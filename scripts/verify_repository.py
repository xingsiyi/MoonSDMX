"""Check project scale, real history and private submission-material hygiene."""
from pathlib import Path
import re
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def git(*args):
    return subprocess.check_output(
        ["git", "-c", "core.quotepath=false", "-c", f"safe.directory={ROOT.as_posix()}", "-C", str(ROOT), *args],
        text=True, encoding="utf-8",
    ).strip()


def effective_lines(path):
    # MoonBit comments are line comments. Exclude blank/comment-only lines;
    # inline code followed by a comment is counted once.
    return sum(
        bool(line.strip()) and not line.lstrip().startswith("//")
        for line in path.read_text(encoding="utf-8-sig").splitlines()
    )


tracked = list(filter(None, git("ls-files", "-z").split("\0")))
for name in tracked:
    assert not name.startswith(("_build/", ".mooncakes/", ".local/", "reports/", "local-materials/")), name
for name in git("log", "--all", "--format=", "--name-only").splitlines():
    assert not re.search(
        r"申报|审查报告|审计报告|验收报告|自查报告|AI辅助|汇总报告|总结报告|"
        r"(?:ai|review|acceptance|summary)_report|proposal|\.bak$", name, re.I
    ), f"Private material in history: {name}"

production = [
    ROOT / name for name in tracked
    if name.endswith(".mbt")
    and not name.endswith(("_test.mbt", "_wbtest.mbt"))
    and not name.startswith("examples/")
]
total = sum(map(effective_lines, production))
commits = int(git("rev-list", "--count", "HEAD"))
assert total > 4000, f"Production MoonBit scale: {total} <= 4000"
assert commits > 30, f"History: {commits} <= 30"
assert len(git("rev-list", "--max-parents=0", "HEAD").splitlines()) == 1
for commit in git("rev-list", "HEAD").splitlines():
    assert git("diff-tree", "--root", "--no-commit-id", "--name-only", "-r", commit), f"Empty commit: {commit}"
assert (ROOT / "LICENSE").is_file()
assert (ROOT / "README.md").is_file()
print(f"Production: {total} effective lines in {len(production)} files (tests/examples/generated interfaces excluded)")
print(f"History: {commits} nonempty commits; private materials absent from all reachable commits")

def check_package_path(name):
    parts = set(name.replace("\\", "/").split("/"))
    if parts.intersection({".git", ".local", "_local", "_build", ".mooncakes", ".scratch", "reports", "local-materials", "__pycache__"}) or re.search(
        r"申报|审查报告|审计报告|验收报告|自查报告|AI辅助|汇总报告|总结报告|(?:ai|review|acceptance|summary)_report|proposal|\.bak$", name, re.I
    ):
        raise SystemExit("Private/generated material in package or tracked paths: " + name)

for name in tracked:
    check_package_path(name)
for name in git("log", "--all", "--format=", "--name-only").splitlines():
    check_package_path(name)
archives = list((ROOT / "_build/publish").glob("*.zip"))
for archive in archives:
    with zipfile.ZipFile(archive) as package:
        for name in package.namelist():
            check_package_path(name)
print(f"Tracked/history paths and {len(archives)} local package ZIPs passed exclusions")
