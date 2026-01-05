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

# 1) ProvasV2.tsx (client)
$provasLines = @(
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
'type ProofCard = {',
'  id: string;',
'  title: string;',
'  body?: string;',
'  href?: string;',
'  source?: string;',
'  tags?: string[];',
'  nodeIds?: string[];',
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
'function normalizeProofs(raw: unknown, mapa: unknown): ProofCard[] {',
'  const fromArray = (arr: unknown[]): ProofCard[] => {',
'    return arr.map((it, idx) => {',
'      if (isObj(it)) {',
'        const id = asString(it.id, "p-" + idx);',
'        const title = asString(it.title ?? it.name ?? it.label, id);',
'        const body = typeof it.body === "string" ? it.body : (typeof it.text === "string" ? it.text : (typeof it.summary === "string" ? it.summary : undefined));',
'        const href = typeof it.href === "string" ? it.href : (typeof it.url === "string" ? it.url : undefined);',
'        const source = typeof it.source === "string" ? it.source : (typeof it.origin === "string" ? it.origin : undefined);',
'        const tags = toStringArray(it.tags ?? it.tag ?? it.kind);',
'        const nodeIds = toStringArray(it.nodeIds ?? it.nodes ?? it.node ?? it.mapNodeId);',
'        return { id, title, body, href, source, tags, nodeIds };',
'      }',
'      return { id: "p-" + idx, title: asString(it, "p-" + idx) };',
'    });',
'  };',
'',
'  if (Array.isArray(raw)) return fromArray(raw);',
'  if (isObj(raw)) {',
'    const items = (raw.items ?? raw.provas ?? raw.evidences) as unknown;',
'    if (Array.isArray(items)) return fromArray(items);',
'  }',
'  if (isObj(mapa)) {',
'    const items2 = (mapa.provas ?? mapa.evidences ?? mapa.proofs) as unknown;',
'    if (Array.isArray(items2)) return fromArray(items2);',
'  }',
'  return [];',
'}',
'',
'export function ProvasV2(props: { slug: string; title: string; provas?: unknown; mapa?: unknown }) {',
'  const sp = useSearchParams();',
'  const node = (sp && sp.get("node")) ? (sp.get("node") || "") : "";',
'  const [q, setQ] = useState<string>("");',
'',
'  const items = useMemo(() => normalizeProofs(props.provas, props.mapa), [props.provas, props.mapa]);',
'',
'  const filtered = useMemo(() => {',
'    const qq = q.trim().toLowerCase();',
'    return items.filter((p) => {',
'      if (node) {',
'        const inNode = (p.nodeIds || []).includes(node) || p.id === node;',
'        if (!inNode) return false;',
'      }',
'      if (!qq) return true;',
'      const hay = (p.title + " " + (p.body || "") + " " + (p.source || "") + " " + (p.tags || []).join(" ")).toLowerCase();',
'      return hay.includes(qq);',
'    });',
'  }, [items, q, node]);',
'',
'  return (',
'    <section className="w-full max-w-5xl mx-auto px-4 py-8">',
'      <header className="mb-6 flex items-start justify-between gap-4">',
'        <div>',
'          <h1 className="text-2xl font-semibold tracking-tight">{props.title}</h1>',
'          <p className="text-sm opacity-80">Provas (V2) — evidências, links e referências do caderno.</p>',
'        </div>',
'        <div className="flex items-center gap-2">',
'          <Link className="text-xs underline opacity-80 hover:opacity-100" href={"/c/" + props.slug + "/v2/debate" + (node ? ("?node=" + encodeURIComponent(node)) : "")}>Debate</Link>',
'          <Link className="text-xs underline opacity-80 hover:opacity-100" href={"/c/" + props.slug + "/v2/mapa"}>Mapa</Link>',
'        </div>',
'      </header>',
'',
'      <div className="mb-4 flex flex-col gap-2">',
'        <div className="flex items-center gap-2">',
'          <input',
'            value={q}',
'            onChange={(e) => setQ(e.target.value)}',
'            placeholder="Buscar nas provas…"',
'            className="w-full rounded-md border border-black/15 dark:border-white/15 bg-white/70 dark:bg-black/30 px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-black/20 dark:focus:ring-white/20"',
'          />',
'          {node ? (',
'            <Link',
'              className="shrink-0 text-xs px-3 py-2 rounded-md border border-black/15 dark:border-white/15 hover:opacity-90"',
'              href={"/c/" + props.slug + "/v2/provas"}',
'            >',
'              Limpar nó',
'            </Link>',
'          ) : null}',
'        </div>',
'        {node ? (',
'          <div className="text-xs opacity-80">',
'            Filtro ativo — nó: <span className="font-mono">{node}</span>',
'          </div>',
'        ) : null}',
'      </div>',
'',
'      <div className="grid grid-cols-1 md:grid-cols-2 gap-3">',
'        {filtered.map((p) => {',
'          const tags = (p.tags || []).filter(Boolean);',
'          return (',
'            <article key={p.id} className="rounded-xl border border-black/10 dark:border-white/10 bg-white/70 dark:bg-black/25 p-4">',
'              <div className="flex items-start justify-between gap-3">',
'                <h2 className="text-base font-semibold leading-snug">{p.title}</h2>',
'                <span className="text-[10px] uppercase tracking-wider px-2 py-1 rounded-full border border-current/25 opacity-70">prova</span>',
'              </div>',
'              {p.source ? <p className="mt-1 text-xs opacity-70">{p.source}</p> : null}',
'              {p.body ? <p className="mt-2 text-sm opacity-90 whitespace-pre-wrap">{p.body}</p> : null}',
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
'                <Link className="underline opacity-80 hover:opacity-100" href={"/c/" + props.slug + "/v2/debate?node=" + encodeURIComponent((p.nodeIds && p.nodeIds.length ? p.nodeIds[0] : p.id))}>debater</Link>',
'                <Link className="underline opacity-80 hover:opacity-100" href={"/c/" + props.slug + "/v2/mapa" + ((p.nodeIds && p.nodeIds.length) ? ("?node=" + encodeURIComponent(p.nodeIds[0])) : "")}>ver no mapa</Link>',
'                {p.href ? (',
'                  <a className="underline opacity-80 hover:opacity-100" href={p.href} target="_blank" rel="noreferrer">abrir fonte</a>',
'                ) : null}',
'              </div>',
'            </article>',
'          );',
'        })}',
'      </div>',
'',
'      {!filtered.length ? (',
'        <div className="mt-6 text-sm opacity-80">',
'          Nada pra mostrar ainda. Procure por <span className="font-mono">provas</span> no JSON do caderno (ou dentro de <span className="font-mono">mapa</span>).',
'        </div>',
'      ) : null}',
'    </section>',
'  );',
'}'
)

WriteLines "src\components\v2\ProvasV2.tsx" $provasLines

# 2) /v2/provas/page.tsx
$provasPageLines = @(
'import { notFound } from "next/navigation";',
'import V2Nav from "@/components/v2/V2Nav";',
'import { ProvasV2 } from "@/components/v2/ProvasV2";',
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
'  const provas = (anyData.provas ? anyData.provas : (mapa && typeof mapa === "object" ? (mapa as Record<string, unknown>).provas : undefined));',
'',
'  return (',
'    <main className="min-h-screen">',
'      <V2Nav slug={slug} active="provas" />',
'      <ProvasV2 slug={slug} title={title0} provas={provas} mapa={mapa} />',
'    </main>',
'  );',
'}'
)

WriteLines "src\app\c\[slug]\v2\provas\page.tsx" $provasPageLines

# 3) Patch DebateV2.tsx para aceitar provas + mostrar relacionadas (best-effort)
$debateRel = Join-Path $repo "src\components\v2\DebateV2.tsx"
if (!(Test-Path -LiteralPath $debateRel)) { throw ("[STOP] nao achei: " + $debateRel) }
$debRaw = Get-Content -LiteralPath $debateRel -Raw
if ($null -eq $debRaw) { throw ("[STOP] leitura nula: " + $debateRel) }

# estratégia segura: reescreve com uma versão compatível (mantém busca + node filter + adiciona provas relacionadas)
$debateLines2 = @(
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
'type DebateCard = {',
'  id: string;',
'  title: string;',
'  body?: string;',
'  tags?: string[];',
'  nodeIds?: string[];',
'};',
'',
'type ProofCard = {',
'  id: string;',
'  title: string;',
'  href?: string;',
'  source?: string;',
'  nodeIds?: string[];',
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
'function pickCardsFromDebate(debate: unknown): DebateCard[] {',
'  if (!debate) return [];',
'  if (Array.isArray(debate)) {',
'    return debate.map((it, idx) => {',
'      if (isObj(it)) {',
'        const id = asString(it.id, "d-" + idx);',
'        const title = asString(it.title ?? it.name ?? it.label, id);',
'        const body = typeof it.body === "string" ? it.body : (typeof it.text === "string" ? it.text : undefined);',
'        const tags = toStringArray(it.tags ?? it.tag);',
'        const nodeIds = toStringArray(it.nodeIds ?? it.nodes ?? it.node ?? it.mapNodeId);',
'        return { id, title, body, tags, nodeIds };',
'      }',
'      return { id: "d-" + idx, title: asString(it, "d-" + idx) };',
'    });',
'  }',
'  if (isObj(debate)) {',
'    const cards = (debate.cards ?? debate.items ?? debate.debate) as unknown;',
'    if (Array.isArray(cards)) return pickCardsFromDebate(cards);',
'  }',
'  return [];',
'}',
'',
'function pickCardsFromMapa(mapa: unknown): DebateCard[] {',
'  if (!mapa || !isObj(mapa)) return [];',
'  const nodes = mapa.nodes;',
'  if (!Array.isArray(nodes)) return [];',
'  return nodes.map((n, idx) => {',
'    if (isObj(n)) {',
'      const id = asString(n.id, "node-" + idx);',
'      const title = asString(n.title ?? n.label ?? n.name, id);',
'      const body = typeof n.summary === "string" ? n.summary : (typeof n.desc === "string" ? n.desc : undefined);',
'      const tags = toStringArray(n.kind ?? n.tags);',
'      return { id, title, body, tags, nodeIds: [id] };',
'    }',
'    return { id: "node-" + idx, title: "node-" + idx, nodeIds: ["node-" + idx] };',
'  });',
'}',
'',
'function normalizeCards(debate: unknown, mapa: unknown): DebateCard[] {',
'  const a = pickCardsFromDebate(debate);',
'  if (a.length) return a;',
'  return pickCardsFromMapa(mapa);',
'}',
'',
'function normalizeProofs(raw: unknown, mapa: unknown): ProofCard[] {',
'  const fromArray = (arr: unknown[]): ProofCard[] => {',
'    return arr.map((it, idx) => {',
'      if (isObj(it)) {',
'        const id = asString(it.id, "p-" + idx);',
'        const title = asString(it.title ?? it.name ?? it.label, id);',
'        const href = typeof it.href === "string" ? it.href : (typeof it.url === "string" ? it.url : undefined);',
'        const source = typeof it.source === "string" ? it.source : (typeof it.origin === "string" ? it.origin : undefined);',
'        const nodeIds = toStringArray(it.nodeIds ?? it.nodes ?? it.node ?? it.mapNodeId);',
'        return { id, title, href, source, nodeIds };',
'      }',
'      return { id: "p-" + idx, title: asString(it, "p-" + idx) };',
'    });',
'  };',
'  if (Array.isArray(raw)) return fromArray(raw);',
'  if (isObj(raw)) {',
'    const items = (raw.items ?? raw.provas ?? raw.evidences) as unknown;',
'    if (Array.isArray(items)) return fromArray(items);',
'  }',
'  if (isObj(mapa)) {',
'    const items2 = (mapa.provas ?? mapa.evidences ?? mapa.proofs) as unknown;',
'    if (Array.isArray(items2)) return fromArray(items2);',
'  }',
'  return [];',
'}',
'',
'export function DebateV2(props: { slug: string; title: string; debate?: unknown; mapa?: unknown; provas?: unknown }) {',
'  const sp = useSearchParams();',
'  const node = (sp && sp.get("node")) ? (sp.get("node") || "") : "";',
'',
'  const [q, setQ] = useState<string>("");',
'  const cards = useMemo(() => normalizeCards(props.debate, props.mapa), [props.debate, props.mapa]);',
'  const proofs = useMemo(() => normalizeProofs(props.provas, props.mapa), [props.provas, props.mapa]);',
'',
'  const filtered = useMemo(() => {',
'    const qq = q.trim().toLowerCase();',
'    return cards.filter((c) => {',
'      if (node) {',
'        const inNode = (c.nodeIds || []).includes(node) || c.id === node;',
'        if (!inNode) return false;',
'      }',
'      if (!qq) return true;',
'      const hay = (c.title + " " + (c.body || "") + " " + (c.tags || []).join(" ")).toLowerCase();',
'      return hay.includes(qq);',
'    });',
'  }, [cards, q, node]);',
'',
'  const relatedTo = (cardId: string): ProofCard[] => {',
'    const rel = proofs.filter((p) => (p.nodeIds || []).includes(cardId) || p.id === cardId);',
'    return rel.slice(0, 3);',
'  };',
'',
'  return (',
'    <section className="w-full max-w-5xl mx-auto px-4 py-8">',
'      <header className="mb-6 flex items-start justify-between gap-4">',
'        <div>',
'          <h1 className="text-2xl font-semibold tracking-tight">{props.title}</h1>',
'          <p className="text-sm opacity-80">Debate (V2) — cards + ponte com provas.</p>',
'        </div>',
'        <div className="flex items-center gap-2">',
'          <Link className="text-xs underline opacity-80 hover:opacity-100" href={"/c/" + props.slug + "/v2/mapa"}>Mapa</Link>',
'          <Link className="text-xs underline opacity-80 hover:opacity-100" href={"/c/" + props.slug + "/v2/provas" + (node ? ("?node=" + encodeURIComponent(node)) : "")}>Provas</Link>',
'        </div>',
'      </header>',
'',
'      <div className="mb-4 flex flex-col gap-2">',
'        <div className="flex items-center gap-2">',
'          <input',
'            value={q}',
'            onChange={(e) => setQ(e.target.value)}',
'            placeholder="Buscar no debate…"',
'            className="w-full rounded-md border border-black/15 dark:border-white/15 bg-white/70 dark:bg-black/30 px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-black/20 dark:focus:ring-white/20"',
'          />',
'          {node ? (',
'            <Link',
'              className="shrink-0 text-xs px-3 py-2 rounded-md border border-black/15 dark:border-white/15 hover:opacity-90"',
'              href={"/c/" + props.slug + "/v2/debate"}',
'            >',
'              Limpar nó',
'            </Link>',
'          ) : null}',
'        </div>',
'        {node ? (',
'          <div className="text-xs opacity-80">',
'            Filtro ativo — nó: <span className="font-mono">{node}</span>',
'          </div>',
'        ) : null}',
'      </div>',
'',
'      <div className="grid grid-cols-1 md:grid-cols-2 gap-3">',
'        {filtered.map((c) => {',
'          const tags = (c.tags || []).filter(Boolean);',
'          const rel = relatedTo(c.id);',
'          return (',
'            <article key={c.id} className="rounded-xl border border-black/10 dark:border-white/10 bg-white/70 dark:bg-black/25 p-4">',
'              <div className="flex items-start justify-between gap-3">',
'                <h2 className="text-base font-semibold leading-snug">{c.title}</h2>',
'                <span className="text-[10px] uppercase tracking-wider px-2 py-1 rounded-full border border-current/25 opacity-70">card</span>',
'              </div>',
'',
'              {c.body ? <p className="mt-2 text-sm opacity-90 whitespace-pre-wrap">{c.body}</p> : null}',
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
'                <Link className="underline opacity-80 hover:opacity-100" href={"/c/" + props.slug + "/v2/mapa?node=" + encodeURIComponent(c.id)}>ver no mapa</Link>',
'                <Link className="underline opacity-80 hover:opacity-100" href={"/c/" + props.slug + "/v2/provas?node=" + encodeURIComponent(c.id)}>ver provas</Link>',
'              </div>',
'',
'              {rel.length ? (',
'                <div className="mt-4 rounded-lg border border-black/10 dark:border-white/10 bg-black/[0.03] dark:bg-white/[0.04] p-3">',
'                  <div className="text-xs font-semibold opacity-80 mb-2">Provas relacionadas</div>',
'                  <ul className="space-y-1 text-xs">',
'                    {rel.map((p) => (',
'                      <li key={p.id} className="flex items-start justify-between gap-2">',
'                        <span className="opacity-90">{p.title}{p.source ? (" — " + p.source) : ""}</span>',
'                        {p.href ? <a className="underline opacity-80 hover:opacity-100" href={p.href} target="_blank" rel="noreferrer">abrir</a> : null}',
'                      </li>',
'                    ))}',
'                  </ul>',
'                </div>',
'              ) : null}',
'            </article>',
'          );',
'        })}',
'      </div>',
'',
'      {!filtered.length ? (',
'        <div className="mt-6 text-sm opacity-80">',
'          Nada pra mostrar ainda. Se o caderno não tiver <span className="font-mono">debate</span>, eu tento gerar cards do <span className="font-mono">mapa.nodes</span>.',
'        </div>',
'      ) : null}',
'    </section>',
'  );',
'}'
)

# só reescreve se o arquivo atual for diferente (com backup)
$debNext = ($debateLines2 -join "`r`n")
if ($debRaw -ne $debNext) {
  $bk2 = BackupFile $debateRel
  WriteUtf8NoBom $debateRel $debNext
  Write-Host ("[OK] patched: " + $debateRel)
  Write-Host ("[BK] " + $bk2)
  $changed.Add($debateRel) | Out-Null
} else {
  Write-Host ("[OK] sem mudanca: " + $debateRel)
}

# 4) /v2/debate/page.tsx — passar provas
$debatePageRel = "src\app\c\[slug]\v2\debate\page.tsx"
if (Test-Path -LiteralPath (Join-Path $repo $debatePageRel)) {
  $dp = Get-Content -LiteralPath (Join-Path $repo $debatePageRel) -Raw
  if ($null -eq $dp) { throw ("[STOP] leitura nula: " + (Join-Path $repo $debatePageRel)) }

  # patch simples: inserir provas e passar prop provas=
  if ($dp.IndexOf("provas=") -lt 0) {
    $dp2 = $dp

    if ($dp2.IndexOf("const provas =") -lt 0) {
      # injeta const provas = ... logo depois de const debate = ...
      $anchor = 'const debate ='
      $ai = $dp2.IndexOf($anchor)
      if ($ai -ge 0) {
        $lineEnd = $dp2.IndexOf("`n", $ai)
        if ($lineEnd -lt 0) { $lineEnd = $dp2.Length }
        $ins = "`r`n  const provas = (anyData.provas ? anyData.provas : (mapa && typeof mapa === ""object"" ? (mapa as Record<string, unknown>).provas : undefined));`r`n"
        $dp2 = $dp2.Substring(0, $lineEnd) + $ins + $dp2.Substring($lineEnd)
      }
    }

    $dp2 = $dp2.Replace("<DebateV2 slug={slug} title={title} debate={debate} mapa={mapa} />", "<DebateV2 slug={slug} title={title} debate={debate} mapa={mapa} provas={provas} />")

    if ($dp2 -ne $dp) {
      $bk3 = BackupFile (Join-Path $repo $debatePageRel)
      WriteUtf8NoBom (Join-Path $repo $debatePageRel) $dp2
      Write-Host ("[OK] patched: " + (Join-Path $repo $debatePageRel))
      Write-Host ("[BK] " + $bk3)
      $changed.Add((Join-Path $repo $debatePageRel)) | Out-Null
    } else {
      Write-Host ("[OK] sem mudanca: " + (Join-Path $repo $debatePageRel))
    }
  } else {
    Write-Host ("[OK] /v2/debate ja passa provas")
  }
} else {
  Write-Host ("[SKIP] nao achei: " + (Join-Path $repo $debatePageRel))
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Step D4 — ProvasV2 ↔ DebateV2 (v0_91)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que foi entregue") | Out-Null
$rep.Add("- ProvasV2 (client): busca + filtro ?node= + links p/ Debate/Mapa.") | Out-Null
$rep.Add("- DebateV2: recebe provas e mostra ate 3 provas relacionadas por card (best-effort por nodeIds).") | Out-Null
$rep.Add("- /v2/provas e /v2/debate: passam provas/mapa.") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null

$rp = WriteReport "cv-step-d4-provasv2-debate-bridge-v0_91.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Step aplicado e verificado."