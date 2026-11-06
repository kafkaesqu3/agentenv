[CmdletBinding()]
param([switch]$ConfigOnly, [switch]$Help)
if ($Help) { Write-Output 'Usage: .\opencode\install.ps1 [-ConfigOnly]'; return }
. (Join-Path $PSScriptRoot '../lib/install.ps1')
Install-Agent -Agent opencode -ConfigOnly:$ConfigOnly
