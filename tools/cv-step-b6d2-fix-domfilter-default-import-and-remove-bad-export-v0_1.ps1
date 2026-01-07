param([switch]$OpenReport)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path

$boot = Join-Path $PSScriptRoot "_bootstrap.ps1"
if (Test-Path -LiteralPath $boot) { . $boot }

function EnsureDirSafe([string]$p) {
  if (Get-Command EnsureDir -ErrorAction SilentlyContinue) { EnsureDir $p; return }
  if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}
function WriteUtf8NoBomSafe([string]$p, [string]$content) {
  if (Get-Command WriteUtf8NoBom -ErrorAction SilentlyContinue) { WriteUtf8NoBom $p $content; return }
  [IO.File]::WriteAllText($p, $content, [Text.UTF8Encoding]::new($false))
}
function BackupFileSafe([string]$p) {
  if (Get-Command BackupFile -ErrorAction SilentlyContinue) { return (BackupFile $p) }
  $bkDir = Join-Path $root "tools\_patch_backup"
  EnsureDirSafe $bkDir
  $stamp = (Get-Date -Format "yyyyMMdd-HHmmss")
  $bk = Join-Path $bkDir ($stamp + "-" + (Split-Path -Leaf $p) + ".bak")
  Copy-Item -LiteralPath $p -Destination $bk -Force
  return $bk
}

$stamp = (Get-Date -Format "yyyyMMdd-HHmmss")
$step  = "cv-step-b6d2-fix-domfilter-default-import-and-remove-bad-export-v0_1"

Write-Host ("== " + $step + " == " + $stamp) -ForegroundColor Cyan
Write-Host ("[DIAG] Root: " + $root)

EnsureDirSafe (Join-Path $root "reports")
EnsureDirSafe (Join-Path $root "tools\_patch_backup")

# ---- targets
$compRel = "src\components\v2\Cv2DomFilterClient.tsx"
$comp    = Join-Path $root $compRel
if (-not (Test-Path -LiteralPath $comp)) { throw ("[STOP] nao achei: " + $compRel) }

$pageRel = "src\app\c\[slug]\v2\provas\page.tsx"
$page    = Join-Path $root $pageRel
if (-not (Test-Path -LiteralPath $page)) { throw ("[STOP] nao achei: " + $pageRel) }

# ---- PATCH 1: remover export inválido no mesmo módulo
$bk1 = BackupFileSafe $comp
$raw1 = Get-Content -Raw -LiteralPath $comp
if ($null -eq $raw1 -or $raw1.Trim().Length -eq 0) { throw "[STOP] componente vazio" }

$lines1 = $raw1 -split "`r?`n"
$bad = "export { default as Cv2DomFilterClient };"

$new1 = @()
$removedBad = 0
foreach ($ln in $lines1) {
  if ($ln.Trim() -eq $bad) { $removedBad += 1; continue }
  $new1 += $ln
}
$patched1 = ($new1 -join "`n")

if ($patched1 -ne $raw1) {
  WriteUtf8NoBomSafe $comp $patched1
  Write-Host ("[PATCH] removed bad export -> " + $compRel)
  Write-Host ("[BK] tools/_patch_backup/" + (Split-Path -Leaf $bk1))
} else {
  Write-Host ("[PATCH] no bad export found -> " + $compRel)
}

# ---- PATCH 2: trocar import do page.tsx para default import
$bk2 = BackupFileSafe $page
$raw2 = Get-Content -Raw -LiteralPath $page
if ($null -eq $raw2 -or $raw2.Trim().Length -eq 0) { throw "[STOP] page vazio" }

$fromImport = 'import { Cv2DomFilterClient } from "@/components/v2/Cv2DomFilterClient";'
$toImport   = 'import Cv2DomFilterClient from "@/components/v2/Cv2DomFilterClient";'

$patched2 = $raw2
if ($patched2.Contains($fromImport)) {
  $patched2 = $patched2.Replace($fromImport, $toImport)
}

if ($patched2 -ne $raw2) {
  WriteUtf8NoBomSafe $page $patched2
  Write-Host ("[PATCH] import fixed -> " + $pageRel)
  Write-Host ("[BK] tools/_patch_backup/" + (Split-Path -Leaf $bk2))
} else {
  Write-Host ("[PATCH] import already ok -> " + $pageRel)
}

# ---- REPORT
$reportRel  = ("reports\" + $step + "-" + $stamp + ".md")
$reportPath = Join-Path $root $reportRel

$rep = @()
$rep += "# CV — Step B6d2: Fix DomFilter export + Provas import"
$rep += ""
$rep += "- when: " + $stamp
$rep += "- component: " + $compRel
$rep += "- page: " + $pageRel
$rep += ""
$rep += "## Changes"
$rep += "- Remove line invalid in-module: export { default as Cv2DomFilterClient };"
$rep += "- Change Provas V2 import to default import (robust for TS/Next/Turbopack)."
$rep += ""
$rep += "## Verify"
$rep += "- tools/cv-verify.ps1"

WriteUtf8NoBomSafe $reportPath ($rep -join "`n")
Write-Host ("[REPORT] " + $reportRel)

# ---- VERIFY
$verify = Join-Path $root "tools\cv-verify.ps1"
if (Test-Path -LiteralPath $verify) {
  Write-Host "[RUN] tools/cv-verify.ps1"
  & pwsh -NoProfile -ExecutionPolicy Bypass -File $verify
} else {
  Write-Host "[RUN] npm run lint"
  & npm run lint
  Write-Host "[RUN] npm run build"
  & npm run build
}

Write-Host "[OK] B6d2 aplicado." -ForegroundColor Green
if ($OpenReport) { try { Invoke-Item $reportPath } catch {} }