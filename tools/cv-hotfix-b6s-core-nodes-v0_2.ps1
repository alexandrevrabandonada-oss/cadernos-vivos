param()
$ErrorActionPreference = "Stop"

$stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

Write-Host ("== cv-hotfix-b6s-core-nodes-v0_2 == " + $stamp)
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
# 1) V2Nav (aceita active/current)
# ------------------------------------------------------------
$navRel = "src\components\v2\V2Nav.tsx"
$navAbs = Join-Path $repoRoot $navRel
if (!(Test-Path -LiteralPath $navAbs)) { throw ("não achei: " + $navRel) }
$bk = BackupFile $navAbs

$navCode = @"
import Link from "next/link";

type Props = {
  slug: string;
  active?: string;
  current?: string;
  title?: string;
};

const TABS: { key: string; label: string; href: (slug: string) => string }[] = [
  { key: "hub", label: "Hub", href: (s) => "/c/" + s + "/v2" },
  { key: "mapa", label: "Mapa", href: (s) => "/c/" + s + "/v2/mapa" },
  { key: "linha", label: "Linha", href: (s) => "/c/" + s + "/v2/linha" },
  { key: "linha-do-tempo", label: "Linha do tempo", href: (s) => "/c/" + s + "/v2/linha-do-tempo" },
  { key: "provas", label: "Provas", href: (s) => "/c/" + s + "/v2/provas" },
  { key: "trilhas", label: "Trilhas", href: (s) => "/c/" + s + "/v2/trilhas" },
  { key: "debate", label: "Debate", href: (s) => "/c/" + s + "/v2/debate" },
];

export default function V2Nav(props: Props) {
  const active = (props.active ?? props.current ?? "hub").trim();
  const slug = props.slug;

  return (
    <nav aria-label="Navegação do caderno" style={{ display: "flex", gap: 8, flexWrap: "wrap", alignItems: "center" }}>
      {TABS.map((t) => {
        const is = t.key === active;
        return (
          <Link
            key={t.key}
            href={t.href(slug)}
            style={{
              padding: "8px 10px",
              borderRadius: 999,
              border: "1px solid rgba(255,255,255,0.12)",
              textDecoration: "none",
              opacity: is ? 1 : 0.78,
              fontWeight: is ? 800 : 650,
              background: is ? "rgba(255,255,255,0.08)" : "transparent",
            }}
          >
            {t.label}
          </Link>
        );
      })}
    </nav>
  );
}
"@

WriteUtf8NoBom $navAbs $navCode
Write-Host ("[PATCH] " + $navRel)
Write-Host ("[BK]    tools\_patch_backup\" + (Split-Path -Leaf $bk))
$patched.Add($navRel) | Out-Null

# ------------------------------------------------------------
# 2) V2Portals (aceita current/active)
# ------------------------------------------------------------
$portalsRel = "src\components\v2\V2Portals.tsx"
$portalsAbs = Join-Path $repoRoot $portalsRel
EnsureDir (Split-Path -Parent $portalsAbs)
if (Test-Path -LiteralPath $portalsAbs) {
  $bk = BackupFile $portalsAbs
  Write-Host ("[BK]    tools\_patch_backup\" + (Split-Path -Leaf $bk))
}

$portalsCode = @"
import Link from "next/link";

type Props = {
  slug: string;
  current?: string;
  active?: string;
  title?: string;
};

const ITEMS: { key: string; label: string; href: (slug: string) => string; hint: string }[] = [
  { key: "hub", label: "Hub", href: (s) => "/c/" + s + "/v2", hint: "ponto de partida" },
  { key: "mapa", label: "Mapa", href: (s) => "/c/" + s + "/v2/mapa", hint: "lugares e conexões" },
  { key: "linha", label: "Linha", href: (s) => "/c/" + s + "/v2/linha", hint: "nós do universo" },
  { key: "linha-do-tempo", label: "Linha do tempo", href: (s) => "/c/" + s + "/v2/linha-do-tempo", hint: "sequência e memória" },
  { key: "provas", label: "Provas", href: (s) => "/c/" + s + "/v2/provas", hint: "fontes e evidências" },
  { key: "trilhas", label: "Trilhas", href: (s) => "/c/" + s + "/v2/trilhas", hint: "caminhos guiados" },
  { key: "debate", label: "Debate", href: (s) => "/c/" + s + "/v2/debate", hint: "conversa em camadas" },
];

export default function V2Portals(props: Props) {
  const slug = props.slug;
  const current = (props.current ?? props.active ?? "").trim();
  const list = ITEMS.filter((x) => x.key !== current).slice(0, 6);

  return (
    <section aria-label="Próximas portas" style={{ marginTop: 12 }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", gap: 12, flexWrap: "wrap" }}>
        <h3 style={{ margin: 0, fontSize: 14 }}>Próximas portas</h3>
        <Link href={"/c/" + slug + "/v2"} style={{ fontSize: 12, opacity: 0.75, textDecoration: "none" }}>
          Voltar ao Hub
        </Link>
      </div>

      <div style={{ display: "grid", gap: 10, gridTemplateColumns: "repeat(auto-fit, minmax(190px, 1fr))", marginTop: 10 }}>
        {list.map((x) => (
          <Link
            key={x.key}
            href={x.href(slug)}
            style={{
              display: "block",
              padding: 12,
              borderRadius: 14,
              border: "1px solid rgba(255,255,255,0.12)",
              textDecoration: "none",
            }}
          >
            <div style={{ fontWeight: 800 }}>{x.label}</div>
            <div style={{ fontSize: 12, opacity: 0.75, marginTop: 4 }}>{x.hint}</div>
          </Link>
        ))}
      </div>
    </section>
  );
}
"@

WriteUtf8NoBom $portalsAbs $portalsCode
Write-Host ("[PATCH] " + $portalsRel)
$patched.Add($portalsRel) | Out-Null

# ------------------------------------------------------------
# 3) V2CoreNodes (5 portas essenciais)
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
        <div style={{ fontSize: 12, opacity: 0.7 }}>5 portas essenciais</div>
      </div>

      <div style={{ display: "grid", gap: 10, gridTemplateColumns: "repeat(auto-fit, minmax(230px, 1fr))", marginTop: 10 }}>
        {CORE.map((x) => (
          <Link
            key={x.key}
            href={x.href(slug)}
            style={{
              display: "block",
              padding: 14,
              borderRadius: 16,
              border: "1px solid rgba(255,255,255,0.12)",
              textDecoration: "none",
              background: "rgba(255,255,255,0.04)",
            }}
          >
            <div style={{ fontWeight: 900, letterSpacing: 0.2 }}>{x.title}</div>
            <div style={{ fontSize: 12, opacity: 0.78, marginTop: 6 }}>{x.desc}</div>
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
# 4) Hub V2 canônico (com núcleo + portais)
# ------------------------------------------------------------
$hubRel = "src\app\c\[slug]\v2\page.tsx"
$hubAbs = Join-Path $repoRoot $hubRel
if (!(Test-Path -LiteralPath $hubAbs)) { throw ("não achei: " + $hubRel) }
$bk = BackupFile $hubAbs

$hubCode = @"
import V2Nav from "@/components/v2/V2Nav";
import V2QuickNav from "@/components/v2/V2QuickNav";
import V2Portals from "@/components/v2/V2Portals";
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
          <div style={{ opacity: 0.75, marginTop: 6 }}>Explore o universo por portas. Mapa primeiro, depois provas, trilhas e debate.</div>
        </div>

        <div style={{ marginTop: 14 }}>
          <V2CoreNodes slug={slug} />
        </div>

        <V2Portals slug={slug} current="hub" />
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
# 5) Debate/Linha canônicos (arruma seu JSX quebrado + garante slug)
# ------------------------------------------------------------
function RewritePage([string]$rel, [string]$activeKey, [string]$placeholder, [string]$componentName) {
  $abs = Join-Path $repoRoot $rel
  if (!(Test-Path -LiteralPath $abs)) { throw ("não achei: " + $rel) }
  $bk = BackupFile $abs

  $id = "cv2-" + $activeKey + "-root"
  $code = @"
import V2Nav from "@/components/v2/V2Nav";
import V2QuickNav from "@/components/v2/V2QuickNav";
import V2Portals from "@/components/v2/V2Portals";
import $componentName from "@/components/v2/$componentName";
import { loadCadernoV2 } from "@/lib/v2";
import type { Metadata } from "next";
import { cvReadMetaLoose } from "@/lib/v2/load";
import Cv2DomFilterClient from "@/components/v2/Cv2DomFilterClient";

type AnyParams = { slug: string } | Promise<{ slug: string }>;

async function getSlug(params: AnyParams): Promise<string> {
  const p = await Promise.resolve(params as unknown as { slug: string });
  return p && typeof p.slug === "string" ? p.slug : "";
}

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }): Promise<Metadata> {
  const slug = await getSlug(params);
  const meta = await cvReadMetaLoose(slug);
  const title = typeof meta.title === "string" && meta.title.trim().length ? meta.title.trim() : slug;
  const m = meta as unknown as Record<string, unknown>;
  const rawDesc = typeof m["description"] === "string" ? (m["description"] as string) : "";
  const description = rawDesc.trim().length ? rawDesc.trim() : undefined;
  return { title: title + " • Cadernos Vivos", description };
}

export default async function Page({ params }: { params: AnyParams }) {
  const slug = await getSlug(params);
  const caderno = await loadCadernoV2(slug);
  const title =
    caderno && typeof (caderno as unknown as { title?: string }).title === "string"
      ? (caderno as unknown as { title: string }).title
      : slug;

  return (
    <div id="$id">
      <Cv2DomFilterClient rootId="$id" placeholder="$placeholder" pageSize={24} enablePager />
      <main style={{ padding: 18, maxWidth: 1100, margin: "0 auto" }}>
        <V2Nav slug={slug} active="$activeKey" />
        <V2QuickNav />
        <div style={{ marginTop: 12 }}>
          <$componentName slug={slug} title={title} />
        </div>
        <V2Portals slug={slug} current="$activeKey" />
      </main>
    </div>
  );
}
"@

  WriteUtf8NoBom $abs $code
  Write-Host ("[PATCH] " + $rel)
  Write-Host ("[BK]    tools\_patch_backup\" + (Split-Path -Leaf $bk))
  $patched.Add($rel) | Out-Null
}

RewritePage "src\app\c\[slug]\v2\debate\page.tsx" "debate" "Filtrar debate..." "DebateV2"
RewritePage "src\app\c\[slug]\v2\linha\page.tsx"  "linha"  "Filtrar linha..."  "LinhaV2"

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
$rep = Join-Path $repDir ($stamp + "-cv-hotfix-b6s-core-nodes.md")

$body = @(
  ("# CV HOTFIX B6S — Núcleo do Universo + hardening Nav/Portals — " + $stamp),
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
Write-Host "[OK] HOTFIX B6S v0_2 concluído (Hub núcleo + Nav/Portals tolerante + debate/linha canônicos)."