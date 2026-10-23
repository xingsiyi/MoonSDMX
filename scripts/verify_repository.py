"""Check project scale, real history and private submission-material hygiene."""
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def git(*args):
    return subprocess.check_output(
        ["git", "-c", f"safe.directory={ROOT.as_posix()}", "-C", str(ROOT), *args],
        text=True, encoding="utf-8",
    ).strip()


def effective_lines(path):
    # MoonBit comments are line comments. Exclude blank/comment-only lines;
    # inline code followed by a comment is counted once.
    return sum(
        bool(line.strip()) and not line.lstrip().startswith("//")
        for line in path.read_text(encoding="utf-8-sig").splitlines()
    )


tracked = git("ls-files").splitlines()
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
