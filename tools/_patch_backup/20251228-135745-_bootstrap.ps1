Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function WL([string]$s) { Write-Host $s }
function TestP([string]$p) { return (Test-Path -LiteralPath $p) }

function EnsureDir([string]$p) {
  if (-not (TestP $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

function WriteUtf8NoBom([string]$p, [string]$content) {
  $parent = Split-Path -Parent $p
  if ($parent) { EnsureDir $parent }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($p, $content, $enc)
}

function BackupFile([string]$p) {
  if (TestP $p) {
    $ts = (Get-Date -Format "yyyyMMdd_HHmmss")
    $bakDir = Join-Path (Get-Location) "tools\_patch_backup"
    EnsureDir $bakDir
    $leaf = Split-Path -Leaf $p
    Copy-Item -LiteralPath $p -Destination (Join-Path $bakDir ($leaf + "." + $ts + ".bak")) -Force
  }
}

function ResolveExe([string]$name) {
  # Preferir wrappers .cmd (evita npm.ps1 interativo no Windows)
  if ($name -eq "npm" -or $name -eq "npm.ps1" -or $name -eq "npm.cmd") {
    $c = Get-Command "npm.cmd" -ErrorAction SilentlyContinue
    if ($c -and $c.Source) { return $c.Source }
    $fallback = Join-Path ${env:ProgramFiles} "nodejs\npm.cmd"
    if (Test-Path -LiteralPath $fallback) { return $fallback }
    return "npm.cmd"
  }
  $cmd = Get-Command $name -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source) { return $cmd.Source }
  return $name
}

function RunNative([string]$cwd, [string]$exe, [string[]]$cmdArgs) {
  $pretty = ($cmdArgs -join " ")
  WL ("[RUN] " + $exe + " " + $pretty)
  Push-Location $cwd
  & $exe @cmdArgs
  $code = $LASTEXITCODE
  Pop-Location
  if ($code -ne 0) { throw ("[STOP] comando falhou (exit " + $code + "): " + $exe + " " + $pretty) }
}

function ResolveRepoHere() {
  $here = (Get-Location).Path
  if (TestP (Join-Path $here "package.json")) { return $here }
  throw ("[STOP] Rode na raiz do repo (onde tem package.json). Atual: " + $here)
}

function ReadJson([string]$p) {
  $raw = Get-Content -LiteralPath $p -Raw -ErrorAction Stop
  return ($raw | ConvertFrom-Json -ErrorAction Stop)
}

function WriteJson([string]$p, $obj) {
  $out = $obj | ConvertTo-Json -Depth 64
  WriteUtf8NoBom $p ($out + "`n")
}

# ---- CV: NewReport helper (auto-added) ----
function NewReport([string]$name, [string[]]$lines) {
  # Espera rodar a partir da raiz do repo
  $repDir = Join-Path (Get-Location) 'reports'
  EnsureDir $repDir
  $p = Join-Path $repDir $name
  WriteUtf8NoBom $p ($lines -join "
")
  return $p
}
# ---- /CV: NewReport helper ----
