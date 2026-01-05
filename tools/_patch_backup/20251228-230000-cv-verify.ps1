# CV — Verify (Guard → Lint → Build)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/_bootstrap.ps1"

& (Join-Path $PSScriptRoot 'cv-guard-v2.ps1')

$npm = GetNpmCmd
RunCmd $npm @('run','lint')
RunCmd $npm @('run','build')

Write-Host '[OK] verify OK (guard+lint+build).'