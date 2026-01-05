$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Write-Host ("[DIAG] Repo: " + $repo)

$bootstrap = Join-Path $PSScriptRoot "_bootstrap.ps1"
if (Test-Path -LiteralPath $bootstrap) { . $bootstrap; Write-Host ("[DIAG] Bootstrap: " + $bootstrap) }

if (-not (Get-Command EnsureDir -ErrorAction SilentlyContinue)) {
  function EnsureDir([string]$p) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}
if (-not (Get-Command WriteUtf8NoBom -ErrorAction SilentlyContinue)) {
  function WriteUtf8NoBom([string]$p, [string]$t) {
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($p, $t, $enc)
  }
}
if (-not (Get-Command BackupFile -ErrorAction SilentlyContinue)) {
  function BackupFile([string]$p) {
    if (-not (Test-Path -LiteralPath $p)) { return $null }
    $bkDir = Join-Path $repo "tools\_patch_backup"
    EnsureDir $bkDir
    $ts = Get-Date -Format "yyyyMMdd-HHmmss"
    $leaf = Split-Path -Leaf $p
    $bk = Join-Path $bkDir ($ts + "-" + $leaf + ".bak")
    Copy-Item -LiteralPath $p -Destination $bk -Force
    return $bk
  }
}
if (-not (Get-Command RunPs1 -ErrorAction SilentlyContinue)) {
  function RunPs1([string]$p) {
    & $PSHOME\pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $p
    if ($LASTEXITCODE -ne 0) { throw ("[STOP] RunPs1 falhou (exit " + $LASTEXITCODE + "): " + $p) }
  }
}
if (-not (Get-Command WriteReport -ErrorAction SilentlyContinue)) {
  function WriteReport([string]$name, [string]$content) {
    $dir = Join-Path $repo "reports"
    EnsureDir $dir
    $p = Join-Path $dir $name
    WriteUtf8NoBom $p $content
    return $p
  }
}

# -----------------------
# 1) Fix active key: linha-do-tempo -> linhaTempo
# -----------------------
$linhaPage = Join-Path $repo "src\app\c\[slug]\v2\linha-do-tempo\page.tsx"
Write-Host ("[DIAG] LinhaPage: " + $linhaPage)

$changedLinha = $false
$bk1 = $null

if (Test-Path -LiteralPath $linhaPage) {
  $raw = Get-Content -LiteralPath $linhaPage -Raw
  if ($raw -match 'active="linha-do-tempo"') {
    $bk1 = BackupFile $linhaPage
    $raw2 = $raw.Replace('active="linha-do-tempo"', 'active="linhaTempo"')
    WriteUtf8NoBom $linhaPage $raw2
    $changedLinha = $true
    Write-Host ("[OK] patched active linhaTempo: " + $linhaPage)
    if ($bk1) { Write-Host ("[BK] " + $bk1) }
  } else {
    Write-Host "[OK] LinhaPage: nada pra mudar (active linha-do-tempo nao encontrado)."
  }
} else {
  Write-Host "[WARN] LinhaPage nao encontrada (ok se voce nao usa essa rota ainda)."
}

# -----------------------
# 2) V2Nav: remove unused i no map
# -----------------------
$v2nav = Join-Path $repo "src\components\v2\V2Nav.tsx"
Write-Host ("[DIAG] V2Nav: " + $v2nav)

$changedNav = $false
$bk2 = $null

if (Test-Path -LiteralPath $v2nav) {
  $rawN = Get-Content -LiteralPath $v2nav -Raw

  # troca ".map((it, i) =>" por ".map((it) =>" (tira param i não usado)
  $rawN2 = $rawN -replace '\.map\(\(\s*it\s*,\s*i\s*\)\s*=>', '.map((it) =>'

  if ($rawN2 -ne $rawN) {
    $bk2 = BackupFile $v2nav
    WriteUtf8NoBom $v2nav $rawN2
    $changedNav = $true
    Write-Host ("[OK] patched: remove unused i em map: " + $v2nav)
    if ($bk2) { Write-Host ("[BK] " + $bk2) }
  } else {
    Write-Host "[OK] V2Nav: nada pra mudar (padrao i nao encontrado)."
  }
} else {
  throw ("[STOP] V2Nav.tsx nao encontrado: " + $v2nav)
}

# -----------------------
# 3) VERIFY
# -----------------------
$verify = Join-Path $repo "tools\cv-verify.ps1"
if (Test-Path -LiteralPath $verify) {
  Write-Host ("[RUN] " + $verify)
  RunPs1 $verify
} else {
  Write-Host ("[WARN] verify nao encontrado: " + $verify)
}

# -----------------------
# 4) REPORT
# -----------------------
$rep = @()
$rep += "# CV — Hotfix v0_43 — V2Nav active linhaTempo + remove unused i"
$rep += ""
$rep += "## Fixes"
$rep += "- page /v2/linha-do-tempo: active='linhaTempo' (alinha com NavKey)."
$rep += "- V2Nav.tsx: remove param i nao usado no map (lint)."
$rep += ""
$rep += "## Arquivos"
$rep += "- src/app/c/[slug]/v2/linha-do-tempo/page.tsx"
$rep += "- src/components/v2/V2Nav.tsx"
$rep += ""
$rep += "## Verify"
$rep += "- tools/cv-verify.ps1 (guard + lint + build)"
$rep += ""

$rp = WriteReport "cv-hotfix-v2nav-linhatempo-active-v0_43.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Hotfix v0_43 aplicado."