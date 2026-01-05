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

function ReplaceFirst([string]$s, [string]$find, [string]$with) {
  $i = $s.IndexOf($find)
  if ($i -lt 0) { return $s }
  return $s.Substring(0, $i) + $with + $s.Substring($i + $find.Length)
}

# -------------------------
# DIAG
# -------------------------
$repo = ResolveRepoHere
$npmExe = ResolveExe "npm.cmd"
$appScope = Join-Path $repo "src\app\c\[slug]"
$layoutPath = Join-Path $appScope "layout.tsx"
$repDir = Join-Path $repo "reports"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] Scope: " + $appScope)
WL ("[DIAG] layout: " + $layoutPath)

if (-not (TestP $layoutPath)) { throw ("[STOP] Não achei layout: " + $layoutPath) }

# achar pages que importam ReadingControls
$pages = @()
if (TestP $appScope) {
  $pages = Get-ChildItem -LiteralPath $appScope -Recurse -File | Where-Object {
    $_.Name -like "page.tsx" -or $_.Name -like "page.jsx" -or $_.Name -like "page.ts" -or $_.Name -like "page.js"
  }
}

$withImport = @()
foreach ($f in $pages) {
  $raw = Get-Content -LiteralPath $f.FullName -Raw
  if ($raw -like "*from*`"@/components/ReadingControls`"*") { $withImport += $f.FullName }
}
WL ("[DIAG] pages com import ReadingControls: " + $withImport.Count)

# -------------------------
# PATCH 1: layout inclui ReadingControls (uma vez)
# -------------------------
BackupFile $layoutPath
$layoutRaw = Get-Content -LiteralPath $layoutPath -Raw

$importLine = 'import ReadingControls from "@/components/ReadingControls";'
$hasImport = ($layoutRaw -like "*import ReadingControls from*")
if (-not $hasImport) {
  # inserir após último import
  $lines = $layoutRaw -split "`r?`n"
  $lastImport = -1
  for ($i=0; $i -lt $lines.Length; $i++) {
    $t = $lines[$i].Trim()
    if ($t.StartsWith("import ") -or $t.StartsWith("import type ")) { $lastImport = $i }
  }

  $out = New-Object System.Collections.Generic.List[string]
  if ($lastImport -ge 0) {
    for ($i=0; $i -lt $lines.Length; $i++) {
      $out.Add($lines[$i])
      if ($i -eq $lastImport) { $out.Add($importLine) }
    }
  } else {
    $out.Add($importLine)
    foreach ($ln in $lines) { $out.Add($ln) }
  }
  $layoutRaw = ($out.ToArray() -join "`n")
  WL "[OK] import ReadingControls adicionado no layout."
} else {
  WL "[OK] layout já tem import ReadingControls."
}

# garantir render: inserir <ReadingControls /> antes do {children} (primeira ocorrência)
if ($layoutRaw -like "*<ReadingControls*") {
  WL "[OK] layout já renderiza <ReadingControls />."
} else {
  $needle = "{children}"
  if ($layoutRaw -like "*$needle*") {
    $layoutRaw = ReplaceFirst $layoutRaw $needle ("<ReadingControls />`n      " + $needle)
    WL "[OK] layout agora injeta <ReadingControls /> antes de {children}."
  } else {
    WL "[WARN] Não achei {children} no layout. (não injetei ReadingControls automaticamente)"
  }
}

WriteUtf8NoBom $layoutPath $layoutRaw

# -------------------------
# PATCH 2: remover imports de ReadingControls das pages (agora é global)
# -------------------------
$removed = 0
foreach ($p in $withImport) {
  BackupFile $p
  $raw = Get-Content -LiteralPath $p -Raw
  $lines = $raw -split "`r?`n"
  $newLines = New-Object System.Collections.Generic.List[string]

  foreach ($ln in $lines) {
    if ($ln -like '*from "@/components/ReadingControls"*') {
      $removed++
    } else {
      $newLines.Add($ln)
    }
  }

  $newRaw = ($newLines.ToArray() -join "`n")
  WriteUtf8NoBom $p $newRaw
  WL ("[OK] removido import ReadingControls: " + $p)
}

# -------------------------
# REPORT
# -------------------------
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repDir "cv-engine-3d-readingcontrols-global-v0_10.md"
$report = @(
  ("# CV Engine-3D — ReadingControls global v0.10 — " + $now),
  "",
  "## Objetivo",
  "- Painel de leitura único por caderno (todas as páginas herdam)",
  "- Remover imports repetidos e warnings de unused-vars",
  "",
  "## Mudanças",
  "- layout.tsx: import + render <ReadingControls /> antes de {children}",
  "- pages: removido import ReadingControls (agora é global)",
  "",
  "## Resultado",
  ("- Imports removidos: " + $removed)
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
WL "[OK] Engine-3D aplicado."