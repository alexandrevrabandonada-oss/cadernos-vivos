$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Write-Host ("[DIAG] Repo: " + $repo)

. (Join-Path $PSScriptRoot "_bootstrap.ps1")

$linhaTempoPage = Join-Path $repo "src\app\c\[slug]\v2\linha-do-tempo\page.tsx"
$v2navPath      = Join-Path $repo "src\components\v2\V2Nav.tsx"

# -----------------------
# 1) linha-do-tempo/page.tsx: active="linha-do-tempo" -> active="linhaTempo"
# -----------------------
if (Test-Path -LiteralPath $linhaTempoPage) {
  $raw = Get-Content -LiteralPath $linhaTempoPage -Raw
  if ($raw -match 'active\s*=\s*["'']linha-do-tempo["'']') {
    $bk = BackupFile $linhaTempoPage
    $raw2 = $raw -replace 'active\s*=\s*["'']linha-do-tempo["'']', 'active="linhaTempo"'
    WriteUtf8NoBom $linhaTempoPage $raw2
    Write-Host ("[OK] patched: " + $linhaTempoPage + " (active linha-do-tempo -> linhaTempo)")
    if ($bk) { Write-Host ("[BK] " + $bk) }
  } else {
    Write-Host "[OK] linha-do-tempo/page.tsx: nada pra mudar."
  }
} else {
  Write-Host "[WARN] nao achei: src/app/c/[slug]/v2/linha-do-tempo/page.tsx"
}

# -----------------------
# 2) V2Nav.tsx: remove unused index param (it, i) -> (it)
# -----------------------
if (Test-Path -LiteralPath $v2navPath) {
  $rawN = Get-Content -LiteralPath $v2navPath -Raw
  $changed = $false

  if ($rawN -match '\.map\(\s*\(\s*it\s*,\s*i\s*\)\s*=>') {
    $bk2 = BackupFile $v2navPath
    $rawN2 = [regex]::Replace($rawN, '\.map\(\s*\(\s*it\s*,\s*i\s*\)\s*=>', '.map((it) =>')
    WriteUtf8NoBom $v2navPath $rawN2
    Write-Host ("[OK] patched: V2Nav removeu parametro i nao usado")
    if ($bk2) { Write-Host ("[BK] " + $bk2) }
    $changed = $true
  }

  if (-not $changed) {
    Write-Host "[OK] V2Nav: nada pra mudar (padrao .map((it, i) => nao encontrado)."
  }
} else {
  Write-Host "[WARN] nao achei: src/components/v2/V2Nav.tsx"
}

# -----------------------
# 3) VERIFY
# -----------------------
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# -----------------------
# 4) REPORT
# -----------------------
$rep = @()
$rep += "# CV — Hotfix v0_45 — V2Nav active key (linhaTempo)"
$rep += ""
$rep += "## Fix"
$rep += "- /v2/linha-do-tempo: V2Nav active foi ajustado para 'linhaTempo' (compatível com o tipo NavKey)."
$rep += "- V2Nav: remove parametro i nao usado na lista (warning)."
$rep += ""
$rep += "## Arquivos"
$rep += "- src/app/c/[slug]/v2/linha-do-tempo/page.tsx"
$rep += "- src/components/v2/V2Nav.tsx"
$rep += ""
$rep += "## Verify"
$rep += "- tools/cv-verify.ps1 (guard + lint + build)"
$rep += ""

$rp = WriteReport "cv-hotfix-v2nav-active-linhatempo-v0_45.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Hotfix v0_45 aplicado."