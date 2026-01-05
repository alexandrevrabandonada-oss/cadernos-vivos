# CV — Hotfix — TimelineV2 immutability (sem assignment em window.location.hash) — v0_23
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/_bootstrap.ps1"

$repo = Get-Location
Write-Host ("[DIAG] Repo: " + $repo)

$target = Join-Path $repo "src\components\v2\TimelineV2.tsx"
if (-not (Test-Path -LiteralPath $target)) { throw ("[STOP] Não achei: " + $target) }

$raw = Get-Content -LiteralPath $target -Raw
$raw2 = $raw

# Preferência: replaceState (sem atribuição) — mantém a URL com hash sem mexer via assignment
if ($raw2 -match 'window\.location\.hash\s*=\s*hash\s*;') {
  $bk = BackupFile $target
  $raw2 = [regex]::Replace($raw2, 'window\.location\.hash\s*=\s*hash\s*;', 'window.history.replaceState(null, "", hash);')
  WriteUtf8NoBom $target $raw2
  Write-Host "[OK] patched: TimelineV2.tsx (window.history.replaceState)"
  if ($bk) { Write-Host ("[BK] " + $bk) }
} else {
  Write-Host "[WARN] Não encontrei 'window.location.hash = hash;'. Sem mudanças."
}

# VERIFY
Write-Host "[RUN] tools/cv-verify.ps1"
& (Join-Path $PSScriptRoot "cv-verify.ps1")

# REPORT
$report = @(
  "# CV — Hotfix v0_23 — TimelineV2 immutability",
  "",
  "## Causa",
  "- ESLint react-hooks/immutability não permite assignment em window.location.hash.",
  "",
  "## Fix",
  "- Troca window.location.hash = hash; por window.history.replaceState(null, \"\", hash);",
  "",
  "## Arquivo",
  "- src/components/v2/TimelineV2.tsx",
  "",
  "## Verify",
  "- tools/cv-verify.ps1 (guard + lint + build)"
) -join "`n"

WriteReport "cv-v2-hotfix-timeline-immutability-v0_23.md" $report | Out-Null
Write-Host "[OK] v0_23 aplicado."