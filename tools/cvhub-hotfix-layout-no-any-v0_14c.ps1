param([switch]$SkipBuild)

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
$repDir = Join-Path $repo "reports"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] layout: " + $layoutPath)

if (-not (TestP $layoutPath)) { throw ("[STOP] Não achei layout.tsx em: " + $layoutPath) }

# -------------------------
# PATCH
# -------------------------
BackupFile $layoutPath

$content = @"
import React from "react";

import UniverseShell from "@/components/UniverseShell";
import ReadingControls from "@/components/ReadingControls";
import { getCaderno } from "@/lib/cadernos";

function pickMoodFromMeta(meta: Record<string, unknown> | null): string {
  if (!meta) return "";
  const v = meta["mood"] ?? meta["universe"] ?? meta["theme"] ?? meta["tone"] ?? "";
  if (typeof v === "string") return v;
  if (typeof v === "number") return String(v);
  return "";
}

function extractMeta(data: unknown): Record<string, unknown> | null {
  if (!data || typeof data !== "object") return null;
  if (!("meta" in data)) return null;
  const meta = (data as { meta?: unknown }).meta;
  if (!meta || typeof meta !== "object") return null;
  return meta as Record<string, unknown>;
}

export default async function CadernoLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: { slug: string };
}) {
  const slug = params.slug;

  let mood = "";
  try {
    const data = (await getCaderno(slug)) as unknown;
    mood = pickMoodFromMeta(extractMeta(data));
  } catch {
    mood = "";
  }

  return (
    <UniverseShell slug={slug} mood={mood}>
      <ReadingControls />
      {children}
    </UniverseShell>
  );
}
"@

WriteUtf8NoBom $layoutPath $content
WL "[OK] patched: layout.tsx (removeu any -> unknown + guards)"

# -------------------------
# REPORT
# -------------------------
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repDir "cv-engine-3h-hotfix-no-any-layout-v0_14c.md"
$report = @(
  ("# CV Engine-3H Hotfix — No Any Layout v0.14c — " + $now),
  "",
  "## O que mudou",
  "- Removeu qualquer uso de `any` no layout do caderno.",
  "- getCaderno() agora é tratado como `unknown` com guards para extrair `meta`.",
  "- pickMoodFromMeta() usa Record<string, unknown> com coerção segura.",
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
WL "[OK] Hotfix aplicado."