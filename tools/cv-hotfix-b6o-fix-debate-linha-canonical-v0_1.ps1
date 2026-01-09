# cv-hotfix-b6o-fix-debate-linha-canonical-v0_1
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = (Get-Location).Path

# bootstrap (se existir)
$boot = Join-Path $repoRoot "tools\_bootstrap.ps1"
if (Test-Path -LiteralPath $boot) { . $boot }

function EnsureDir([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}
function WriteUtf8NoBom([string]$file, [string]$content) {
  $dir = Split-Path -Parent $file
  if ($dir) { EnsureDir $dir }
  [IO.File]::WriteAllText($file, $content, [Text.UTF8Encoding]::new($false))
}
function BackupFile([string]$file) {
  $bkDir = Join-Path $repoRoot "tools\_patch_backup"
  EnsureDir $bkDir
  $stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
  $leaf = (Split-Path -Leaf $file) -replace '[\\\/:]', '_'
  $bk = Join-Path $bkDir ("$stamp-$leaf.bak")
  Copy-Item -LiteralPath $file -Destination $bk -Force
  return $bk
}

function Patch-Canonical([string]$rel, [string[]]$lines) {
  $file = Join-Path $repoRoot $rel
  if (-not (Test-Path -LiteralPath $file)) { throw "[STOP] não achei: $rel" }
  $bk = BackupFile $file
  WriteUtf8NoBom $file ($lines -join "`n")
  Write-Host ("[PATCH] " + $rel)
  Write-Host ("[BK]    tools\_patch_backup\" + (Split-Path -Leaf $bk))
}

# ------------------------------------------------------------
# PATCH: debate
# ------------------------------------------------------------
$debateLines = @(
'import V2Nav from "@/components/v2/V2Nav";',
'import V2QuickNav from "@/components/v2/V2QuickNav";',
'import V2Portals from "@/components/v2/V2Portals";',
'import DebateV2 from "@/components/v2/DebateV2";',
'import Cv2DomFilterClient from "@/components/v2/Cv2DomFilterClient";',
'import { loadCadernoV2 } from "@/lib/v2";',
'import { cvReadMetaLoose } from "@/lib/v2/load";',
'import type { Metadata } from "next";',
'',
'type AnyParams = { slug: string } | Promise<{ slug: string }>; ',
'',
'async function getSlug(params: AnyParams): Promise<string> {',
'  const p = await Promise.resolve(params as unknown as { slug: string });',
'  return p && typeof p.slug === "string" ? p.slug : "";',
'}',
'',
'export async function generateMetadata({ params }: { params: AnyParams }): Promise<Metadata> {',
'  const slug = await getSlug(params);',
'  const meta = await cvReadMetaLoose(slug);',
'  const title = (typeof meta.title === "string" && meta.title.trim().length) ? meta.title.trim() : slug;',
'  const m = meta as unknown as Record<string, unknown>;',
'  const rawDesc = (typeof m["description"] === "string") ? (m["description"] as string) : "";',
'  const description = rawDesc.trim().length ? rawDesc.trim() : undefined;',
'  return {',
'    title: title + " • Cadernos Vivos",',
'    description,',
'  };',
'}',
'',
'export default async function Page({ params }: { params: AnyParams }) {',
'  const slug = await getSlug(params);',
'  const caderno = await loadCadernoV2(slug);',
'  const rec = caderno as unknown as Record<string, unknown>;',
'  const t = (typeof rec["title"] === "string") ? (rec["title"] as string) : "";',
'  const title = t.trim().length ? t.trim() : slug;',
'',
'  return (',
'    <div id="cv2-debate-root">',
'      <Cv2DomFilterClient rootId="cv2-debate-root" placeholder="Filtrar debate..." pageSize={24} enablePager />',
'      <main style={{ padding: 18, maxWidth: 1100, margin: "0 auto" }}>',
'        <V2Nav slug={slug} active="debate" />',
'        <V2QuickNav />',
'        <div style={{ marginTop: 12 }}>',
'          <DebateV2 slug={slug} title={title} />',
'        </div>',
'        <V2Portals slug={slug} />',
'      </main>',
'    </div>',
'  );',
'}'
)

Patch-Canonical "src\app\c\[slug]\v2\debate\page.tsx" $debateLines

# ------------------------------------------------------------
# PATCH: linha
# ------------------------------------------------------------
$linhaLines = @(
'import V2Nav from "@/components/v2/V2Nav";',
'import V2QuickNav from "@/components/v2/V2QuickNav";',
'import V2Portals from "@/components/v2/V2Portals";',
'import LinhaV2 from "@/components/v2/LinhaV2";',
'import Cv2DomFilterClient from "@/components/v2/Cv2DomFilterClient";',
'import { loadCadernoV2 } from "@/lib/v2";',
'import { cvReadMetaLoose } from "@/lib/v2/load";',
'import type { Metadata } from "next";',
'',
'type AnyParams = { slug: string } | Promise<{ slug: string }>; ',
'',
'async function getSlug(params: AnyParams): Promise<string> {',
'  const p = await Promise.resolve(params as unknown as { slug: string });',
'  return p && typeof p.slug === "string" ? p.slug : "";',
'}',
'',
'export async function generateMetadata({ params }: { params: AnyParams }): Promise<Metadata> {',
'  const slug = await getSlug(params);',
'  const meta = await cvReadMetaLoose(slug);',
'  const title = (typeof meta.title === "string" && meta.title.trim().length) ? meta.title.trim() : slug;',
'  const m = meta as unknown as Record<string, unknown>;',
'  const rawDesc = (typeof m["description"] === "string") ? (m["description"] as string) : "";',
'  const description = rawDesc.trim().length ? rawDesc.trim() : undefined;',
'  return {',
'    title: title + " • Cadernos Vivos",',
'    description,',
'  };',
'}',
'',
'export default async function Page({ params }: { params: AnyParams }) {',
'  const slug = await getSlug(params);',
'  const caderno = await loadCadernoV2(slug);',
'  const rec = caderno as unknown as Record<string, unknown>;',
'  const t = (typeof rec["title"] === "string") ? (rec["title"] as string) : "";',
'  const title = t.trim().length ? t.trim() : slug;',
'',
'  return (',
'    <div id="cv2-linha-root">',
'      <Cv2DomFilterClient rootId="cv2-linha-root" placeholder="Filtrar linha..." pageSize={24} enablePager />',
'      <main style={{ padding: 18, maxWidth: 1100, margin: "0 auto" }}>',
'        <V2Nav slug={slug} active="linha" />',
'        <V2QuickNav />',
'        <div style={{ marginTop: 12 }}>',
'          <LinhaV2 slug={slug} title={title} />',
'        </div>',
'        <V2Portals slug={slug} />',
'      </main>',
'    </div>',
'  );',
'}'
)

Patch-Canonical "src\app\c\[slug]\v2\linha\page.tsx" $linhaLines

# ------------------------------------------------------------
# VERIFY (npm robusto — sem "cmd.Source")
# ------------------------------------------------------------
$npmCmd = (Get-Command npm -ErrorAction Stop)
$npmExe = $npmCmd.Source
if (-not $npmExe) { $npmExe = $npmCmd.Path }
if (-not $npmExe) { $npmExe = "npm" }

Write-Host "[RUN] npm run lint"
$lintOut = (& $npmExe run lint 2>&1 | Out-String)
$lintExit = $LASTEXITCODE
if ($lintExit -ne 0) { Write-Host $lintOut; throw ("[STOP] lint falhou (exit=" + $lintExit + ")") }

Write-Host "[RUN] npm run build"
$buildOut = (& $npmExe run build 2>&1 | Out-String)
$buildExit = $LASTEXITCODE
if ($buildExit -ne 0) { Write-Host $buildOut; throw ("[STOP] build falhou (exit=" + $buildExit + ")") }

# ------------------------------------------------------------
# REPORT
# ------------------------------------------------------------
$stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
$repDir = Join-Path $repoRoot "reports"
EnsureDir $repDir
$rep = Join-Path $repDir ($stamp + "-cv-hotfix-b6o-debate-linha-canonical.md")

$body = @(
  ("# CV HOTFIX B6O — Debate/Linha canonical (parse-safe) — " + $stamp),
  "",
  ("Repo: " + $repoRoot),
  "",
  "## PATCH",
  "- Rewrote canonical:",
  "  - src/app/c/[slug]/v2/debate/page.tsx",
  "  - src/app/c/[slug]/v2/linha/page.tsx",
  "",
  "## VERIFY",
  ("- lint exit: " + $lintExit),
  ("- build exit: " + $buildExit),
  "",
  "--- LINT OUTPUT START ---",
  $lintOut.TrimEnd(),
  "--- LINT OUTPUT END ---",
  "",
  "--- BUILD OUTPUT START ---",
  $buildOut.TrimEnd(),
  "--- BUILD OUTPUT END ---",
  ""
) -join "`n"

WriteUtf8NoBom $rep $body
Write-Host ("[REPORT] reports\" + (Split-Path -Leaf $rep))
Write-Host "[OK] HOTFIX B6O concluído (debate/linha parse + lint/build ok)."