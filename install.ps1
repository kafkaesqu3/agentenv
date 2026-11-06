[CmdletBinding()]
param([switch]$Claude, [switch]$Codex, [switch]$OpenCode, [switch]$All,
      [switch]$ConfigOnly, [switch]$Help)
$ErrorActionPreference = 'Stop'
if ($Help) {
    Write-Output 'Usage: .\install.ps1 [-All | -Claude -Codex -OpenCode] [-ConfigOnly]'
    return
}
if ($All -or -not ($Claude -or $Codex -or $OpenCode)) { $Claude = $Codex = $OpenCode = $true }
foreach ($agent in @('claude', 'codex', 'opencode')) {
    if (($agent -eq 'claude' -and $Claude) -or ($agent -eq 'codex' -and $Codex) -or ($agent -eq 'opencode' -and $OpenCode)) {
        & (Join-Path $PSScriptRoot "$agent/install.ps1") -ConfigOnly:$ConfigOnly
    }
}
