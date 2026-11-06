# Run with pwsh -NoProfile -File tests/powershell-smoke.ps1
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
foreach ($file in Get-ChildItem -LiteralPath $repo -Filter '*.ps1' -Recurse | Where-Object { $_.FullName -notlike '*/.validation/*' }) {
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors) { throw "$($file.FullName): $parseErrors" }
}
$testRoot = Join-Path $repo ('.test powershell ' + [Guid]::NewGuid().ToString())
[void](New-Item -ItemType Directory -Path $testRoot)
# Preserve the session's environment. Never change the caller's actual home/profile.
$names = @('CLAUDE_CONFIG_DIR','CODEX_HOME','OPENCODE_CONFIG_DIR','OPENCODE_CONFIG','OTEL_EXPORTER_OTLP_ENDPOINT','PATH')
$saved = @{}
foreach ($name in $names) { $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
$savedProfile = $PROFILE
try {
    $env:CLAUDE_CONFIG_DIR = Join-Path $testRoot 'claude'
    $env:CODEX_HOME = Join-Path $testRoot 'codex'
    $env:OPENCODE_CONFIG_DIR = Join-Path $testRoot 'opencode'
    Remove-Item Env:OPENCODE_CONFIG -ErrorAction SilentlyContinue
    $profileFile = Join-Path $testRoot 'profile.ps1'
    $PROFILE = [pscustomobject]@{ CurrentUserAllHosts = $profileFile }
    & (Join-Path $repo 'install.ps1') -All -ConfigOnly
    & (Join-Path $repo 'install.ps1') -All -ConfigOnly
    $settings = Get-Content -Raw -LiteralPath (Join-Path $env:CLAUDE_CONFIG_DIR 'settings.json') | ConvertFrom-Json
    if ($settings.attribution.commit -ne '') { throw 'Claude attribution mismatch' }
    if (-not (Test-Path -LiteralPath (Join-Path $env:CODEX_HOME 'config.toml'))) { throw 'Codex config missing' }
    $env:OTEL_EXPORTER_OTLP_ENDPOINT = 'https://example.invalid'
    . $profileFile
    if ($env:OTEL_EXPORTER_OTLP_ENDPOINT) { throw 'OpenCode OTLP environment not disabled' }
    if (@(Get-ChildItem -LiteralPath $env:CLAUDE_CONFIG_DIR -Filter 'settings.json.bak.*').Count -ne 0) { throw 'Repeated run changed config' }
    Write-Output 'PowerShell parse and configuration smoke tests passed.'
} finally {
    $PROFILE = $savedProfile
    foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process') }
    Remove-Item -LiteralPath $testRoot -Recurse -Force
}
