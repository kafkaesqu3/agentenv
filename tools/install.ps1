[CmdletBinding()]
param([switch]$DryRun, [switch]$Help)
$ErrorActionPreference = 'Stop'
if ($Help) { Write-Output 'Usage: tools/install.ps1 [-DryRun] (Windows with WinGet)'; return }
if ($env:OS -ne 'Windows_NT') { throw 'Use tools/install.sh on macOS/Linux.' }
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw 'Install Microsoft App Installer (WinGet) first.' }
# Windows supplies CA trust and tar; Git provides Bash. 7-Zip supplies archive equivalents.
$packages = @('Git.Git','cURL.cURL','BurntSushi.ripgrep.MSVC','sharkdp.fd','jqlang.jq','OpenJS.NodeJS.LTS','Python.Python.3.13','astral-sh.uv','Microsoft.PowerShell','7zip.7zip')
foreach ($package in $packages) {
    $arguments = @('install','--exact','--id',$package,'--source','winget','--accept-package-agreements','--accept-source-agreements','--disable-interactivity')
    if ($DryRun) { Write-Output ('winget ' + ($arguments -join ' ')); continue }
    & winget @arguments
    # APPINSTALLER_CLI_ERROR_UPDATE_NOT_APPLICABLE: already installed/current.
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) { throw "WinGet failed for ${package}: $LASTEXITCODE" }
}
if (-not $DryRun) {
    $env:PATH = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User') + ';' + $env:PATH
    $archiveBin = Join-Path $env:ProgramFiles '7-Zip'
    if (Test-Path $archiveBin) { $env:PATH = $archiveBin + ';' + $env:PATH }
    $env:AGENTENV_TOOL_PATH = $archiveBin
    & node --version
    if ($LASTEXITCODE -ne 0) { throw 'Node is not available after installation; reopen PowerShell and rerun.' }
    & node (Join-Path (Split-Path $PSScriptRoot) 'lib/tools-env.mjs') --profile $PROFILE.CurrentUserAllHosts
    if ($LASTEXITCODE -ne 0) { throw 'Shared tool environment configuration failed.' }
}
