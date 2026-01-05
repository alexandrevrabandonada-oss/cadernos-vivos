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

$readingPath = Join-Path $repo "src\components\ReadingControls.tsx"
$libPath     = Join-Path $repo "src\lib\cadernos.ts"
$repDir      = Join-Path $repo "reports"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] ReadingControls: " + $readingPath)
WL ("[DIAG] cadernos.ts: " + $libPath)

# -------------------------
# PATCH 1: remover eslint-disable inutil em ReadingControls
# -------------------------
$didReading = $false
if (TestP $readingPath) {
  $raw = Get-Content -LiteralPath $readingPath -Raw
  if ($null -eq $raw) { throw "[STOP] ReadingControls.tsx veio nulo" }

  $lines = $raw -split "(`r`n|`n)"
  $out = New-Object System.Collections.Generic.List[string]

  foreach ($ln in $lines) {
    $t = $ln.Trim()
    if ($t -eq "/* eslint-disable react/no-unescaped-entities */") { $didReading = $true; continue }
    if ($t -eq "// eslint-disable react/no-unescaped-entities") { $didReading = $true; continue }
    $out.Add($ln) | Out-Null
  }

  if ($didReading) {
    BackupFile $readingPath
    WriteUtf8NoBom $readingPath (($out.ToArray()) -join "`n")
    WL "[OK] patched: ReadingControls.tsx (removeu eslint-disable inutil)"
  } else {
    WL "[OK] ReadingControls.tsx sem mudanca (nao tinha eslint-disable inutil)"
  }
} else {
  WL "[WARN] ReadingControls.tsx nao encontrado (pulei)"
}

# -------------------------
# PATCH 2: cadernos.ts — evitar warnings de parsers "defined but never used"
# (até ligarmos isso no motor de leitura de JSON)
# -------------------------
$didLib = $false
if (TestP $libPath) {
  $raw2 = Get-Content -LiteralPath $libPath -Raw
  if ($null -eq $raw2) { throw "[STOP] cadernos.ts veio nulo" }

  $hasMapa   = ($raw2 -match "parseMapaJson")
  $hasDebate = ($raw2 -match "parseDebateJson")
  $hasAcervo = ($raw2 -match "parseAcervoJson")
  $hasMarker = ($raw2 -match "cv-keep-parsers")

  if ($hasMapa -and $hasDebate -and $hasAcervo -and (-not $hasMarker)) {
    $keep = @(
      "",
      "// cv-keep-parsers: mantém helpers referenciados (evita ruído no lint) até ligarmos no motor",
      "function __cv_keep_parsers() {",
      "  void parseMapaJson;",
      "  void parseDebateJson;",
      "  void parseAcervoJson;",
      "}",
      "__cv_keep_parsers();",
      ""
    ) -join "`n"

    BackupFile $libPath
    WriteUtf8NoBom $libPath ($raw2 + $keep)
    $didLib = $true
    WL "[OK] patched: cadernos.ts (keep-parsers adicionada)"
  } else {
    if ($hasMarker) { WL "[OK] cadernos.ts já tinha keep-parsers" }
    else { WL "[OK] cadernos.ts sem mudanca (parsers nao encontrados juntos ou ja resolvido)" }
  }
} else {
  WL "[WARN] cadernos.ts nao encontrado (pulei)"
}

# -------------------------
# REPORT
# -------------------------
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repDir "cv-engine-3g-lint-zero-warnings-v0_13.md"
$report = @(
  ("# CV Engine-3G — Lint Zero Warnings v0.13 — " + $now),
  "",
  "## Mudanças",
  ("- ReadingControls: removeu eslint-disable inutil: " + [string]$didReading),
  ("- cadernos.ts: keep-parsers adicionada: " + [string]$didLib),
  "",
  "## Próximo",
  "- Engine-3H: mood do Universo vindo do meta.json do caderno (não por heurística do slug)",
  "- UniverseHeader por seção (Mapa/Debate/Trilha/Registro) + acessibilidade consistente",
  ""
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
WL "[OK] Engine-3G aplicado (meta: lint limpo)."