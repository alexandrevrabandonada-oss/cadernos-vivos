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
$mapPath = Join-Path $repo "src\app\c\[slug]\mapa\page.tsx"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] File: " + $mapPath)

if (-not (TestP $mapPath)) { throw ("[STOP] Não achei: " + $mapPath) }

$raw = Get-Content -LiteralPath $mapPath -Raw
if ($null -eq $raw -or $raw.Trim().Length -eq 0) { throw "[STOP] page.tsx vazio ou não lido." }

# Mostra primeiras linhas p/ confirmar
$preview = $raw -split "`r?`n"
WL "[DIAG] Preview (linhas 1-25):"
for ($i=0; $i -lt [Math]::Min(25, $preview.Count); $i++) {
  $n = $i + 1
  WL ((("{0,3}" -f $n) + " | " + $preview[$i]))
}

# -------------------------
# PATCH — rebuild imports apenas
# -------------------------
BackupFile $mapPath

$lines = $raw -split "`r?`n"

# Acha faixa de imports (primeiro import até último import consecutivo)
$firstImport = -1
$lastImport  = -1

for ($i=0; $i -lt $lines.Count; $i++) {
  $t = $lines[$i].TrimStart()
  if ($t.StartsWith("import ")) {
    if ($firstImport -lt 0) { $firstImport = $i }
    $lastImport = $i
  } elseif ($firstImport -ge 0) {
    # para no primeiro não-import depois de começar
    break
  }
}

if ($firstImport -lt 0) { throw "[STOP] Não achei bloco de imports para corrigir." }

# Mantém imports que NÃO sejam dos componentes (e também remove qualquer import quebrado citando CadernoHeader/NavPills/TerritoryMap)
$kept = New-Object System.Collections.Generic.List[string]
for ($i=0; $i -le $lastImport; $i++) {
  $ln = $lines[$i]
  $low = $ln.ToLowerInvariant()
  $isBadComp =
    ($low.Contains("cadernoheader")) -or
    ($low.Contains("navpills")) -or
    ($low.Contains("territorymap")) -or
    ($low.Contains("@/components/cadernoheader")) -or
    ($low.Contains("@/components/navpills")) -or
    ($low.Contains("@/components/territorymap"))

  if (-not $isBadComp) {
    $kept.Add($ln) | Out-Null
  }
}

# Agora injeta imports canônicos (sem quebrar parser)
$canon = @(
  'import CadernoHeader from "@/components/CadernoHeader";',
  'import NavPills from "@/components/NavPills";',
  'import TerritoryMap from "@/components/TerritoryMap";',
  'import type { MapPoint } from "@/components/TerritoryMap";'
)

# Evita duplicar se já existir igual (caso raro)
$canonFinal = New-Object System.Collections.Generic.List[string]
foreach ($c in $canon) {
  $exists = $false
  foreach ($k in $kept) {
    if ($k.Trim() -eq $c) { $exists = $true; break }
  }
  if (-not $exists) { $canonFinal.Add($c) | Out-Null }
}

# Reconstrói arquivo: mantém tudo antes do firstImport, depois kept+canon, depois o restante após lastImport
$before = @()
if ($firstImport -gt 0) { $before = $lines[0..($firstImport-1)] }

$after = @()
if ($lastImport + 1 -lt $lines.Count) { $after = $lines[($lastImport+1)..($lines.Count-1)] }

$newLines = @()
$newLines += $before
$newLines += $kept.ToArray()
$newLines += $canonFinal.ToArray()
$newLines += $after

$newRaw = ($newLines -join "`n")

WriteUtf8NoBom $mapPath $newRaw
WL "[OK] Imports do mapa/page.tsx reconstruídos."

# -------------------------
# REPORT
# -------------------------
$repDir = Join-Path $repo "reports"
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repDir "cv-4f-hotfix-mapa-page-imports.md"
$report = @(
  "# CV-4f — Hotfix imports mapa/page.tsx — " + $now,
  "",
  "## Problema",
  "- ESLint parsing error em src/app/c/[slug]/mapa/page.tsx (import quebrado).",
  "",
  "## Correção",
  "- Reconstruído bloco de imports removendo linhas ruins e inserindo imports canônicos:",
  "  - CadernoHeader (default)",
  "  - NavPills (default)",
  "  - TerritoryMap (default) + MapPoint (type)",
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
WL "[OK] Hotfix aplicado. Se passar, seguimos pro próximo erro de TS (se aparecer)."