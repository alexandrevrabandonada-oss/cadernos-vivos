# CV — V2 Hotfix — linha-do-tempo: c.title -> meta.title; TimelineV2: remove window.location.hash — v0_28
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

$repo = Get-Location
$bootstrap = Join-Path $repo "tools\_bootstrap.ps1"
if (-not (Test-Path -LiteralPath $bootstrap)) { throw "[STOP] tools/_bootstrap.ps1 não encontrado. Rode o tijolo infra antes." }
. $bootstrap

Write-Host ("[DIAG] Repo: " + $repo)

# --- 1) Fix: page.tsx (linha-do-tempo e alias linha) ---
$pages = @(
  (Join-Path $repo "src\app\c\[slug]\v2\linha-do-tempo\page.tsx"),
  (Join-Path $repo "src\app\c\[slug]\v2\linha\page.tsx")
)

foreach ($page in $pages) {
  if (-not (Test-Path -LiteralPath $page)) {
    Write-Host ("[SKIP] não achei: " + $page)
    continue
  }

  $raw = Get-Content -LiteralPath $page -Raw
  $lines = $raw -split "`r?`n"
  $out = New-Object System.Collections.Generic.List[string]
  $changed = $false

  foreach ($ln in $lines) {
    if ($ln -match "const\s+title\s*=\s*c\.title\s*;") {
      $indent = ""
      if ($ln -match "^(\s*)") { $indent = $Matches[1] }
      $out.Add($indent + 'const title = (c as unknown as { meta?: { title?: string } }).meta?.title ?? slug;')
      $changed = $true
    } else {
      $out.Add($ln)
    }
  }

  if ($changed) {
    $bk = BackupFile $page
    WriteUtf8NoBom $page ($out -join "`n")
    Write-Host ("[OK] patched: " + $page + " (c.title -> meta.title ?? slug)")
    if ($bk) { Write-Host ("[BK] " + $bk) }
  } else {
    Write-Host ("[OK] no change: " + $page)
  }
}

# --- 2) Fix: TimelineV2 window.location.hash (se existir) ---
$timeline = Join-Path $repo "src\components\v2\TimelineV2.tsx"
if (Test-Path -LiteralPath $timeline) {
  $raw = Get-Content -LiteralPath $timeline -Raw
  $lines = $raw -split "`r?`n"
  $out = New-Object System.Collections.Generic.List[string]
  $changed = $false

  foreach ($ln in $lines) {
    if ($ln -match "window\.location\.hash\s*=\s*hash\s*;") {
      $indent = ""
      if ($ln -match "^(\s*)") { $indent = $Matches[1] }
      $out.Add($indent + 'const el = document.getElementById(hash.slice(1));')
      $out.Add($indent + 'if (el) el.scrollIntoView({ behavior: "smooth", block: "start" });')
      $changed = $true
    } else {
      $out.Add($ln)
    }
  }

  if ($changed) {
    $bk = BackupFile $timeline
    WriteUtf8NoBom $timeline ($out -join "`n")
    Write-Host "[OK] patched: TimelineV2.tsx (removeu window.location.hash; adicionou scrollIntoView)"
    if ($bk) { Write-Host ("[BK] " + $bk) }
  } else {
    Write-Host "[OK] TimelineV2: nada pra mudar (window.location.hash não encontrado)."
  }
} else {
  Write-Host ("[SKIP] não achei: " + $timeline)
}

# --- 3) VERIFY ---
RunPs1 (Join-Path $repo "tools\cv-verify.ps1") @()

# --- 4) REPORT ---
$report = @(
  "# CV — Hotfix v0_28 — title da Linha + Timeline hash",
  "",
  "## Fixes",
  "- v2/linha-do-tempo (e v2/linha se existir): troca `const title = c.title;` por `meta.title ?? slug`.",
  "- TimelineV2: remove `window.location.hash = hash;` (lint react-hooks/immutability) e usa `scrollIntoView`.",
  "",
  "## Verify",
  "- tools/cv-verify.ps1 (Guard → Lint → Build)",
  ""
) -join "`n"

WriteReport "cv-v2-hotfix-title-linha-e-timelinehash-v0_28.md" $report | Out-Null
Write-Host "[OK] v0_28 aplicado e verificado."