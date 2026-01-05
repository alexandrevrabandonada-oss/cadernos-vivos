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

$layoutPath = Join-Path $repo "src\app\c\[slug]\layout.tsx"
$universePath = Join-Path $repo "src\components\UniverseShell.tsx"
$repDir = Join-Path $repo "reports"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] layout: " + $layoutPath)
WL ("[DIAG] UniverseShell: " + $universePath)

if (-not (TestP $layoutPath)) { throw ("[STOP] Não achei layout: " + $layoutPath) }
if (-not (TestP $universePath)) { WL "[WARN] UniverseShell.tsx não encontrado (mas vamos corrigir import do layout mesmo assim)." }

# -------------------------
# PATCH
# -------------------------
BackupFile $layoutPath
$raw = Get-Content -LiteralPath $layoutPath -Raw

$needsUse = ($raw -like "*<UniverseShell*")
$hasImport = ($raw -like "*import UniverseShell from*")

if (-not $needsUse) {
  WL "[OK] layout não usa <UniverseShell> (nada a fazer)."
} elseif ($hasImport) {
  WL "[OK] import de UniverseShell já existe (nada a fazer)."
} else {
  $importLine = 'import UniverseShell from "@/components/UniverseShell";'
  $lines = $raw -split "`r?`n"

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

  $newRaw = ($out.ToArray() -join "`n")
  WriteUtf8NoBom $layoutPath $newRaw
  WL "[OK] import de UniverseShell adicionado no layout."
}

# -------------------------
# REPORT
# -------------------------
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repDir "cv-engine-3c-hotfix-universeshell-import-v0_9b.md"
$report = @(
  ("# CV Engine-3C — Hotfix import UniverseShell v0.9b — " + $now),
  "",
  "## Problema",
  "- ESLint react/jsx-no-undef: UniverseShell usado no layout sem import",
  "",
  "## Correção",
  "- Inserido: import UniverseShell from ""@/components/UniverseShell""",
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
WL "[OK] Hotfix aplicado."