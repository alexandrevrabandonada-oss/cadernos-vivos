# CV — Hotfix — MapaV2: passar prop `mapa` para MapaDockV2 — v0_34
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

$repo = Get-Location
$bootstrap = Join-Path $repo "tools\_bootstrap.ps1"
if (Test-Path -LiteralPath $bootstrap) { . $bootstrap } else { throw "[STOP] tools/_bootstrap.ps1 não encontrado." }

Write-Host ("[DIAG] Repo: " + $repo)

$mapaV2Path = Join-Path $repo "src\components\v2\MapaV2.tsx"
if (-not (Test-Path -LiteralPath $mapaV2Path)) { throw ("[STOP] Não achei: " + $mapaV2Path) }

$raw = Get-Content -LiteralPath $mapaV2Path -Raw

# patch: <MapaDockV2 slug={slug} />  -> <MapaDockV2 slug={slug} mapa={mapa} />
# (só se ainda não tiver mapa=)
if ($raw -match '<MapaDockV2\s+slug=\{slug\}[^>]*mapa=') {
  Write-Host "[OK] MapaV2: já passa mapa= para MapaDockV2."
} else {
  $patched = $raw

  # tenta substituir forma auto-fechada primeiro
  $patched = [regex]::Replace(
    $patched,
    '<MapaDockV2\s+slug=\{slug\}\s*\/>',
    '<MapaDockV2 slug={slug} mapa={mapa} />'
  )

  # se não mudou, tenta forma com props em múltiplas linhas (fallback simples)
  if ($patched -eq $raw) {
    $patched = [regex]::Replace(
      $patched,
      '<MapaDockV2\s+slug=\{slug\}\s*>',
      '<MapaDockV2 slug={slug} mapa={mapa}>'
    )
  }

  if ($patched -eq $raw) {
    throw "[STOP] Não consegui achar o trecho '<MapaDockV2 slug={slug} />' para patchar."
  }

  $bk = BackupFile $mapaV2Path
  WriteUtf8NoBom $mapaV2Path $patched
  Write-Host "[OK] patched: MapaV2.tsx (passou mapa para MapaDockV2)"
  if ($bk) { Write-Host ("[BK] " + $bk) }
}

# VERIFY
RunPs1 (Join-Path $repo "tools\cv-verify.ps1")

# REPORT
$rep = @()
$rep += "# CV — Hotfix v0_34 — MapaDockV2 props"
$rep += ""
$rep += "## Fix"
$rep += "- Em src/components/v2/MapaV2.tsx: <MapaDockV2 slug={slug} /> -> <MapaDockV2 slug={slug} mapa={mapa} />"
$rep += ""
$rep += "## Verify"
$rep += "- tools/cv-verify.ps1 (guard + lint + build)"
$rep += ""

WriteReport "cv-v2-hotfix-mapadock-props-v0_34.md" ($rep -join "`n") | Out-Null
Write-Host "[OK] v0_34 aplicado e verificado."