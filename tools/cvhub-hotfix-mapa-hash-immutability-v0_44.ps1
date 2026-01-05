$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Write-Host ("[DIAG] Repo: " + $repo)

. (Join-Path $PSScriptRoot "_bootstrap.ps1")

$canvasPath = Join-Path $repo "src\components\v2\MapaCanvasV2.tsx"
$mapaV2Path = Join-Path $repo "src\components\v2\MapaV2.tsx"

Write-Host ("[DIAG] MapaCanvasV2: " + $canvasPath)
Write-Host ("[DIAG] MapaV2: " + $mapaV2Path)

# -----------------------
# 1) MapaCanvasV2: trocar window.location.hash = ... por history.replaceState + dispatch hashchange
# -----------------------
if (Test-Path -LiteralPath $canvasPath) {
  $raw = Get-Content -LiteralPath $canvasPath -Raw

  $pattern = 'window\.location\.hash\s*=\s*([^;]+);'
  if ([regex]::IsMatch($raw, $pattern)) {
    $bk = BackupFile $canvasPath

    $raw2 = [regex]::Replace($raw, $pattern, {
      param($m)
      $expr = $m.Groups[1].Value.Trim()

      # se já inclui "#", usa como está; senão prefixa "#"
      $hashExpr = $expr
      if ($expr -notmatch '#') {
        $hashExpr = '"#" + ' + $expr
      }

      # mantém mesma indentação aproximada (6 espaços é ok)
      return (
        'window.history.replaceState(null, "", window.location.pathname + window.location.search + ' + $hashExpr + ');' +
        "`n      " +
        'window.dispatchEvent(new Event("hashchange"));'
      )
    })

    WriteUtf8NoBom $canvasPath $raw2
    Write-Host ("[OK] patched: removeu window.location.hash= (usa history.replaceState + hashchange)")
    if ($bk) { Write-Host ("[BK] " + $bk) }
  } else {
    Write-Host "[OK] MapaCanvasV2: nada pra mudar (window.location.hash= nao encontrado)."
  }
} else {
  Write-Host "[WARN] MapaCanvasV2.tsx nao encontrado (ok se ainda nao existe no repo)."
}

# -----------------------
# 2) MapaV2: garantir <MapaDockV2 ... mapa={mapa} />
# -----------------------
if (Test-Path -LiteralPath $mapaV2Path) {
  $rawM = Get-Content -LiteralPath $mapaV2Path -Raw
  $needle = '<MapaDockV2 slug={slug} />'
  if ($rawM.Contains($needle)) {
    $bk2 = BackupFile $mapaV2Path
    $rawM2 = $rawM.Replace($needle, '<MapaDockV2 slug={slug} mapa={mapa} />')
    WriteUtf8NoBom $mapaV2Path $rawM2
    Write-Host "[OK] patched: MapaV2 agora passa mapa no Dock"
    if ($bk2) { Write-Host ("[BK] " + $bk2) }
  } else {
    Write-Host "[OK] MapaV2: nada pra mudar (padrao <MapaDockV2 slug={slug} /> nao encontrado)."
  }
} else {
  Write-Host "[WARN] MapaV2.tsx nao encontrado."
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
$rep += "# CV — Hotfix v0_44 — Mapa hash (immutability) + Dock props"
$rep += ""
$rep += "## Fixes"
$rep += "- MapaCanvasV2: remove `window.location.hash = ...` (lint react-hooks/immutability)."
$rep += "- Substitui por `history.replaceState(... + #id)` e dispara `hashchange` manualmente."
$rep += "- MapaV2: garante `mapa={mapa}` ao chamar MapaDockV2 quando o padrão antigo existir."
$rep += ""
$rep += "## Arquivos"
$rep += "- src/components/v2/MapaCanvasV2.tsx"
$rep += "- src/components/v2/MapaV2.tsx"
$rep += ""
$rep += "## Verify"
$rep += "- tools/cv-verify.ps1 (guard + lint + build)"
$rep += ""

$rp = WriteReport "cv-hotfix-mapa-hash-immutability-v0_44.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Hotfix v0_44 aplicado."