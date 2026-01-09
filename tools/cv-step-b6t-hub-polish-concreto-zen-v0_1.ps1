param()
$ErrorActionPreference = "Stop"

$stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

Write-Host ("== cv-step-b6t-hub-polish-concreto-zen-v0_1 == " + $stamp)
Write-Host ("[DIAG] Repo: " + $repoRoot)

function EnsureDir([string]$p) { if (!(Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function BackupFile([string]$abs) {
  $bkDir = Join-Path $repoRoot "tools\_patch_backup"
  EnsureDir $bkDir
  $leaf = (Split-Path -Leaf $abs) -replace "[\\\/:\s]", "_"
  $bk = Join-Path $bkDir ($stamp + "-" + $leaf + ".bak")
  Copy-Item -LiteralPath $abs -Destination $bk -Force
  return $bk
}
function WriteUtf8NoBom([string]$abs, [string]$content) { [IO.File]::WriteAllText($abs, $content, [Text.UTF8Encoding]::new($false)) }

$patched = New-Object System.Collections.Generic.List[string]

# ------------------------------------------------------------
# 1) globals.css: add CV2 Card polish (idempotent)
# ------------------------------------------------------------
$globalsRel = "src\app\globals.css"
$globalsAbs = Join-Path $repoRoot $globalsRel
if (Test-Path -LiteralPath $globalsAbs) {
  $raw = Get-Content -LiteralPath $globalsAbs -Raw
  if ($raw -notmatch "CV2 CARD POLISH") {
    $bk = BackupFile $globalsAbs

    $append = @"




/* ===== CV2 CARD POLISH (Concreto Zen) ===== */
/* CV2 CARD POLISH */
[id^="cv2-"] .cv2-card,
.cv-v2 .cv2-card {
  display: block;
  padding: 14px;
  border-radius: 16px;
  border: 1px solid rgba(255,255,255,0.12);
  background: rgba(255,255,255,0.04);
  text-decoration: none;
  transition: transform 140ms ease, background 140ms ease, border-color 140ms ease, opacity 140ms ease;
}

[id^="cv2-"] .cv2-card:hover,
.cv-v2 .cv2-card:hover {
  transform: translateY(-1px);
  background: rgba(255,255,255,0.06);
  border-color: rgba(255,255,255,0.18);
}

[id^="cv2-"] .cv2-card:active,
.cv-v2 .cv2-card:active {
  transform: translateY(0px) scale(0.995);
  opacity: 0.96;
}

[id^="cv2-"] .cv2-card:focus-visible,
.cv-v2 .cv2-card:focus-visible {
  outline: 2px solid rgba(255,255,255,0.22);
  outline-offset: 2px;
}

[id^="cv2-"] .cv2-cardTitle,
.cv-v2 .cv2-cardTitle {
  font-weight: 900;
  letter-spacing: 0.2px;
}

[id^="cv2-"] .cv2-cardDesc,
.cv-v2 .cv2-cardDesc {
  font-size: 12px;
  opacity: 0.78;
  margin-top: 6px;
}
/* ===== /CV2 CARD POLISH ===== */

"@

    WriteUtf8NoBom $globalsAbs ($raw.TrimEnd() + $append)
    Write-Host ("[PATCH] " + $globalsRel + " (append CV2 Card polish)")
    Write-Host ("[BK]    tools\_patch_backup\" + (Split-Path -Leaf $bk))
    $patched.Add($globalsRel) | Out-Null
  } else {
    Write-Host "SKIP: globals.css já tem CV2 Card polish"
  }
} else {
  Write-Host "[WARN] não achei src/app/globals.css"
}

# ------------------------------------------------------------
# 2) Rewrite V2CoreNodes.tsx: include Linha + use cv2-card classes
# ------------------------------------------------------------
$coreRel = "src\components\v2\V2CoreNodes.tsx"
$coreAbs = Join-Path $repoRoot $coreRel
EnsureDir (Split-Path -Parent $coreAbs)
if (Test-Path -LiteralPath $coreAbs) {
  $bk = BackupFile $coreAbs
  Write-Host ("[BK]    tools\_patch_backup\" + (Split-Path -Leaf $bk))
}

$coreCode = @"
import Link from "next/link";

type Item = { key: string; href: (slug: string) => string; title: string; desc: string };

const CORE: Item[] = [
  { key: "mapa", href: (s) => "/c/" + s + "/v2/mapa", title: "Mapa", desc: "O eixo do universo: lugares, conexões e portas." },
  { key: "linha", href: (s) => "/c/" + s + "/v2/linha", title: "Linha", desc: "Nós do universo: temas, cenas, atores e tensões." },
  { key: "linha-do-tempo", href: (s) => "/c/" + s + "/v2/linha-do-tempo", title: "Linha do tempo", desc: "Sequência, memória e viradas da história." },
  { key: "provas", href: (s) => "/c/" + s + "/v2/provas", title: "Provas", desc: "Fontes, links, documentos e rastros." },
  { key: "trilhas", href: (s) => "/c/" + s + "/v2/trilhas", title: "Trilhas", desc: "Caminhos guiados: do básico ao profundo." },
  { key: "debate", href: (s) => "/c/" + s + "/v2/debate", title: "Debate", desc: "Conversa em camadas: crítica + cuidado." },
];

export default function V2CoreNodes({ slug }: { slug: string }) {
  return (
    <section aria-label="Núcleo do universo">
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", gap: 12, flexWrap: "wrap" }}>
        <h2 style={{ fontSize: 16, margin: 0 }}>Núcleo do universo</h2>
        <div style={{ fontSize: 12, opacity: 0.7 }}>{CORE.length} portas essenciais</div>
      </div>

      <div style={{ display: "grid", gap: 10, gridTemplateColumns: "repeat(auto-fit, minmax(230px, 1fr))", marginTop: 10 }}>
        {CORE.map((x) => (
          <Link key={x.key} href={x.href(slug)} className="cv2-card">
            <div className="cv2-cardTitle">{x.title}</div>
            <div className="cv2-cardDesc">{x.desc}</div>
          </Link>
        ))}
      </div>
    </section>
  );
}
"@

WriteUtf8NoBom $coreAbs $coreCode
Write-Host ("[PATCH] " + $coreRel)
$patched.Add($coreRel) | Out-Null

# ------------------------------------------------------------
# 3) Hub V2: remove duplicated "Próximas portas" (keep only core)
# ------------------------------------------------------------
$hubRel = "src\app\c\[slug]\v2\page.tsx"
$hubAbs = Join-Path $repoRoot $hubRel
if (!(Test-Path -LiteralPath $hubAbs)) { throw ("não achei: " + $hubRel) }
$bk = BackupFile $hubAbs

$hubCode = @"
import V2Nav from "@/components/v2/V2Nav";
import V2QuickNav from "@/components/v2/V2QuickNav";
import V2CoreNodes from "@/components/v2/V2CoreNodes";
import { loadCadernoV2 } from "@/lib/v2";
import { cvReadMetaLoose } from "@/lib/v2/load";
import type { Metadata } from "next";

type AnyParams = { slug: string } | Promise<{ slug: string }>;

async function getSlug(params: AnyParams): Promise<string> {
  const p = await Promise.resolve(params as unknown as { slug: string });
  return p && typeof p.slug === "string" ? p.slug : "";
}

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }): Promise<Metadata> {
  const slug = await getSlug(params);
  const meta = await cvReadMetaLoose(slug);
  const title0 = typeof meta.title === "string" && meta.title.trim().length ? meta.title.trim() : slug;
  const m = meta as unknown as Record<string, unknown>;
  const rawDesc = typeof m["description"] === "string" ? (m["description"] as string) : "";
  const description = rawDesc.trim().length ? rawDesc.trim() : undefined;
  return { title: title0 + " • Cadernos Vivos", description };
}

export default async function Page({ params }: { params: AnyParams }) {
  const slug = await getSlug(params);
  const caderno = await loadCadernoV2(slug);
  const title0 =
    caderno && typeof (caderno as unknown as { title?: string }).title === "string"
      ? (caderno as unknown as { title: string }).title
      : slug;

  return (
    <div id="cv2-hub-root">
      <main style={{ padding: 18, maxWidth: 1100, margin: "0 auto" }}>
        <V2Nav slug={slug} active="hub" />
        <V2QuickNav />

        <div style={{ marginTop: 10 }}>
          <h1 style={{ fontSize: 22, margin: "8px 0 0" }}>{title0}</h1>
          <div style={{ opacity: 0.75, marginTop: 6 }}>
            Explore o universo por portas. Mapa primeiro, depois provas, trilhas e debate.
          </div>
        </div>

        <div style={{ marginTop: 14 }}>
          <V2CoreNodes slug={slug} />
        </div>
      </main>
    </div>
  );
}
"@

WriteUtf8NoBom $hubAbs $hubCode
Write-Host ("[PATCH] " + $hubRel)
Write-Host ("[BK]    tools\_patch_backup\" + (Split-Path -Leaf $bk))
$patched.Add($hubRel) | Out-Null

# ------------------------------------------------------------
# VERIFY
# ------------------------------------------------------------
$npm = (Get-Command npm.cmd -ErrorAction Stop).Path

Write-Host "[RUN] npm run lint"
$lintOut = (& $npm run lint 2>&1 | Out-String)
$lintExit = $LASTEXITCODE
if ($lintExit -ne 0) { Write-Host $lintOut; throw ("[STOP] lint falhou (exit=" + $lintExit + ")") }

Write-Host "[RUN] npm run build"
$buildOut = (& $npm run build 2>&1 | Out-String)
$buildExit = $LASTEXITCODE
if ($buildExit -ne 0) { Write-Host $buildOut; throw ("[STOP] build falhou (exit=" + $buildExit + ")") }

# ------------------------------------------------------------
# REPORT
# ------------------------------------------------------------
$repDir = Join-Path $repoRoot "reports"
EnsureDir $repDir
$rep = Join-Path $repDir ($stamp + "-cv-b6t-hub-polish-concreto-zen.md")

$body = @(
  ("# CV B6T — Hub polish (Concreto Zen) — " + $stamp),
  "",
  ("Repo: " + $repoRoot),
  "",
  "## PATCH",
  ($patched | ForEach-Object { "- " + $_ }),
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
  "--- BUILD OUTPUT END ---"
) -join "`n"

WriteUtf8NoBom $rep $body
Write-Host ("[REPORT] reports\" + (Split-Path -Leaf $rep))
Write-Host "[OK] B6T concluído (Hub sem duplicação + Linha no núcleo + card polish)."