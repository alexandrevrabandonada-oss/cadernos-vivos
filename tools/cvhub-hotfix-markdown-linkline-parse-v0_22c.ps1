param(
  [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function TestP([string]$p){ Test-Path -LiteralPath $p }

function ResolveRepoHere() {
  $here = (Get-Location).Path
  if (TestP (Join-Path $here "package.json")) { return $here }
  throw ("[STOP] Rode na raiz do repo (package.json). Atual: " + $here)
}

$repo = ResolveRepoHere
$boot = Join-Path $repo "tools\_bootstrap.ps1"
if (TestP $boot) { . $boot }

# fallbacks (se _bootstrap não tiver)
if (-not (Get-Command WL -ErrorAction SilentlyContinue)) { function WL([string]$s){ Write-Host $s } }
if (-not (Get-Command EnsureDir -ErrorAction SilentlyContinue)) { function EnsureDir([string]$p){ if (-not (TestP $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } } }
if (-not (Get-Command WriteUtf8NoBom -ErrorAction SilentlyContinue)) {
  function WriteUtf8NoBom([string]$p,[string]$content){
    $parent = Split-Path -Parent $p
    if ($parent) { EnsureDir $parent }
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($p, $content, $enc)
  }
}
if (-not (Get-Command BackupFile -ErrorAction SilentlyContinue)) {
  function BackupFile([string]$p){
    if (TestP $p) {
      $ts = (Get-Date -Format "yyyyMMdd_HHmmss")
      $bakDir = Join-Path (Get-Location) "tools\_patch_backup"
      EnsureDir $bakDir
      $leaf = Split-Path -Leaf $p
      Copy-Item -LiteralPath $p -Destination (Join-Path $bakDir ($leaf + "." + $ts + ".bak")) -Force
    }
  }
}
if (-not (Get-Command ResolveExe -ErrorAction SilentlyContinue)) {
  function ResolveExe([string]$name){
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { return $cmd.Source }
    return $name
  }
}
if (-not (Get-Command RunNative -ErrorAction SilentlyContinue)) {
  function RunNative([string]$cwd,[string]$exe,[string[]]$args){
    WL ("[RUN] " + $exe + " " + ($args -join " "))
    Push-Location $cwd
    & $exe @args
    $code = $LASTEXITCODE
    Pop-Location
    if ($code -ne 0) { throw ("[STOP] comando falhou (exit " + $code + ")") }
  }
}
if (-not (Get-Command NewReport -ErrorAction SilentlyContinue)) {
  function NewReport([string]$name,[string]$content){
    $repDir = Join-Path $repo "reports"
    EnsureDir $repDir
    $p = Join-Path $repDir $name
    WriteUtf8NoBom $p $content
    return $p
  }
}

$npmExe = ResolveExe "npm.cmd"
$mdLibPath = Join-Path $repo "src\lib\markdown.ts"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] markdown lib: " + $mdLibPath)

if (-not (TestP $mdLibPath)) { throw ("[STOP] Não achei: " + $mdLibPath) }

$raw = Get-Content -LiteralPath $mdLibPath -Raw
if (-not $raw) { throw "[STOP] markdown.ts vazio/inalcançável." }

$lines = $raw -split "`r?`n"

$needle = "s = s.replace(/\[([^\]]+)\]\(([^)]+)\)/g,"
$fixedLine = '  s = s.replace(/\[([^\]]+)\]\(([^)]+)\)/g, ''<a href="$2" target="_blank" rel="noreferrer">$1</a>'');'

$changed = 0
for ($i=0; $i -lt $lines.Count; $i++) {
  if ($lines[$i] -like "*$needle*") {
    $lines[$i] = $fixedLine
    $changed++
  }
}

if ($changed -eq 0) {
  throw "[STOP] Não achei a linha do replace de links no markdown.ts. Me manda as linhas em volta do inline()."
}

BackupFile $mdLibPath
WriteUtf8NoBom $mdLibPath ($lines -join "`n")
WL ("[OK] patched: markdown.ts (linha de links corrigida). hits=" + $changed)

# REPORT (sem backticks para não quebrar o parser do PS)
$rep = @()
$rep += ('# Hotfix — markdown.ts link replace parse v0.22c — ' + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
$rep += ''
$rep += '## O que foi corrigido'
$rep += '- Corrigida a linha do replace de links no inline() (evita \\\" que quebrava o parser).'
$rep += ''
$rep += '## Resultado esperado'
$rep += "- eslint para de reclamar 'Parsing error: , expected' em src/lib/markdown.ts"
$repPath = NewReport "cv-hotfix-markdown-linkline-parse-v0_22c.md" ($rep -join "`n")
WL ("[OK] Report: " + $repPath)

# VERIFY
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