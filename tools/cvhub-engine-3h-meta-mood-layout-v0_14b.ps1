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

$layoutPath   = Join-Path $repo "src\app\c\[slug]\layout.tsx"
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
# PATCH: UniverseShell (props mood + slug, fallback)
# -------------------------
BackupFile $universePath

$u = @"
"use client";

import React from "react";
import { useParams } from "next/navigation";

function moodFromSlug(slug: string): string {
  const s = (slug || "").toLowerCase();

  if (s.indexOf("poluicao") >= 0) return "smoke";
  if (s.indexOf("trabalho") >= 0) return "steel";
  if (s.indexOf("memoria") >= 0) return "archive";
  if (s.indexOf("eco") >= 0) return "green";

  return "urban";
}

function normalizeMood(s: string): string {
  const v = (s || "").trim().toLowerCase();
  if (!v) return "";
  return v.replace(/[^a-z0-9\-]/g, "-").replace(/\-+/g, "-").replace(/^\-|\-$/g, "");
}

type Props = {
  children: React.ReactNode;
  slug?: string;
  mood?: string;
};

export default function UniverseShell({ children, slug: slugProp, mood: moodProp }: Props) {
  const params = useParams() as { slug?: string };
  const slug = slugProp ? String(slugProp) : (params && params.slug ? String(params.slug) : "");

  const normalized = normalizeMood(moodProp || "");
  const mood = normalized ? normalized : moodFromSlug(slug);

  const cls = "cv-universe cv-mood-" + mood;

  return (
    <div className={cls} data-cv-slug={slug} data-cv-mood={mood}>
      <div className="cv-universe-inner">
        {children}
      </div>
    </div>
  );
}
"@

WriteUtf8NoBom $universePath $u
WL "[OK] wrote: UniverseShell.tsx"

# -------------------------
# PATCH: layout.tsx (server) lê meta.mood e passa pro UniverseShell
# -------------------------
BackupFile $layoutPath

$l = @"
import React from "react";

import UniverseShell from "@/components/UniverseShell";
import ReadingControls from "@/components/ReadingControls";
import { getCaderno } from "@/lib/cadernos";

function pickMoodFromMeta(meta: any): string {
  if (!meta) return "";
  const v = meta.mood || meta.universe || meta.theme || meta.tone || "";
  return v ? String(v) : "";
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
    const data: any = await getCaderno(slug);
    mood = pickMoodFromMeta(data && data.meta ? data.meta : null);
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

WriteUtf8NoBom $layoutPath $l
WL "[OK] wrote: /c/[slug]/layout.tsx (meta mood -> UniverseShell)"

# -------------------------
# REPORT
# -------------------------
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repDir "cv-engine-3h-meta-mood-layout-v0_14b.md"
$report = @(
  ("# CV Engine-3H — Meta Mood Layout v0.14b — " + $now),
  "",
  "## O que mudou",
  "- UniverseShell agora aceita props mood e slug (com fallback).",
  "- Layout do caderno tenta ler meta.mood (ou meta.universe/theme/tone) via getCaderno(slug) e passa pro UniverseShell.",
  "- ReadingControls fica global no layout do caderno.",
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
WL "[OK] Engine-3H aplicado."