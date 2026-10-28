<#
.SYNOPSIS
    Installs the ainish-coder CLI on native Windows.

.DESCRIPTION
    Puts <repo>\bin on the current user's PATH so `ainish-coder` resolves from
    cmd.exe, PowerShell and Windows Terminal without WSL, then verifies the
    runtime the CLI depends on.

    The change is user-scoped (HKCU\Environment) and needs no elevation. It is
    idempotent: re-running it rewrites nothing when the entry is already there.
    -Uninstall removes exactly that entry again.

    The PATH value is written back with the registry kind it was read with, so
    any %VAR% references already in the user PATH keep expanding. Rewriting PATH
    as a plain string is what corrupts people's PATH in careless installers, so
    it is deliberately avoided here.

.PARAMETER Uninstall
    Remove the bin directory from the user PATH instead of adding it.

.PARAMETER SkipVerify
    Skip the post-install smoke test of the CLI.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\ainish-setup.ps1

.EXAMPLE
    .\scripts\ainish-setup.ps1 -Uninstall
#>
[CmdletBinding()]
param(
    [switch]$Uninstall,
    [switch]$SkipVerify
)

$ErrorActionPreference = 'Stop'

function Write-Step { param([string]$Message) Write-Host "[*] $Message" -ForegroundColor Cyan }
function Write-Ok   { param([string]$Message) Write-Host "[+] $Message" -ForegroundColor Green }
function Write-Warn { param([string]$Message) Write-Host "[!] $Message" -ForegroundColor Yellow }
function Write-Err  { param([string]$Message) Write-Host "[x] $Message" -ForegroundColor Red }

# ---------------------------------------------------------------- repo layout
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$BinDir   = Join-Path $RepoRoot 'bin'
$CliCmd   = Join-Path $BinDir 'ainish-coder.cmd'
$CliShell = Join-Path $BinDir 'ainish-coder'

Write-Host ''
Write-Host '  AINISH-CODER - WINDOWS SETUP' -ForegroundColor White
Write-Host '  ============================' -ForegroundColor White
Write-Host ''

foreach ($required in @($BinDir, $CliCmd, $CliShell)) {
    if (-not (Test-Path -LiteralPath $required)) {
        Write-Err "Required path missing: $required"
        exit 1
    }
}

# ------------------------------------------------------- prerequisite: bash
# The CLI is POSIX shell; Windows runs it through Git for Windows / MSYS2 /
# Cygwin bash. This mirrors the probe order in bin/ainish-coder.cmd.
function Find-Bash {
    $bases = @(
        $env:ProgramFiles
        ${env:ProgramFiles(x86)}
        $env:LOCALAPPDATA
        $env:ProgramData
        $env:USERPROFILE
        $env:SystemDrive
    )
    $suffixes = @(
        'Git\bin\bash.exe'
        'Programs\Git\bin\bash.exe'
        'chocolatey\bin\bash.exe'
        'scoop\apps\git\current\bin\bash.exe'
        'msys64\usr\bin\bash.exe'
        'cygwin64\bin\bash.exe'
        'cygwin\bin\bash.exe'
    )
    foreach ($base in $bases) {
        if ([string]::IsNullOrWhiteSpace($base)) { continue }
        foreach ($suffix in $suffixes) {
            $candidate = Join-Path $base $suffix
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                if ((Get-Item -LiteralPath $candidate).Length -gt 0) { return $candidate }
            }
        }
    }
    # Fall back to PATH, ignoring the WindowsApps WSL launcher stub.
    foreach ($cmd in @(Get-Command bash -All -ErrorAction SilentlyContinue)) {
        if (-not $cmd.Source) { continue }
        if ($cmd.Source -like '*WindowsApps*') { continue }
        if (Test-Path -LiteralPath $cmd.Source -PathType Leaf) {
            if ((Get-Item -LiteralPath $cmd.Source).Length -gt 0) { return $cmd.Source }
        }
    }
    return $null
}

Write-Step 'Checking for a POSIX shell (Git for Windows bash)...'
$BashPath = Find-Bash
if (-not $BashPath) {
    Write-Err 'No usable bash found.'
    Write-Host '    ainish-coder runs its POSIX CLI on Windows through Git for Windows.'
    Write-Host '    Install it, then re-run this script:'
    Write-Host ''
    Write-Host '        winget install --id Git.Git -e' -ForegroundColor Yellow
    exit 127
}
Write-Ok "bash: $BashPath"

# ------------------------------------------------------------ provide python
# Reported, never required: most commands run without Python. The JSON-backed
# skill-selection toggles need one working interpreter, so report honestly.
Write-Step 'Checking for a Python 3 interpreter...'
$PythonPath = $null
foreach ($candidate in @('python3', 'python')) {
    $found = Get-Command $candidate -ErrorAction SilentlyContinue
    if (-not $found -or -not $found.Source) { continue }
    & $found.Source -c 'import sys; raise SystemExit(0 if sys.version_info[0] == 3 else 1)' 2>$null
    if ($LASTEXITCODE -eq 0) { $PythonPath = $found.Source; break }
}
if (-not $PythonPath) {
    $py = Get-Command py -ErrorAction SilentlyContinue
    if ($py -and $py.Source) {
        $resolved = & $py.Source -3 -c 'import sys; print(sys.executable)' 2>$null
        if ($LASTEXITCODE -eq 0 -and $resolved) { $PythonPath = "$resolved".Trim() }
    }
}
if ($PythonPath) {
    Write-Ok "python3: $PythonPath"
} else {
    Write-Warn 'No Python 3 found. Skill-selection toggles stay at their defaults.'
    Write-Host '    Install it later with:  winget install --id Python.Python.3.12 -e'
}

# ------------------------------------------------------------------ PATH edit
$keyPath = 'HKCU:\Environment'
$currentPath = $null
$valueKind = [Microsoft.Win32.RegistryValueKind]::ExpandString
try {
    $key = Get-Item -LiteralPath $keyPath -ErrorAction Stop
    if ($key.GetValueNames() -contains 'Path') {
        $valueKind = $key.GetValueKind('Path')
        $currentPath = $key.GetValue('Path', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    }
} catch {
    $currentPath = $null
}

function Normalize-PathEntry { param([string]$Entry) $Entry.Trim().TrimEnd('\') }
$normBin = Normalize-PathEntry $BinDir

# Split without filtering. Re-joining the untouched segments reproduces the
# original value byte-for-byte, including the empty entries an existing PATH may
# already carry; filtering empties here would silently rewrite a user PATH.
$segments = @()
if ($null -ne $currentPath) { $segments = @($currentPath -split ';') }
$alreadyThere = $false
foreach ($segment in $segments) {
    if ([string]::IsNullOrWhiteSpace($segment)) { continue }
    if ((Normalize-PathEntry $segment) -ieq $normBin) { $alreadyThere = $true; break }
}

if ($Uninstall) {
    Write-Step 'Removing from the user PATH...'
    if (-not $alreadyThere) {
        Write-Ok "$BinDir is not on the user PATH; nothing to remove."
    } else {
        # Remove the entry together with exactly one adjacent separator, so a
        # trailing or embedded empty PATH entry survives the round-trip.
        $sepBin = ';' + $BinDir
        if ($currentPath -ieq $BinDir) {
            $newPath = ''
        } elseif ($currentPath.EndsWith($sepBin, [StringComparison]::OrdinalIgnoreCase)) {
            $newPath = $currentPath.Substring(0, $currentPath.Length - $sepBin.Length)
        } else {
            $pattern = [regex]::Escape($BinDir) + ';'
            $newPath = [regex]::Replace($currentPath, $pattern, '', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        }
        Set-ItemProperty -LiteralPath $keyPath -Name 'Path' -Value $newPath -Type $valueKind
        $readback = (Get-Item -LiteralPath $keyPath).GetValue('Path', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        if ([string]$readback -cne [string]$newPath) { Write-Err 'PATH read-back mismatch after removal.'; exit 1 }
        Write-Ok "Removed $BinDir from the user PATH."
    }
    Write-Host ''
    Write-Host 'Close and reopen your terminal to apply.'
    exit 0
}

Write-Step 'Adding to the user PATH...'
if ($alreadyThere) {
    Write-Ok "$BinDir is already on the user PATH."
} else {
    # Append with an explicit separator even when the existing value already ends
    # in ';'. Reusing that separator would make the entry indistinguishable from
    # one the user added themselves, and -Uninstall could not restore the exact
    # original value. Adding our own makes ending with ';'+BinDir the precise
    # inverse of this step.
    if ([string]::IsNullOrEmpty($currentPath)) {
        $newPath = $BinDir
    } else {
        $newPath = $currentPath + ';' + $BinDir
    }
    Set-ItemProperty -LiteralPath $keyPath -Name 'Path' -Value $newPath -Type $valueKind
    $readback = (Get-Item -LiteralPath $keyPath).GetValue('Path', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    $verified = $false
    foreach ($part in @($readback -split ';')) {
        if ((Normalize-PathEntry $part) -ieq $normBin) { $verified = $true; break }
    }
    if (-not $verified) { Write-Err 'PATH read-back did not contain the bin directory.'; exit 1 }
    Write-Ok "Added $BinDir to the user PATH."
}

# ------------------------------------------------------------- smoke test
if (-not $SkipVerify) {
    Write-Step 'Verifying the installed command...'
    $savedPath = $env:PATH
    try {
        $env:PATH = "$BinDir;$env:PATH"
        $output = @(& cmd /c 'ainish-coder --help' 2>&1)
        if ($LASTEXITCODE -ne 0) {
            Write-Err "ainish-coder --help exited $LASTEXITCODE"
            $output | Select-Object -First 20 | ForEach-Object { Write-Host "    $_" }
            exit 1
        }
        if (-not (($output -join "`n") -match 'Configuration Manager')) {
            Write-Err 'ainish-coder --help did not print the expected banner.'
            $output | Select-Object -First 20 | ForEach-Object { Write-Host "    $_" }
            exit 1
        }
        Write-Ok 'ainish-coder --help responded correctly.'
    } finally {
        $env:PATH = $savedPath
    }
}

Write-Host ''
Write-Host '  SETUP COMPLETE' -ForegroundColor Green
Write-Host '  -------------- ' -ForegroundColor Green
Write-Host ''
Write-Host '  Close and reopen your terminal, then try:'
Write-Host ''
Write-Host '      ainish-coder --help' -ForegroundColor Yellow
Write-Host '      ainish-coder --rules' -ForegroundColor Yellow
Write-Host ''
Write-Host '  Works from cmd.exe, PowerShell 5.1+, PowerShell 7 and Windows Terminal.'
Write-Host '  WSL remains supported and unchanged.'
Write-Host ''