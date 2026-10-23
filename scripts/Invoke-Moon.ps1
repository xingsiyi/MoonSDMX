# Project-local workaround for the 2026-10-16 Windows drive-path regression.
# It runs the installed moon/moonc, preserves exit codes and never edits them.
[CmdletBinding()]
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$MoonArgs)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$moonCommand = (Get-Command moon -CommandType Application -ErrorAction Stop).Source
$realCompiler = Join-Path (Split-Path -Parent $moonCommand) 'moonc.exe'
$version = (& $moonCommand version --all | Out-String)
if ($LASTEXITCODE -ne 0 -or $version -notmatch '(?m)^moonc v0\.10\.16(?:\+|\s)') {
    throw 'This workaround is restricted to moonc v0.10.16; use normal moon commands for other versions.'
}
if (-not $MoonArgs -or $MoonArgs.Count -eq 0) { $MoonArgs = @('version', '--all') }
$compilerDriver = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $compilerDriver)) {
    throw 'Windows .NET Framework C# compiler is required for this local adapter.'
}
$adapterSource = Join-Path $PSScriptRoot 'windows_path_adapter.cs'
$sourceId = (Get-FileHash -LiteralPath $adapterSource -Algorithm SHA256).Hash.Substring(0, 16)
$adapterDirectory = Join-Path $projectRoot ".local\toolchain-016\$sourceId"
New-Item -ItemType Directory -Path $adapterDirectory -Force | Out-Null
$adapterExecutable = Join-Path $adapterDirectory 'moonc-path-adapter.exe'
$formatterAdapter = Join-Path $adapterDirectory 'moonfmt-path-adapter.exe'
# A source-keyed immutable cache avoids rewriting an executable in use.
$cacheMutex = New-Object System.Threading.Mutex($false, "Local\MoonSDMX-adapter-$sourceId")
$cacheOwned = $false
try {
    $cacheOwned = $cacheMutex.WaitOne(30000)
    if (-not $cacheOwned) { throw 'Timed out waiting for local adapter compilation.' }
    if (-not (Test-Path -LiteralPath $adapterExecutable)) {
        & $compilerDriver /nologo /target:exe "/out:$adapterExecutable" $adapterSource
        if ($LASTEXITCODE -ne 0) { throw 'Could not compile the project-local path adapter.' }
    }
    if (-not (Test-Path -LiteralPath $formatterAdapter)) {
        Copy-Item -LiteralPath $adapterExecutable -Destination $formatterAdapter
    }
} finally {
    if ($cacheOwned) { $cacheMutex.ReleaseMutex() }
    $cacheMutex.Dispose()
}
$previousOverride = $env:MOONC_OVERRIDE
$previousCompiler = $env:MOONSDMX_REAL_COMPILER
$previousFormatterOverride = $env:MOONFMT_OVERRIDE
$previousFormatter = $env:MOONSDMX_REAL_FORMATTER
try {
    $env:MOONC_OVERRIDE = $adapterExecutable
    $env:MOONSDMX_REAL_COMPILER = $realCompiler
    $env:MOONFMT_OVERRIDE = $formatterAdapter
    $env:MOONSDMX_REAL_FORMATTER = Join-Path (Split-Path -Parent $moonCommand) 'moonfmt.exe'
    & $moonCommand @MoonArgs
    $resultCode = $LASTEXITCODE
} finally {
    $env:MOONC_OVERRIDE = $previousOverride
    $env:MOONSDMX_REAL_COMPILER = $previousCompiler
    $env:MOONFMT_OVERRIDE = $previousFormatterOverride
    $env:MOONSDMX_REAL_FORMATTER = $previousFormatter
}
exit $resultCode
