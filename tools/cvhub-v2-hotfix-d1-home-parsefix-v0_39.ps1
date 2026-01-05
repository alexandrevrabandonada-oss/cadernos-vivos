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

$pagePath = Join-Path $repo "src\app\c\[slug]\v2\page.tsx"
if (-not (Test-Path -LiteralPath $pagePath)) { throw ("[STOP] não achei: " + $pagePath) }

$raw = Get-Content -LiteralPath $pagePath -Raw

if ($raw -notmatch "filter\(Boolean;") {
  Write-Host "[OK] Nada pra corrigir: 'filter(Boolean;' não encontrado."
} else {
  $bk = BackupFile $pagePath
  $fixed = $raw.Replace("filter(Boolean;", "filter(Boolean);")
  WriteUtf8NoBom $pagePath $fixed
  Write-Host ("[OK] patched: " + $pagePath)
  if ($bk) { Write-Host ("[BK] " + $bk) }
}

$verify = Join-Path $repo "tools\cv-verify.ps1"
if (Test-Path -LiteralPath $verify) {
  Write-Host ("[RUN] " + $verify)
  RunPs1 $verify
} else {
  Write-Host ("[WARN] verify não encontrado: " + $verify)
}

Write-Host "[OK] Hotfix v0_39 aplicado."