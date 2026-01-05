param(
  [switch]$SkipBuild
)

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

function ResolveRepo() {
  $here = (Get-Location).Path
  if (TestP (Join-Path $here "package.json")) { return $here }

  $child = Join-Path $here "cadernos-vivos"
  if (TestP (Join-Path $child "package.json")) { return $child }

  throw ("[STOP] Rode na raiz do repo (onde tem package.json). Atual: " + $here)
}

# -------------------------
# DIAG
# -------------------------
$repo = ResolveRepo
$npmExe = ResolveExe "npm.cmd"
$debatePage = Join-Path $repo "src\app\c\[slug]\debate\page.tsx"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] Debate page: " + $debatePage)

if (-not (TestP $debatePage)) {
  throw ("[STOP] Não achei: " + $debatePage)
}

# -------------------------
# PATCH
# -------------------------
BackupFile $debatePage
$raw = Get-Content -LiteralPath $debatePage -Raw

# Corrige chamadas do DebateBoard sem slug
$changed = $false

if ($raw -match "<DebateBoard[^>]*prompts=\{prompts\}[^>]*\/>") {
  $raw2 = $raw -replace "<DebateBoard\s+prompts=\{prompts\}\s*\/>", "<DebateBoard slug={slug} prompts={prompts} />"
  if ($raw2 -ne $raw) { $raw = $raw2; $changed = $true }
}

# fallback mais geral: linha que contém "<DebateBoard" sem "slug="
if (-not $changed) {
  $lines = $raw -split "`n"
  for ($i=0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($line -like "*<DebateBoard*" -and $line -like "*prompts={prompts}*" -and $line -notlike "*slug=*") {
      $lines[$i] = $line -replace "<DebateBoard", "<DebateBoard slug={slug}"
      $changed = $true
    }
  }
  $raw = ($lines -join "`n")
}

if (-not $changed) {
  WL "[WARN] Não encontrei um <DebateBoard ...> sem slug pra corrigir (talvez já esteja ok)."
} else {
  WriteUtf8NoBom $debatePage $raw
  WL "[OK] patched: DebateBoard agora recebe slug={slug}."
}

# -------------------------
# REPORT
# -------------------------
$repDir = Join-Path $repo "reports"
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repDir "cv-3i-hotfix-debateboard-slug.md"

$report = @(
  ("# CV-3i — Hotfix DebateBoard slug — " + $now),
  "",
  "## Problema",
  "- Build falhando: DebateBoard exige prop `slug` e a página /c/[slug]/debate não passava.",
  "",
  "## Correção",
  "- Patch em `src/app/c/[slug]/debate/page.tsx`: `<DebateBoard slug={slug} prompts={prompts} />`",
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

WL "[OK] Hotfix aplicado. Re-teste o build e abra /c/poluicao-vr/debate."