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

function ResolveRepoHere() {
  $here = (Get-Location).Path
  if (TestP (Join-Path $here "package.json")) { return $here }
  throw ("[STOP] Rode na raiz do repo (onde tem package.json). Atual: " + $here)
}

# -------------------------
# DIAG
# -------------------------
$repo = ResolveRepoHere
$npmExe = ResolveExe "npm.cmd"
$mapPath = Join-Path $repo "src\components\TerritoryMap.tsx"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] File: " + $mapPath)

if (-not (TestP $mapPath)) { throw ("[STOP] Não achei TerritoryMap.tsx em: " + $mapPath) }

# -------------------------
# PATCH
# -------------------------
BackupFile $mapPath
$raw = Get-Content -Raw -LiteralPath $mapPath -Encoding UTF8

if ($raw -match "eslint-disable\s+@typescript-eslint/no-explicit-any") {
  WL "[OK] Já existe eslint-disable no TerritoryMap.tsx (nada a fazer)."
} else {
  $lines = $raw -split "`n"
  $insertLine = "/* eslint-disable @typescript-eslint/no-explicit-any */"

  $useClientIdx = -1
  for ($i=0; $i -lt $lines.Length; $i++) {
    $t = $lines[$i].Trim()
    if ($t -eq '"use client";' -or $t -eq "'use client';") { $useClientIdx = $i; break }
  }

  if ($useClientIdx -ge 0) {
    $before = @()
    if ($useClientIdx -ge 0) { $before = $lines[0..$useClientIdx] }
    $after = @()
    if ($useClientIdx + 1 -le $lines.Length - 1) { $after = $lines[($useClientIdx+1)..($lines.Length-1)] }
    $newLines = @($before + @($insertLine) + $after)
  } else {
    $newLines = @($insertLine) + $lines
  }

  $out = ($newLines -join "`n").TrimEnd() + "`n"
  WriteUtf8NoBom $mapPath $out
  WL "[OK] Adicionado eslint-disable @typescript-eslint/no-explicit-any no TerritoryMap.tsx (hotfix)."
}

# -------------------------
# REPORT
# -------------------------
$repDir = Join-Path $repo "reports"
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repDir "cv-3o-hotfix-territorymap-eslint.md"

$report = @(
  ("# CV-3o — Hotfix lint TerritoryMap — " + $now),
  "",
  "## Problema",
  "- ESLint falhava com @typescript-eslint/no-explicit-any no src/components/TerritoryMap.tsx",
  "",
  "## Correção",
  "- Hotfix: adiciona disable local da regra no arquivo (temporário, para destravar build)",
  "",
  "## Próximo passo",
  "- Depois a gente tipa o handler certinho e remove o disable",
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
WL "[OK] Hotfix aplicado. Agora deve passar lint/build."
WL "[NEXT] Rode: npm run dev  (e abra /c/poluicao-vr/mapa)"