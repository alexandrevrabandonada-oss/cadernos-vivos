# CV — V2 Hotfix — TimelineV2: remover window.location.hash (react-hooks/immutability) — v0_27
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

$repo = Get-Location
$bootstrap = Join-Path $repo "tools\_bootstrap.ps1"
if (-not (Test-Path -LiteralPath $bootstrap)) { throw "[STOP] tools/_bootstrap.ps1 não encontrado. Rode o tijolo infra antes." }
. $bootstrap

Write-Host ("[DIAG] Repo: " + $repo)

$timelinePath = Join-Path $repo "src\components\v2\TimelineV2.tsx"
if (-not (Test-Path -LiteralPath $timelinePath)) { throw ("[STOP] Não achei: " + $timelinePath) }
Write-Host ("[DIAG] TimelineV2: " + $timelinePath)

$raw = Get-Content -LiteralPath $timelinePath -Raw
$lines = $raw -split "\r?\n"

$out = New-Object System.Collections.Generic.List[string]
$changed = $false

foreach ($ln in $lines) {
  if ($ln -match "window\.location\.hash\s*=\s*hash\s*;") {
    $indent = ""
    if ($ln -match "^(\s*)") { $indent = $Matches[1] }

    # Mantém a âncora e UX sem mutar window.location/history (lint friendly)
    $out.Add($indent + 'const el = document.getElementById(hash.slice(1));')
    $out.Add($indent + 'if (el) el.scrollIntoView({ behavior: "smooth", block: "start" });')
    $changed = $true
  } else {
    $out.Add($ln)
  }
}

if (-not $changed) {
  Write-Host "[WARN] Não encontrei 'window.location.hash = hash;' — talvez já esteja corrigido."
} else {
  $bk = BackupFile $timelinePath
  WriteUtf8NoBom $timelinePath ($out -join "`n")
  Write-Host "[OK] patched: TimelineV2.tsx (removeu window.location.hash; adicionou scrollIntoView)"
  if ($bk) { Write-Host ("[BK] " + $bk) }
}

# VERIFY (guard + lint + build)
$verify = Join-Path $repo "tools\cv-verify.ps1"
if (-not (Test-Path -LiteralPath $verify)) { throw ("[STOP] Não achei: " + $verify) }
Write-Host ("[RUN] " + $verify)
& $verify

# REPORT
$report = @(
  "# CV — Hotfix v0_27 — TimelineV2 sem window.location.hash",
  "",
  "## Causa raiz",
  "- ESLint (react-hooks/immutability) bloqueia mutação de window.location.hash dentro de componente/hook.",
  "",
  "## Fix",
  "- Removeu: window.location.hash = hash;",
  "- Mantém UX: scrollIntoView no item do hash (o link já é copiado com #id).",
  "",
  "## Arquivo",
  "- src/components/v2/TimelineV2.tsx",
  "",
  "## Verify",
  "- tools/cv-verify.ps1 (Guard → Lint → Build)",
  ""
) -join "`n"

WriteReport "cv-v2-hotfix-timeline-immutability-v0_27.md" $report | Out-Null
Write-Host "[OK] v0_27 aplicado e verificado."