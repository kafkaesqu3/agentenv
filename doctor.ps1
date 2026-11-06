$ErrorActionPreference = 'Stop'
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { throw 'doctor requires Node.js 22+; run tools/install.ps1 first.' }
& node (Join-Path $PSScriptRoot 'lib/doctor.mjs') @args
exit $LASTEXITCODE
