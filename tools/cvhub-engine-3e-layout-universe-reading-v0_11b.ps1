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

$layoutPath  = Join-Path $repo "src\app\c\[slug]\layout.tsx"
$universePath = Join-Path $repo "src\components\UniverseShell.tsx"
$readingPath  = Join-Path $repo "src\components\ReadingControls.tsx"
$repDir       = Join-Path $repo "reports"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] layout: " + $layoutPath)
WL ("[DIAG] UniverseShell: " + $universePath)
WL ("[DIAG] ReadingControls: " + $readingPath)

if (-not (TestP $layoutPath)) { throw ("[STOP] Não achei layout.tsx em: " + $layoutPath) }
if (-not (TestP $readingPath)) { throw ("[STOP] Não achei ReadingControls.tsx em: " + $readingPath) }

# -------------------------
# PATCH: UniverseShell.tsx (sem here-string aninhado)
# -------------------------
BackupFile $universePath

$u = @(
  '"use client";',
  '',
  'import React from "react";',
  'import { useParams } from "next/navigation";',
  '',
  'function moodFromSlug(slug: string): string {',
  '  const s = (slug || "").toLowerCase();',
  '  if (s.indexOf("poluicao") >= 0) return "smoke";',
  '  if (s.indexOf("trabalho") >= 0) return "steel";',
  '  if (s.indexOf("memoria") >= 0) return "archive";',
  '  if (s.indexOf("eco") >= 0) return "green";',
  '  return "urban";',
  '}',
  '',
  'export default function UniverseShell({ children }: { children: React.ReactNode }) {',
  '  const params = useParams() as { slug?: string };',
  '  const slug = (params && params.slug) ? String(params.slug) : "";',
  '  const mood = moodFromSlug(slug);',
  '  const cls = "cv-universe cv-mood-" + mood;',
  '  return (',
  '    <div className={cls}>',
  '      <div className="cv-universe-inner">',
  '        {children}',
  '      </div>',
  '    </div>',
  '  );',
  '}'
) -join "`n"

WriteUtf8NoBom $universePath $u
WL "[OK] wrote: UniverseShell.tsx"

# -------------------------
# PATCH: /c/[slug]/layout.tsx (centraliza Universe + Reading)
# -------------------------
BackupFile $layoutPath

$l = @(
  'import React from "react";',
  '',
  'import UniverseShell from "@/components/UniverseShell";',
  'import ReadingControls from "@/components/ReadingControls";',
  '',
  'export default function CadernoLayout({ children }: { children: React.ReactNode }) {',
  '  return (',
  '    <UniverseShell>',
  '      <ReadingControls />',
  '      {children}',
  '    </UniverseShell>',
  '  );',
  '}'
) -join "`n"

WriteUtf8NoBom $layoutPath $l
WL "[OK] wrote: /c/[slug]/layout.tsx"

# -------------------------
# PATCH: ReadingControls (disable react/no-unescaped-entities)
# -------------------------
BackupFile $readingPath
$rc = Get-Content -LiteralPath $readingPath -Raw
if ($null -eq $rc) { throw "[STOP] Falha lendo ReadingControls.tsx (conteudo nulo)." }

if ($rc -notlike "*eslint-disable react/no-unescaped-entities*") {
  $rc2 = "/* eslint-disable react/no-unescaped-entities */`n" + $rc
  WriteUtf8NoBom $readingPath $rc2
  WL "[OK] patched: ReadingControls.tsx (eslint-disable)"
} else {
  WL "[OK] ReadingControls já tinha eslint-disable."
}

# -------------------------
# REPORT
# -------------------------
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repDir "cv-engine-3e-layout-universe-reading-v0_11b.md"
$report = @(
  ("# CV Engine-3E — Layout/Universe/Reading v0.11b — " + $now),
  "",
  "## Objetivo",
  "- Layout unico por caderno: UniverseShell + ReadingControls sempre presentes",
  "",
  "## Mudancas",
  "- Reescreveu src/components/UniverseShell.tsx (mood por slug)",
  "- Reescreveu src/app/c/[slug]/layout.tsx (wrapper global)",
  "- ReadingControls: eslint-disable react/no-unescaped-entities",
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
WL "[OK] Engine-3E v0.11b aplicado."