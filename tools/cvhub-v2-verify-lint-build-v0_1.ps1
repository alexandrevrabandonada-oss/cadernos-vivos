# CV — Verify — lint + build (npm com args corretos) — v0_1
$ErrorActionPreference = "Stop"

function RunCmd([string]$exe, [string[]]$cmdArgs) {
  Write-Host ("[RUN] " + $exe + " " + ($cmdArgs -join " "))
  & $exe @cmdArgs
  if ($LASTEXITCODE -ne 0) {
    throw ("[STOP] falhou (exit " + $LASTEXITCODE + "): " + $exe + " " + ($cmdArgs -join " "))
  }
}

$repo = Get-Location
Write-Host ("[DIAG] Repo: " + $repo)

$cmd = Get-Command "npm.cmd" -ErrorAction SilentlyContinue
$npmExe = if ($cmd) { $cmd.Source } else { "npm.cmd" }
Write-Host ("[DIAG] npm: " + $npmExe)

RunCmd $npmExe @("run","lint")
RunCmd $npmExe @("run","build")

Write-Host "[OK] verify passou (lint + build)."