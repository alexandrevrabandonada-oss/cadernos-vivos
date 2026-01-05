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

$layoutDir = Join-Path $repo "src\app\c\[slug]"
$layoutPath = Join-Path $layoutDir "layout.tsx"
$globalsPath = Join-Path $repo "src\app\globals.css"
$repDir = Join-Path $repo "reports"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] layout dir: " + $layoutDir)
WL ("[DIAG] globals: " + $globalsPath)

if (-not (TestP $globalsPath)) { throw ("[STOP] Não achei globals.css: " + $globalsPath) }

# -------------------------
# PATCH 1 — layout por caderno (Universe Shell)
# -------------------------
EnsureDir $layoutDir
if (TestP $layoutPath) { BackupFile $layoutPath }

$layoutLines = @(
'import type { ReactNode } from "react";',
'',
'type LayoutProps = {',
'  children: ReactNode;',
'  params: Promise<{ slug: string }>; // Next 16: params pode ser Promise',
'};',
'',
'export default async function Layout({ children }: LayoutProps) {',
'  // Universo do caderno: o visual base fica aqui (sem acoplar em conteúdo).',
'  return <div className="cv-universe">{children}</div>;',
'}'
) -join "`n"

WriteUtf8NoBom $layoutPath $layoutLines
WL ("[OK] wrote: " + $layoutPath)

# -------------------------
# PATCH 2 — CSS do universo (safe append)
# -------------------------
BackupFile $globalsPath
$raw = Get-Content -LiteralPath $globalsPath -Raw

if ($raw -like "*/* cv-universe */*") {
  WL "[OK] globals.css já contém bloco cv-universe (marker encontrado)."
} else {
  $block = @(
    "",
    "/* cv-universe */",
    ".cv-universe {",
    "  min-height: 100%;",
    "  background-image:",
    "    radial-gradient(900px 500px at 20% 10%, rgba(255,255,255,0.06), transparent 60%),",
    "    radial-gradient(700px 420px at 80% 25%, rgba(255,255,255,0.04), transparent 65%),",
    "    linear-gradient(180deg, rgba(0,0,0,0.0), rgba(0,0,0,0.55));",
    "}"
  ) -join "`n"

  WriteUtf8NoBom $globalsPath ($raw + $block)
  WL "[OK] patched: globals.css (cv-universe appended)"
}

# -------------------------
# REPORT (sem crase/backtick)
# -------------------------
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repDir "cv-engine-3b-universe-shell-v0_8b.md"
$report = @(
  ("# CV Engine-3B — Universe Shell v0.8b — " + $now),
  "",
  "## O que mudou",
  "- Criado layout base do caderno: src/app/c/[slug]/layout.tsx",
  "- Adicionado bloco CSS cv-universe em globals.css (marker: /* cv-universe */)",
  "",
  "## Objetivo",
  "- Dar um pano de fundo/atmosfera comum para todas as páginas do caderno.",
  "- Preparar o terreno para o próximo passo: modos por rota (cada página um universo).",
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
WL "[OK] Engine-3B v0.8b aplicado."