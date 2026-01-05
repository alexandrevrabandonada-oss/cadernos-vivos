$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Write-Host ("[DIAG] Repo: " + $repo)

. (Join-Path $PSScriptRoot "_bootstrap.ps1")

$changed = New-Object System.Collections.Generic.List[string]

function WriteFileLines([string]$rel, [string[]]$lines) {
  $full = Join-Path $repo $rel
  EnsureDir (Split-Path -Parent $full) | Out-Null
  $bk = $null
  if (Test-Path -LiteralPath $full) { $bk = BackupFile $full }
  $content = $lines -join "`r`n"
  WriteUtf8NoBom $full $content
  Write-Host ("[OK] wrote: " + $full)
  if ($bk) { Write-Host ("[BK] " + $bk) }
  $script:changed.Add($full) | Out-Null
}

function PatchText([string]$rel, [scriptblock]$mutate) {
  $full = Join-Path $repo $rel
  if (!(Test-Path -LiteralPath $full)) {
    Write-Host ("[SKIP] nao achei: " + $full)
    return
  }
  $raw = Get-Content -LiteralPath $full -Raw
  if ($null -eq $raw) { throw ("[STOP] leitura nula: " + $full) }

  $next = & $mutate $raw
  if ($null -eq $next) { throw "[STOP] mutate retornou null" }

  if ($next -ne $raw) {
    $bk = BackupFile $full
    WriteUtf8NoBom $full $next
    Write-Host ("[OK] patched: " + $full)
    Write-Host ("[BK] " + $bk)
    $script:changed.Add($full) | Out-Null
  } else {
    Write-Host ("[OK] sem mudanca: " + $full)
  }
}

# 1) Novo componente: HomeV2Hub (client)
$hubLines = @(
  '"use client";',
  '',
  'import React, { useEffect, useMemo, useState } from "react";',
  '',
  'type AnyObj = Record<string, unknown>;',
  '',
  'type HubNode = {',
  '  id: string;',
  '  title?: string;',
  '  label?: string;',
  '  kind?: string;',
  '  type?: string;',
  '  href?: string;',
  '  hot?: boolean;',
  '  pinned?: boolean;',
  '};',
  '',
  'export type HubStats = { nodes?: number; provas?: number; debate?: number; trilhas?: number };',
  '',
  'function isObj(v: unknown): v is AnyObj {',
  '  return !!v && typeof v === "object" && !Array.isArray(v);',
  '}',
  '',
  'function pickStr(o: unknown, key: string): string {',
  '  if (!isObj(o)) return "";',
  '  const v = o[key];',
  '  return typeof v === "string" ? v : "";',
  '}',
  '',
  'function pickBool(o: unknown, key: string): boolean {',
  '  if (!isObj(o)) return false;',
  '  const v = o[key];',
  '  return v === true;',
  '}',
  '',
  'function nodesFromMapa(mapa: unknown): HubNode[] {',
  '  if (!mapa) return [];',
  '  if (Array.isArray(mapa)) {',
  '    return mapa.filter(isObj).map((n) => ({',
  '      id: pickStr(n, "id"),',
  '      title: pickStr(n, "title") || pickStr(n, "name"),',
  '      label: pickStr(n, "label"),',
  '      kind: pickStr(n, "kind"),',
  '      type: pickStr(n, "type"),',
  '      href: pickStr(n, "href"),',
  '      hot: pickBool(n, "hot"),',
  '      pinned: pickBool(n, "pinned"),',
  '    })).filter((n) => !!n.id);',
  '  }',
  '  if (isObj(mapa)) {',
  '    const nodes = mapa["nodes"];',
  '    if (Array.isArray(nodes)) return nodesFromMapa(nodes);',
  '    const items = mapa["items"];',
  '    if (Array.isArray(items)) return nodesFromMapa(items);',
  '    const timeline = mapa["timeline"];',
  '    if (Array.isArray(timeline)) return nodesFromMapa(timeline);',
  '  }',
  '  return [];',
  '}',
  '',
  'function nodeText(n: HubNode): string {',
  '  return n.title || n.label || n.id;',
  '}',
  '',
  'function nodeTarget(slug: string, n: HubNode): { href: string; external: boolean } {',
  '  const href = n.href || "";',
  '  if (href) {',
  '    const ext = href.startsWith("http://") || href.startsWith("https://");',
  '    if (ext) return { href, external: true };',
  '    if (href.startsWith("/")) return { href, external: false };',
  '    const rel = href.replace(/^\\/+/, "");',
  '    return { href: "/c/" + slug + "/v2/" + rel, external: false };',
  '  }',
  '  const k = (n.kind || n.type || "").toLowerCase();',
  '  if (k.includes("debate")) return { href: "/c/" + slug + "/v2/debate#" + n.id, external: false };',
  '  if (k.includes("prova") || k.includes("acervo") || k.includes("proof")) return { href: "/c/" + slug + "/v2/provas#" + n.id, external: false };',
  '  if (k.includes("linha") || k.includes("timeline")) return { href: "/c/" + slug + "/v2/linha-do-tempo#" + n.id, external: false };',
  '  return { href: "/c/" + slug + "/v2/mapa#" + n.id, external: false };',
  '}',
  '',
  'async function copyText(text: string): Promise<boolean> {',
  '  try {',
  '    if (navigator.clipboard && navigator.clipboard.writeText) {',
  '      await navigator.clipboard.writeText(text);',
  '      return true;',
  '    }',
  '  } catch {}',
  '  try {',
  '    const ta = document.createElement("textarea");',
  '    ta.value = text;',
  '    ta.style.position = "fixed";',
  '    ta.style.left = "-9999px";',
  '    document.body.appendChild(ta);',
  '    ta.select();',
  '    const ok = document.execCommand("copy");',
  '    document.body.removeChild(ta);',
  '    return ok;',
  '  } catch {',
  '    return false;',
  '  }',
  '}',
  '',
  'export function HomeV2Hub(props: { slug: string; title: string; mapa?: unknown; stats?: HubStats }) {',
  '  const [last, setLast] = useState<string>("");',
  '  const key = "cv_v2_last:" + props.slug;',
  '',
  '  useEffect(() => {',
  '    try {',
  '      const v = localStorage.getItem(key) || "";',
  '      setLast(v);',
  '    } catch {}',
  '  }, [key]);',
  '',
  '  const nodes = useMemo(() => nodesFromMapa(props.mapa), [props.mapa]);',
  '  const hot = useMemo(() => nodes.filter((n) => !!n.hot || !!n.pinned).slice(0, 8), [nodes]);',
  '  const hotOrFirst = useMemo(() => (hot.length ? hot : nodes.slice(0, 8)), [hot, nodes]);',
  '',
  '  const base = "/c/" + props.slug + "/v2";',
  '  const continueHref = last && last.startsWith("/c/") ? last : (base + "/mapa");',
  '',
  '  function remember(href: string) {',
  '    try { localStorage.setItem(key, href); } catch {}',
  '  }',
  '',
  '  return (',
  '    <div style={{ display: "grid", gap: 12 }}>',
  '      <header style={{ border: "1px solid rgba(255,255,255,0.10)", borderRadius: 14, padding: 12, background: "rgba(0,0,0,0.22)" }}>',
  '        <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", gap: 12, flexWrap: "wrap" }}>',
  '          <div style={{ display: "flex", flexDirection: "column", gap: 2 }}>',
  '            <div style={{ fontSize: 12, opacity: 0.75 }}>Caderno V2</div>',
  '            <div style={{ fontSize: 18, fontWeight: 900 }}>{props.title}</div>',
  '            <div style={{ fontSize: 12, opacity: 0.80 }}>Concreto Zen: portas rápidas, fios quentes e links diretos.</div>',
  '          </div>',
  '          <div style={{ display: "flex", gap: 8, alignItems: "center", flexWrap: "wrap" }}>',
  '            <span style={{ fontSize: 12, opacity: 0.85, padding: "6px 10px", borderRadius: 999, border: "1px solid rgba(255,255,255,0.12)" }}>',
  '              Nós: {props.stats?.nodes ?? 0} · Provas: {props.stats?.provas ?? 0} · Debate: {props.stats?.debate ?? 0} · Trilhas: {props.stats?.trilhas ?? 0}',
  '            </span>',
  '            <button',
  '              type="button"',
  '              title="Copiar link do Hub V2"',
  '              style={{ cursor: "pointer", fontSize: 12, fontWeight: 800, padding: "8px 10px", borderRadius: 10, background: "rgba(255,255,255,0.06)", border: "1px solid rgba(255,255,255,0.12)", color: "inherit" }}',
  '              onClick={async () => {',
  '                const url = window.location.origin + base;',
  '                const ok = await copyText(url);',
  '                if (!ok) alert("Nao consegui copiar aqui. Tenta manualmente.");',
  '              }}',
  '            >',
  '              Copiar link',
  '            </button>',
  '          </div>',
  '        </div>',
  '      </header>',
  '',
  '      <div style={{ display: "grid", gridTemplateColumns: "1.1fr 0.9fr", gap: 12, alignItems: "start" }}>',
  '        <section style={{ borderRadius: 14, padding: 12, border: "1px solid rgba(255,255,255,0.10)", background: "rgba(0,0,0,0.18)", display: "grid", gap: 10 }}>',
  '          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 8, flexWrap: "wrap" }}>',
  '            <div style={{ fontSize: 13, fontWeight: 900 }}>Portas</div>',
  '            <a',
  '              href={continueHref}',
  '              onClick={() => remember(continueHref)}',
  '              style={{ textDecoration: "none", fontSize: 12, fontWeight: 900, padding: "8px 10px", borderRadius: 10, background: "var(--accent)", color: "#111" }}',
  '              title="Continuar do ultimo link guardado"',
  '            >',
  '              Continuar',
  '            </a>',
  '          </div>',
  '',
  '          <div style={{ display: "grid", gap: 8 }}>',
  '            <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>',
  '              <a href={base + "/mapa"} onClick={() => remember(base + "/mapa")} style={{ textDecoration: "none", fontSize: 12, fontWeight: 800, padding: "8px 10px", borderRadius: 10, background: "rgba(255,255,255,0.06)", border: "1px solid rgba(255,255,255,0.12)", color: "inherit" }}>Mapa</a>',
  '              <a href={base + "/provas"} onClick={() => remember(base + "/provas")} style={{ textDecoration: "none", fontSize: 12, fontWeight: 800, padding: "8px 10px", borderRadius: 10, background: "rgba(255,255,255,0.06)", border: "1px solid rgba(255,255,255,0.12)", color: "inherit" }}>Provas</a>',
  '              <a href={base + "/debate"} onClick={() => remember(base + "/debate")} style={{ textDecoration: "none", fontSize: 12, fontWeight: 800, padding: "8px 10px", borderRadius: 10, background: "rgba(255,255,255,0.06)", border: "1px solid rgba(255,255,255,0.12)", color: "inherit" }}>Debate</a>',
  '              <a href={base + "/linha-do-tempo"} onClick={() => remember(base + "/linha-do-tempo")} style={{ textDecoration: "none", fontSize: 12, fontWeight: 800, padding: "8px 10px", borderRadius: 10, background: "rgba(255,255,255,0.06)", border: "1px solid rgba(255,255,255,0.12)", color: "inherit" }}>Linha do tempo</a>',
  '              <a href={base + "/trilhas"} onClick={() => remember(base + "/trilhas")} style={{ textDecoration: "none", fontSize: 12, fontWeight: 800, padding: "8px 10px", borderRadius: 10, background: "rgba(255,255,255,0.06)", border: "1px solid rgba(255,255,255,0.12)", color: "inherit" }}>Trilhas</a>',
  '            </div>',
  '            <div style={{ fontSize: 12, opacity: 0.78 }}>Dica: os links que voce clicar aqui viram seu Continuar.</div>',
  '          </div>',
  '        </section>',
  '',
  '        <section style={{ borderRadius: 14, padding: 12, border: "1px solid rgba(255,255,255,0.10)", background: "rgba(0,0,0,0.18)", display: "grid", gap: 10 }}>',
  '          <div style={{ fontSize: 13, fontWeight: 900 }}>Fios quentes</div>',
  '          <div style={{ display: "grid", gap: 8 }}>',
  '            {hotOrFirst.length ? hotOrFirst.map((n) => {',
  '              const t = nodeTarget(props.slug, n);',
  '              return (',
  '                <a',
  '                  key={n.id}',
  '                  href={t.href}',
  '                  target={t.external ? "_blank" : undefined}',
  '                  rel={t.external ? "noreferrer" : undefined}',
  '                  onClick={() => { if (!t.external) remember(t.href); }}',
  '                  style={{ textDecoration: "none", display: "flex", alignItems: "center", justifyContent: "space-between", gap: 10, padding: "10px 10px", borderRadius: 12, border: "1px solid rgba(255,255,255,0.10)", background: "rgba(255,255,255,0.04)", color: "inherit" }}',
  '                  title={t.external ? "Abrir externo" : "Abrir no V2"}',
  '                >',
  '                  <span style={{ fontSize: 12, fontWeight: 900, opacity: 0.90 }}>{nodeText(n)}</span>',
  '                  <span style={{ fontSize: 11, opacity: 0.70 }}>#{n.id}</span>',
  '                </a>',
  '              );',
  '            }) : (',
  '              <div style={{ fontSize: 12, opacity: 0.75 }}>Sem nos no mapa ainda. Adicione nodes em mapa.json para aparecer aqui.</div>',
  '            )}',
  '          </div>',
  '        </section>',
  '      </div>',
  '    </div>',
  '  );',
  '}'
)

WriteFileLines "src\components\v2\HomeV2Hub.tsx" $hubLines

# 2) /c/[slug]/v2/page.tsx — Hub server page (usa getCaderno e passa mapa+stats)
$pageLines = @(
  'import { notFound } from "next/navigation";',
  'import type { CSSProperties } from "react";',
  'import { getCaderno } from "@/lib/cadernos";',
  'import V2Nav from "@/components/v2/V2Nav";',
  'import { HomeV2Hub, type HubStats } from "@/components/v2/HomeV2Hub";',
  '',
  'type AccentStyle = CSSProperties & Record<"--accent", string>;',
  'type AnyObj = Record<string, unknown>;',
  '',
  'function isObj(v: unknown): v is AnyObj {',
  '  return !!v && typeof v === "object" && !Array.isArray(v);',
  '}',
  '',
  'function pickObj(o: unknown, key: string): AnyObj | null {',
  '  if (!isObj(o)) return null;',
  '  const v = o[key];',
  '  return isObj(v) ? v : null;',
  '}',
  '',
  'function pickArr(o: unknown, key: string): unknown[] {',
  '  if (!isObj(o)) return [];',
  '  const v = o[key];',
  '  return Array.isArray(v) ? v : [];',
  '}',
  '',
  'export default async function Page({ params }: { params: Promise<{ slug: string }> }) {',
  '  const { slug } = await params;',
  '',
  '  let data: Awaited<ReturnType<typeof getCaderno>>;',
  '  try {',
  '    data = await getCaderno(slug);',
  '  } catch (e) {',
  '    const err = e as { code?: string };',
  '    if (err && err.code === "ENOENT") return notFound();',
  '    throw e;',
  '  }',
  '',
  '  const meta = (data as unknown as { meta?: unknown }).meta;',
  '  const title = isObj(meta) && typeof meta["title"] === "string" ? (meta["title"] as string) : slug;',
  '  const accent = isObj(meta) && typeof meta["accent"] === "string" ? (meta["accent"] as string) : "#F7C600";',
  '  const s: AccentStyle = { ["--accent"]: accent } as AccentStyle;',
  '',
  '  const dataObj = data as unknown as AnyObj;',
  '  const mapa = pickObj(dataObj, "mapa") ?? pickObj(dataObj, "mapaV2") ?? (dataObj["mapa"] as unknown) ?? null;',
  '  const mapaNodes = isObj(mapa) ? (Array.isArray(mapa["nodes"]) ? (mapa["nodes"] as unknown[]) : []) : (Array.isArray(mapa) ? mapa : []);',
  '',
  '  const stats: HubStats = {',
  '    nodes: mapaNodes.length,',
  '    provas: pickArr(dataObj, "acervo").length,',
  '    debate: pickArr(dataObj, "debate").length,',
  '    trilhas: pickArr(dataObj, "trilhas").length,',
  '  };',
  '',
  '  return (',
  '    <main style={{ padding: 14, maxWidth: 1100, margin: "0 auto", ...s }}>',
  '      <V2Nav slug={slug} active="mapa" />',
  '      <div style={{ marginTop: 12 }}>',
  '        <HomeV2Hub slug={slug} title={title} mapa={mapa} stats={stats} />',
  '      </div>',
  '    </main>',
  '  );',
  '}'
)

WriteFileLines "src\app\c\[slug]\v2\page.tsx" $pageLines

# 3) Fix: MapaV2 nodes.map precisa idx quando usa idx (evita "Cannot find name idx")
PatchText "src\components\v2\MapaV2.tsx" {
  param($s)
  $out = $s

  # troca nodes.map((n) => para nodes.map((n, idx) => (só a primeira ocorrência)
  $out2 = [regex]::Replace($out, 'nodes\.map\(\(\s*n\s*\)\s*=>', 'nodes.map((n, idx) =>', 1)
  return $out2
}

# 4) VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# 5) REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Step D1c — Hub V2 microinteracoes (v0_81)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que entrou") | Out-Null
$rep.Add("- HomeV2Hub: portas rapidas (Mapa/Provas/Debate/Linha/Trilhas), botao Continuar (com last local), copiar link do hub e lista de fios quentes.") | Out-Null
$rep.Add("- /c/[slug]/v2: pagina do hub carregando getCaderno e passando mapa+stats.") | Out-Null
$rep.Add("- MapaV2: nodes.map agora recebe idx quando o layout precisa idx.") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null

$rp = WriteReport "cv-step-d1c-homev2-microinteractions-v0_81.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Step D1c aplicado e verificado."