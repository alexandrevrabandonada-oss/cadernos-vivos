# CV — Hotfix — MapaCanvasV2 (immutability) + V2Nav keys — v0_41
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

$toolsDir = if ($PSScriptRoot -and (Test-Path -LiteralPath $PSScriptRoot)) { $PSScriptRoot } else { Join-Path (Get-Location) "tools" }
$repo = (Resolve-Path (Join-Path $toolsDir "..")).Path
. (Join-Path $toolsDir "_bootstrap.ps1")

Write-Host ("[DIAG] Repo: " + $repo)

function PatchFile([string]$p, [scriptblock]$fn) {
  if (-not (Test-Path -LiteralPath $p)) { Write-Host ("[SKIP] missing: " + $p); return $false }
  $raw = Get-Content -LiteralPath $p -Raw
  if (-not $raw) { throw ("[STOP] arquivo vazio/ilegivel: " + $p) }
  $next = & $fn $raw
  if ($null -eq $next) { Write-Host ("[SKIP] no-op: " + $p); return $false }
  if ($next -eq $raw) { Write-Host ("[OK] no change: " + $p); return $false }
  $bk = BackupFile $p
  WriteUtf8NoBom $p $next
  Write-Host ("[OK] patched: " + $p)
  if ($bk) { Write-Host ("[BK] " + $bk) }
  return $true
}

# ------------------------------------------------------------
# 1) Fix: MapaCanvasV2 — remove assignment em window.location.hash
# ------------------------------------------------------------
$canvasPath = Join-Path $repo "src\components\v2\MapaCanvasV2.tsx"
PatchFile $canvasPath {
  param($raw)

  $o = $raw

  # troca o assignment por history.replaceState (sem mutar window.location.hash diretamente)
  if ($o -match 'window\.location\.hash\s*=\s*id\s*;') {
    $o = [regex]::Replace($o, 'window\.location\.hash\s*=\s*id\s*;', 'history.replaceState(null, "", "#" + id);')
  }

  return $o
} | Out-Null

# ------------------------------------------------------------
# 2) Fix: V2Nav — remove i não usado + key mais robusta
# ------------------------------------------------------------
$v2navPath = Join-Path $repo "src\components\v2\V2Nav.tsx"
PatchFile $v2navPath {
  param($raw)

  $o = $raw

  # .map((it, i) =>  -> .map((it) =>
  $o = $o.Replace('.map((it, i) => {', '.map((it) => {')

  # key={it.key} -> key={it.key + "-" + it.href}
  $o = $o.Replace('key={it.key}', 'key={it.key + "-" + it.href}')

  return $o
} | Out-Null

# ------------------------------------------------------------
# VERIFY
# ------------------------------------------------------------
RunPs1 (Join-Path $repo "tools\cv-verify.ps1")

# ------------------------------------------------------------
# REPORT
# ------------------------------------------------------------
$rep = @(
  '# CV — Hotfix v0_41 — MapaCanvasV2 immutability + V2Nav keys',
  '',
  '## Causa',
  '- ESLint react-hooks/immutability bloqueia assignment em window.location.hash.',
  '- V2Nav tinha indice i nao usado e warning de keys em runtime.',
  '',
  '## Fix',
  '- MapaCanvasV2: window.location.hash = id -> history.replaceState(null, "", "#" + id)',
  '- V2Nav: remove i do map + key fica it.key + "-" + it.href',
  '',
  '## Arquivos',
  '- src/components/v2/MapaCanvasV2.tsx',
  '- src/components/v2/V2Nav.tsx',
  '',
  '## Verify',
  '- tools/cv-verify.ps1 (guard + lint + build)',
  ''
) -join "`n"

WriteReport "cv-hotfix-mapa-immutability-v2nav-keys-v0_41.md" $rep | Out-Null
Write-Host "[OK] v0_41 aplicado e verificado."