[CmdletBinding()]
param([switch]$Claude, [switch]$Codex, [switch]$OpenCode, [switch]$All,
      [switch]$ConfigOnly, [switch]$SkipTools, [switch]$ToolsOnly, [switch]$Help)
$ErrorActionPreference = 'Stop'
if ($Help) {
    Write-Output 'Usage: .\install.ps1 [-All | -Claude -Codex -OpenCode] [-ConfigOnly | -SkipTools | -ToolsOnly]'
    return
}
if ($ToolsOnly -and ($SkipTools -or $ConfigOnly -or $All -or $Claude -or $Codex -or $OpenCode)) { throw '-ToolsOnly cannot be combined with other installation switches.' }
if (-not $SkipTools -and -not $ConfigOnly) { & (Join-Path $PSScriptRoot 'tools/install.ps1') }
if ($ToolsOnly) {
    & node (Join-Path $PSScriptRoot 'lib/doctor.mjs') --agents none --manifest auto
    if ($LASTEXITCODE -ne 0) { throw 'Manifest creation failed.' }
    return
}
if ($All -or -not ($Claude -or $Codex -or $OpenCode)) { $Claude = $Codex = $OpenCode = $true }
foreach ($agent in @('claude', 'codex', 'opencode')) {
    if (($agent -eq 'claude' -and $Claude) -or ($agent -eq 'codex' -and $Codex) -or ($agent -eq 'opencode' -and $OpenCode)) {
        & (Join-Path $PSScriptRoot "$agent/install.ps1") -ConfigOnly:$ConfigOnly
    }
}
if (-not $ConfigOnly) {
    $selected = @()
    if ($Claude) { $selected += 'claude' }
    if ($Codex) { $selected += 'codex' }
    if ($OpenCode) { $selected += 'opencode' }
    & node (Join-Path $PSScriptRoot 'lib/doctor.mjs') --agents ($selected -join ',') --manifest auto
    if ($LASTEXITCODE -ne 0) { throw 'Manifest creation failed.' }
}
