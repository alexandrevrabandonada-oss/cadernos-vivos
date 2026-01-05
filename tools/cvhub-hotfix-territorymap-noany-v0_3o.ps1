param(
  [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function WL([string]$s) { Write-Host $s }
function EnsureDir([string]$p) { if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function WriteUtf8NoBom([string]$p, [string]$content) {
  $parent = Split-Path -Parent $p
  if ($parent) { EnsureDir $parent }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($p, $content, $enc)
}
function BackupFile([string]$p) {
  if (Test-Path -LiteralPath $p) {
    $ts = (Get-Date -Format "yyyyMMdd_HHmmss")
    $bakDir = Join-Path (Get-Location) "tools\_patch_backup"
    EnsureDir $bakDir
    $leaf = Split-Path -Leaf $p
    Copy-Item -LiteralPath $p -Destination (Join-Path $bakDir ($leaf + "." + $ts + ".bak")) -Force
  }
}
function ResolveExe([string]$name) {
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
  if (Test-Path -LiteralPath (Join-Path $here "package.json")) { return $here }
  $p1 = Split-Path -Parent $here
  if ($p1 -and (Test-Path -LiteralPath (Join-Path $p1 "package.json"))) { return $p1 }
  throw ("[STOP] Rode na raiz do repo (onde tem package.json). Atual: " + $here)
}

# -------------------------
# DIAG
# -------------------------
$repo = ResolveRepoHere
$npmExe = ResolveExe "npm.cmd"
$f = Join-Path $repo "src\components\TerritoryMap.tsx"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] File: " + $f)

if (-not (Test-Path -LiteralPath $f)) { throw ("[STOP] Não achei: " + $f) }

# -------------------------
# PATCH
# -------------------------
BackupFile $f
$raw = Get-Content -LiteralPath $f -Raw

$from = 'setKind((e.target.value as any) || "")'
$to   = 'setKind((e.target.value as MapPoint["kind"] | "") || "")'

if ($raw.Contains($from)) {
  $raw2 = $raw.Replace($from, $to)
  WriteUtf8NoBom $f $raw2
  WL "[OK] Substituído cast any -> MapPoint['kind'] | ''"
} else {
  # fallback: se mudou um pouco, remove só o "as any"
  if ($raw.Contains(' as any')) {
    $raw2 = $raw.Replace(' as any', ' as MapPoint["kind"] | ""')
    WriteUtf8NoBom $f $raw2
    WL "[OK] Fallback aplicado: removeu 'as any'"
  } else {
    throw "[STOP] Não encontrei o trecho com 'as any' para corrigir."
  }
}

# -------------------------
# REPORT
# -------------------------
$repDir = Join-Path $repo "reports"
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repDir "cv-3o-hotfix-territorymap-noany.md"
$report = @(
  ("# CV-3o — Hotfix ESLint (no-explicit-any) — " + $now),
  "",
  "## Problema",
  "- ESLint: @typescript-eslint/no-explicit-any em TerritoryMap.tsx",
  "",
  "## Correção",
  "- Troca do cast `as any` por `as MapPoint['kind'] | ''` no select de categoria",
  "",
  "## Verify",
  "- npm run lint",
  "- npm run build"
) -join "`n"
WriteUtf8NoBom $reportPath $report
WL ("[OK] Report: " + $reportPath)

# -------------------------
# VERIFY
# -------------------------
WL "[VERIFY] npm run lint..."
RunNative $repo $npmExe @("run","lint")

if (-not $SkipBuild) {
  WL "[VERIFY] npm run build..."
  RunNative $repo $npmExe @("run","build")
} else {
  WL "[VERIFY] build pulado (-SkipBuild)."
}

WL ""
WL "[OK] Hotfix aplicado. Segue o baile."