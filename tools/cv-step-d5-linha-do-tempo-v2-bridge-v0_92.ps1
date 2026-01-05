$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Write-Host ("[DIAG] Repo: " + $repo)

. (Join-Path $PSScriptRoot "_bootstrap.ps1")

$changed = New-Object System.Collections.Generic.List[string]

function WriteLines([string]$rel, [string[]]$lines) {
  $full = Join-Path $repo $rel
  EnsureDir (Split-Path -Parent $full)
  $next = ($lines -join "`r`n")
  if (Test-Path -LiteralPath $full) {
    $raw = Get-Content -LiteralPath $full -Raw
    if ($null -eq $raw) { $raw = "" }
    if ($raw -eq $next) {
      Write-Host ("[OK] sem mudanca: " + $full)
      return
    }
    $bk = BackupFile $full
    WriteUtf8NoBom $full $next
    Write-Host ("[OK] wrote: " + $full)
    Write-Host ("[BK] " + $bk)
  } else {
    WriteUtf8NoBom $full $next
    Write-Host ("[OK] wrote: " + $full)
  }
  $script:changed.Add($full) | Out-Null
}

# 1) LinhaDoTempoV2.tsx (client)
$timelineLines = @(
'"use client";',
'',
'import React, { useMemo, useState } from "react";',
'import Link from "next/link";',
'import { useSearchParams } from "next/navigation";',
'',
'type AnyObj = Record<string, unknown>;',
'',
'function isObj(v: unknown): v is AnyObj {',
'  return !!v && typeof v === "object" && !Array.isArray(v);',
'}',
'',
'type TimelineItem = {',
'  id: string;',
'  date?: string;',
'  title: string;',
'  body?: string;',
'  href?: string;',
'  source?: string;',
'  tags?: string[];',
'  nodeIds?: string[];',
'  _idx: number;',
'};',
'',
'function asString(v: unknown, fallback: string): string {',
'  if (typeof v === "string") return v;',
'  if (typeof v === "number") return String(v);',
'  return fallback;',
'}',
'',
'function toStringArray(v: unknown): string[] | undefined {',
'  if (!v) return undefined;',
'  if (Array.isArray(v)) return v.map((x) => asString(x, "")).filter(Boolean);',
'  if (typeof v === "string") return [v];',
'  return undefined;',
'}',
'',
'function parseDateKey(s?: string): number | null {',
'  if (!s) return null;',
'  const t = Date.parse(s);',
'  if (!Number.isNaN(t)) return t;',
'  // YYYY-MM-DD (bem comum)',
'  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s);',
'  if (m) {',
'    const yy = Number(m[1]);',
'    const mm = Number(m[2]);',
'    const dd = Number(m[3]);',
'    if (yy >= 1900 && mm >= 1 && mm <= 12 && dd >= 1 && dd <= 31) {',
'      return Date.UTC(yy, mm - 1, dd);',
'    }',
'  }',
'  return null;',
'}',
'',
'function normalizeTimeline(raw: unknown, mapa: unknown): TimelineItem[] {',
'  const fromArray = (arr: unknown[]): TimelineItem[] => {',
'    return arr.map((it, idx) => {',
'      if (isObj(it)) {',
'        const id = asString(it.id, "t-" + idx);',
'        const date = typeof it.date === "string" ? it.date : (typeof it.day === "string" ? it.day : (typeof it.when === "string" ? it.when : undefined));',
'        const title = asString(it.title ?? it.name ?? it.label, id);',
'        const body = typeof it.body === "string" ? it.body : (typeof it.text === "string" ? it.text : (typeof it.summary === "string" ? it.summary : undefined));',
'        const href = typeof it.href === "string" ? it.href : (typeof it.url === "string" ? it.url : undefined);',
'        const source = typeof it.source === "string" ? it.source : (typeof it.origin === "string" ? it.origin : undefined);',
'        const tags = toStringArray(it.tags ?? it.tag ?? it.kind);',
'        const nodeIds = toStringArray(it.nodeIds ?? it.nodes ?? it.node ?? it.mapNodeId);',
'        return { id, date, title, body, href, source, tags, nodeIds, _idx: idx };',
'      }',
'      return { id: "t-" + idx, title: asString(it, "t-" + idx), _idx: idx };',
'    });',
'  };',
'',
'  if (Array.isArray(raw)) return fromArray(raw);',
'  if (isObj(raw)) {',
'    const items = (raw.items ?? raw.events ?? raw.timeline ?? raw.linhaDoTempo) as unknown;',
'    if (Array.isArray(items)) return fromArray(items);',
'  }',
'  if (isObj(mapa)) {',
'    const items2 = (mapa.timeline ?? mapa.linhaDoTempo ?? mapa.events) as unknown;',
'    if (Array.isArray(items2)) return fromArray(items2);',
'  }',
'  return [];',
'}',
'',
'export function LinhaDoTempoV2(props: { slug: string; title: string; linha?: unknown; mapa?: unknown }) {',
'  const sp = useSearchParams();',
'  const node = (sp && sp.get("node")) ? (sp.get("node") || "") : "";',
'  const [q, setQ] = useState<string>("");',
'',
'  const items = useMemo(() => {',
'    const base = normalizeTimeline(props.linha, props.mapa);',
'    // ordena por data quando der; senão mantém ordem original',
'    return base.slice().sort((a, b) => {',
'      const ka = parseDateKey(a.date);',
'      const kb = parseDateKey(b.date);',
'      if (ka !== null && kb !== null) return ka - kb;',
'      if (ka !== null && kb === null) return -1;',
'      if (ka === null && kb !== null) return 1;',
'      return a._idx - b._idx;',
'    });',
'  }, [props.linha, props.mapa]);',
'',
'  const filtered = useMemo(() => {',
'    const qq = q.trim().toLowerCase();',
'    return items.filter((e) => {',
'      if (node) {',
'        const inNode = (e.nodeIds || []).includes(node) || e.id === node;',
'        if (!inNode) return false;',
'      }',
'      if (!qq) return true;',
'      const hay = (e.title + " " + (e.body || "") + " " + (e.source || "") + " " + (e.tags || []).join(" ")).toLowerCase();',
'      return hay.includes(qq);',
'    });',
'  }, [items, q, node]);',
'',
'  const pickNode = (e: TimelineItem): string => {',
'    const ids = (e.nodeIds || []).filter(Boolean);',
'    return ids.length ? ids[0] : e.id;',
'  };',
'',
'  return (',
'    <section className="w-full max-w-5xl mx-auto px-4 py-8">',
'      <header className="mb-6 flex items-start justify-between gap-4">',
'        <div>',
'          <h1 className="text-2xl font-semibold tracking-tight">{props.title}</h1>',
'          <p className="text-sm opacity-80">Linha do tempo (V2) — eventos conectados ao mapa, debate e provas.</p>',
'        </div>',
'        <div className="flex items-center gap-2">',
'          <Link className="text-xs underline opacity-80 hover:opacity-100" href={"/c/" + props.slug + "/v2/mapa" + (node ? ("?node=" + encodeURIComponent(node)) : "")}>Mapa</Link>',
'          <Link className="text-xs underline opacity-80 hover:opacity-100" href={"/c/" + props.slug + "/v2/debate" + (node ? ("?node=" + encodeURIComponent(node)) : "")}>Debate</Link>',
'          <Link className="text-xs underline opacity-80 hover:opacity-100" href={"/c/" + props.slug + "/v2/provas" + (node ? ("?node=" + encodeURIComponent(node)) : "")}>Provas</Link>',
'        </div>',
'      </header>',
'',
'      <div className="mb-4 flex flex-col gap-2">',
'        <div className="flex items-center gap-2">',
'          <input',
'            value={q}',
'            onChange={(ev) => setQ(ev.target.value)}',
'            placeholder="Buscar na linha do tempo…"',
'            className="w-full rounded-md border border-black/15 dark:border-white/15 bg-white/70 dark:bg-black/30 px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-black/20 dark:focus:ring-white/20"',
'          />',
'          {node ? (',
'            <Link className="shrink-0 text-xs px-3 py-2 rounded-md border border-black/15 dark:border-white/15 hover:opacity-90" href={"/c/" + props.slug + "/v2/linha-do-tempo"}>',
'              Limpar nó',
'            </Link>',
'          ) : null}',
'        </div>',
'        {node ? (',
'          <div className="text-xs opacity-80">Filtro ativo — nó: <span className="font-mono">{node}</span></div>',
'        ) : null}',
'      </div>',
'',
'      <div className="space-y-3">',
'        {filtered.map((e) => {',
'          const tags = (e.tags || []).filter(Boolean);',
'          const nodeId = pickNode(e);',
'          return (',
'            <article key={e.id} className="rounded-xl border border-black/10 dark:border-white/10 bg-white/70 dark:bg-black/25 p-4">',
'              <div className="flex items-start justify-between gap-3">',
'                <div>',
'                  <h2 className="text-base font-semibold leading-snug">{e.title}</h2>',
'                  {e.date ? <p className="mt-1 text-xs opacity-70">{e.date}</p> : null}',
'                  {e.source ? <p className="mt-1 text-xs opacity-70">{e.source}</p> : null}',
'                </div>',
'                <span className="text-[10px] uppercase tracking-wider px-2 py-1 rounded-full border border-current/25 opacity-70">evento</span>',
'              </div>',
'',
'              {e.body ? <p className="mt-2 text-sm opacity-90 whitespace-pre-wrap">{e.body}</p> : null}',
'',
'              {tags.length ? (',
'                <div className="mt-3 flex flex-wrap gap-2">',
'                  {tags.map((t) => (',
'                    <span key={t} className="text-[11px] px-2 py-1 rounded-full border border-black/10 dark:border-white/10 opacity-80">{t}</span>',
'                  ))}',
'                </div>',
'              ) : null}',
'',
'              <div className="mt-3 flex items-center gap-3 text-xs">',
'                <Link className="underline opacity-80 hover:opacity-100" href={"/c/" + props.slug + "/v2/mapa?node=" + encodeURIComponent(nodeId)}>ver no mapa</Link>',
'                <Link className="underline opacity-80 hover:opacity-100" href={"/c/" + props.slug + "/v2/debate?node=" + encodeURIComponent(nodeId)}>debater</Link>',
'                <Link className="underline opacity-80 hover:opacity-100" href={"/c/" + props.slug + "/v2/provas?node=" + encodeURIComponent(nodeId)}>provas</Link>',
'                {e.href ? <a className="underline opacity-80 hover:opacity-100" href={e.href} target="_blank" rel="noreferrer">abrir fonte</a> : null}',
'              </div>',
'            </article>',
'          );',
'        })}',
'      </div>',
'',
'      {!filtered.length ? (',
'        <div className="mt-6 text-sm opacity-80">',
'          Nada por aqui ainda. Coloque <span className="font-mono">linhaDoTempo</span> (array) no JSON do caderno, ou dentro de <span className="font-mono">mapa</span>.',
'        </div>',
'      ) : null}',
'    </section>',
'  );',
'}'
)

WriteLines "src\components\v2\LinhaDoTempoV2.tsx" $timelineLines

# 2) /v2/linha-do-tempo/page.tsx
$linhaPageLines = @(
'import { notFound } from "next/navigation";',
'import V2Nav from "@/components/v2/V2Nav";',
'import { LinhaDoTempoV2 } from "@/components/v2/LinhaDoTempoV2";',
'import { loadCadernoV2 } from "@/lib/v2";',
'',
'export default async function Page({ params }: { params: Promise<{ slug: string }> }) {',
'  const { slug } = await params;',
'  const data = await loadCadernoV2(slug);',
'  if (!data) return notFound();',
'',
'  const anyData = data as unknown as Record<string, unknown>;',
'  const title0 = (typeof anyData.title === "string" && anyData.title) ? (anyData.title as string) : slug;',
'  const mapa = anyData.mapa ? anyData.mapa : anyData.data;',
'  const linha = anyData.linhaDoTempo ? anyData.linhaDoTempo : (anyData.timeline ? anyData.timeline : (mapa && typeof mapa === "object" ? (mapa as Record<string, unknown>).linhaDoTempo : undefined));',
'',
'  return (',
'    <main className="min-h-screen">',
'      <V2Nav slug={slug} active="linha" />',
'      <LinhaDoTempoV2 slug={slug} title={title0} linha={linha} mapa={mapa} />',
'    </main>',
'  );',
'}'
)

WriteLines "src\app\c\[slug]\v2\linha-do-tempo\page.tsx" $linhaPageLines

# 3) /v2/linha/page.tsx -> redirect para /v2/linha-do-tempo (remove warning antigo)
$linhaRedirectLines = @(
'import { redirect } from "next/navigation";',
'',
'export default async function Page({ params }: { params: Promise<{ slug: string }> }) {',
'  const { slug } = await params;',
'  redirect("/c/" + slug + "/v2/linha-do-tempo");',
'}'
)

WriteLines "src\app\c\[slug]\v2\linha\page.tsx" $linhaRedirectLines

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Step D5 — Linha do Tempo V2 bridge (v0_92)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que foi entregue") | Out-Null
$rep.Add("- LinhaDoTempoV2 (client): busca + filtro ?node= + links para Mapa/Debate/Provas.") | Out-Null
$rep.Add("- /v2/linha-do-tempo: pagina nova usando loadCadernoV2.") | Out-Null
$rep.Add("- /v2/linha: redirect para /v2/linha-do-tempo (limpa warning antigo).") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null

$rp = WriteReport "cv-step-d5-linha-do-tempo-v2-bridge-v0_92.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Step aplicado e verificado."