$ErrorActionPreference = 'Stop'
$AgentEnvRoot = Split-Path -Parent $PSScriptRoot

function Install-Agent {
    param([ValidateSet('claude','codex','opencode')][string]$Agent, [switch]$ConfigOnly)
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) { throw 'Node.js 22+ is required.' }
    $nodeVersion = & node --version
    if ($LASTEXITCODE -ne 0 -or [int](($nodeVersion -replace '^v','').Split('.')[0]) -lt 22) { throw 'Node.js 22+ is required.' }
    $binPath = ''
    if (-not $ConfigOnly) {
        if ($Agent -eq 'claude') {
            $tempFile = [System.IO.Path]::GetTempFileName() + '.ps1'
            try {
                Invoke-WebRequest -Uri 'https://claude.ai/install.ps1' -OutFile $tempFile -UseBasicParsing
                # Run in a child process: vendor exit statements cannot terminate this installer.
                $shellExe = (Get-Process -Id $PID).Path
                & $shellExe -NoProfile -ExecutionPolicy Bypass -File $tempFile latest
                if ($LASTEXITCODE -ne 0) { throw "Claude installer failed: $LASTEXITCODE" }
            } finally {
                Remove-Item -LiteralPath $tempFile -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath ($tempFile -replace '\.ps1$','') -ErrorAction SilentlyContinue
            }
            $binPath = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.local/bin'
            $binary = Join-Path $binPath 'claude.exe'
        } else {
            if (-not (Get-Command npm.cmd -ErrorAction SilentlyContinue)) { throw 'npm is required.' }
            $package = if ($Agent -eq 'codex') { '@openai/codex@latest' } else { '@opencode/cli@latest' }
            & npm.cmd install --global $package
            if ($LASTEXITCODE -ne 0) { throw "npm installation failed: $LASTEXITCODE" }
            $binPath = (& npm.cmd prefix --global | Out-String).Trim()
            if ($LASTEXITCODE -ne 0) { throw 'Could not determine npm global prefix.' }
            $binary = Join-Path $binPath "$Agent.cmd"
        }
        if (-not (Test-Path -LiteralPath $binary)) { throw "Installed binary not found: $binary" }
        & $binary --version
        if ($LASTEXITCODE -ne 0) { throw "$Agent version check failed." }
        $env:PATH = $binPath + [IO.Path]::PathSeparator + $env:PATH
    }
    $configArgs = @((Join-Path $AgentEnvRoot 'lib/configure.mjs'), $Agent, '--profile', $PROFILE.CurrentUserAllHosts)
    if ($binPath) { $configArgs += @('--bin', $binPath) }
    & node @configArgs
    if ($LASTEXITCODE -ne 0) { throw "$Agent configuration failed." }
    Write-Output "$Agent baseline installed. Open a new PowerShell session to load PATH and environment changes."
}
