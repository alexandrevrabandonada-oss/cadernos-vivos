$ErrorActionPreference = "Stop"

function _NowTag { Get-Date -Format "yyyyMMdd-HHmmss" }

# Bootstrap (se existir) + fallbacks
$boot = Join-Path $PSScriptRoot "_bootstrap.ps1"
if (Test-Path -LiteralPath $boot) { . $boot }

if (-not (Get-Command EnsureDir -ErrorAction SilentlyContinue)) {
  function EnsureDir([string]$p) { if ($p -and -not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
}
if (-not (Get-Command WriteUtf8NoBom -ErrorAction SilentlyContinue)) {
  function WriteUtf8NoBom([string]$p, [string]$t) {
    EnsureDir (Split-Path -Parent $p)
    [IO.File]::WriteAllText($p, $t, [Text.UTF8Encoding]::new($false))
  }
}
if (-not (Get-Command BackupFile -ErrorAction SilentlyContinue)) {
  function BackupFile([string]$p) {
    if (-not (Test-Path -LiteralPath $p)) { return $null }
    $bkDir = Join-Path $PSScriptRoot "_patch_backup"
    EnsureDir $bkDir
    $ts = Get-Date -Format "yyyyMMdd-HHmmss"
    $leaf = Split-Path -Leaf $p
    $dst = Join-Path $bkDir ($ts + "-" + $leaf + ".bak")
    Copy-Item -LiteralPath $p -Destination $dst -Force
    return $dst
  }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$stamp = _NowTag
Write-Host ("== cv-step-b5g-v2-hub-dedup-v0_1 == " + $stamp)
Write-Host ("[DIAG] Repo: " + $repoRoot)

$hubRel = "src/app/c/[slug]/v2/page.tsx"
$hubAbs = Join-Path $repoRoot $hubRel
if (-not (Test-Path -LiteralPath $hubAbs)) { throw ("[STOP] não achei: " + $hubAbs) }

$mmRel = "src/components/v2/Cv2MindmapHubClient.tsx"
$mmAbs = Join-Path $repoRoot $mmRel
if (-not (Test-Path -LiteralPath $mmAbs)) { Write-Host ("[WARN] não achei mindmap client: " + $mmRel) }

# ---------------------------
# PATCH 1: remover Hub antigo duplicado (bloco com a frase "Explore o universo por portas.")
# ---------------------------
$hubRaw = Get-Content -Raw -LiteralPath $hubAbs
$needle = "Explore o universo por portas"
$idx = $hubRaw.IndexOf($needle, [StringComparison]::Ordinal)

if ($idx -lt 0) {
  Write-Host "[SKIP] Não encontrei o bloco antigo (needle não apareceu)."
  $hubNew = $hubRaw
} else {
  $start = $hubRaw.LastIndexOf("<h1", $idx, [StringComparison]::Ordinal)
  if ($start -lt 0) {
    # fallback: tenta achar um wrapper comum caso não tenha <h1
    $start = $hubRaw.LastIndexOf("SEU-SLUG", $idx, [StringComparison]::Ordinal)
    if ($start -lt 0) { throw "[STOP] achei o needle mas não consegui localizar início do bloco antigo (sem <h1/SEU-SLUG antes)." }
  }

  $end = $hubRaw.IndexOf("</Cv2Shell>", $idx, [StringComparison]::Ordinal)
  if ($end -lt 0) { $end = $hubRaw.IndexOf("</main>", $idx, [StringComparison]::Ordinal) }
  if ($end -lt 0) { throw "[STOP] não consegui achar o fim do bloco (sem </Cv2Shell> ou </main> depois do needle)." }

  $bk = BackupFile $hubAbs
  if ($bk) { Write-Host ("[BK]    tools/_patch_backup/" + (Split-Path -Leaf $bk)) }

  $hubNew = $hubRaw.Remove($start, ($end - $start))

  # deixa um marcador discreto (sem mexer em JSX)
  $hubNew = $hubNew.Insert($start, "`n      {/* CV2_LEGACY_HUB_REMOVIDO */}`n")

  WriteUtf8NoBom $hubAbs $hubNew
  Write-Host ("[PATCH] " + $hubRel + " (removeu bloco antigo duplicado)")
}

# ---------------------------
# PATCH 2: corrigir lint do Mindmap (useCallback deps include 'focus')
# ---------------------------
$mmPatched = $false
if (Test-Path -LiteralPath $mmAbs) {
  $mmRaw = Get-Content -Raw -LiteralPath $mmAbs
  # Só mexe se existir o padrão e ainda não tiver focus no deps
  if ($mmRaw -match "const onKeyDown\s*=\s*React\.useCallback" -and $mmRaw -match "\},\s*\[\s*active\s*,\s*nodes\.length\s*\]\s*\)\s*;" -and $mmRaw -notmatch "\},\s*\[\s*active\s*,\s*nodes\.length\s*,\s*focus\s*\]\s*\)\s*;") {
    $bk2 = BackupFile $mmAbs
    if ($bk2) { Write-Host ("[BK]    tools/_patch_backup/" + (Split-Path -Leaf $bk2)) }

    $mmNew = [regex]::Replace(
      $mmRaw,
      "\},\s*\[\s*active\s*,\s*nodes\.length\s*\]\s*\)\s*;",
      "}, [active, nodes.length, focus]);"
    )
    WriteUtf8NoBom $mmAbs $mmNew
    $mmPatched = $true
    Write-Host ("[PATCH] " + $mmRel + " (deps do onKeyDown agora incluem focus)")
  } else {
    Write-Host "[SKIP] Mindmap deps já ok (ou padrão diferente)."
  }
}

# ---------------------------
# VERIFY
# ---------------------------
$verify = Join-Path $repoRoot "tools/cv-verify.ps1"
if (Test-Path -LiteralPath $verify) {
  Write-Host ("[RUN] " + $verify)
  & (Get-Command pwsh.exe -ErrorAction Stop).Path -NoProfile -ExecutionPolicy Bypass -File $verify
  if ($LASTEXITCODE -ne 0) { throw ("[STOP] cv-verify falhou (exit=" + $LASTEXITCODE + ")") }
} else {
  $npm = (Get-Command npm.cmd -ErrorAction Stop).Path
  Write-Host "[RUN] npm run lint"
  $lintOut = (& $npm run lint 2>&1 | Out-String)
  if ($LASTEXITCODE -ne 0) { Write-Host $lintOut; throw "[STOP] lint falhou" }

  Write-Host "[RUN] npm run build"
  $buildOut = (& $npm run build 2>&1 | Out-String)
  if ($LASTEXITCODE -ne 0) { Write-Host $buildOut; throw "[STOP] build falhou" }
}

# ---------------------------
# REPORT
# ---------------------------
$repDir = Join-Path $repoRoot "reports"
EnsureDir $repDir
$rep = Join-Path $repDir ($stamp + "-cv-step-b5g-v2-hub-dedup.md")

$body = @(
  ("# CV B5G — V2 Hub dedup (remove bloco antigo) — " + $stamp),
  "",
  ("Repo: " + $repoRoot),
  "",
  "## PATCH",
  ("- " + $hubRel + " (removeu bloco duplicado 'Explore o universo por portas')"),
  ("- " + $mmRel + " (deps do onKeyDown incluem focus)"),
  "",
  "## VERIFY",
  "- cv-verify/lint/build: OK (se este script terminou sem STOP)"
) -join "`n"

WriteUtf8NoBom $rep $body
Write-Host ("[REPORT] reports\" + (Split-Path -Leaf $rep))
Write-Host "[OK] B5G concluído (Hub sem duplicação + mindmap lint ajustado)."