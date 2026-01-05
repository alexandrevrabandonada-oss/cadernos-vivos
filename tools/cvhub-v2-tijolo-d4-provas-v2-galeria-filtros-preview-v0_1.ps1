# CV — V2 — Tijolo D4: Provas V2 (galeria + filtros + preview + copiar citacao) — v0_1
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

function EnsureDir($p){ if(-not(Test-Path -LiteralPath $p)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function WriteUtf8NoBom($path,$text){
  EnsureDir (Split-Path -Parent $path)
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($path,$text,$enc)
}
function BackupFile($path){
  if(-not(Test-Path -LiteralPath $path)){ return $null }
  $bkRoot = Join-Path (Get-Location) "tools\_patch_backup"
  EnsureDir $bkRoot
  $stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
  $name = (Split-Path -Leaf $path)
  if ($name -match '\.tsx?$') { $name = $name + ".bak" }
  $dest = Join-Path $bkRoot ($stamp + "-" + $name)
  Copy-Item -LiteralPath $path -Destination $dest -Force
  return $dest
}
function Run([string]$exe,[string[]]$a){
  Write-Host ("[RUN] " + $exe + " " + ($a -join " "))
  & $exe @a
  if($LASTEXITCODE -ne 0){ throw ("[STOP] falhou (exit " + $LASTEXITCODE + "): " + $exe + " " + ($a -join " ")) }
}

$repo = Get-Location
Write-Host ("[DIAG] Repo: " + $repo)

$cmd = Get-Command "npm.cmd" -ErrorAction SilentlyContinue
$npmExe = if ($cmd) { $cmd.Source } else { "npm.cmd" }
Write-Host ("[DIAG] npm: " + $npmExe)

$pageProvas = Join-Path $repo "src\app\c\[slug]\v2\provas\page.tsx"
$compProvas = Join-Path $repo "src\components\v2\ProvasV2.tsx"

Write-Host ("[DIAG] page: " + $pageProvas)
Write-Host ("[DIAG] comp: " + $compProvas)

# -------------------------
# PATCH 1: Client component ProvasV2
# -------------------------
EnsureDir (Split-Path -Parent $compProvas)
$bkC = BackupFile $compProvas

$comp = @(
'"use client";',
'',
'import React, { useMemo, useState } from "react";',
'',
'type JsonPrimitive = string | number | boolean | null;',
'type JsonValue = JsonPrimitive | JsonValue[] | { [k: string]: JsonValue };',
'',
'type Prova = {',
'  id: string;',
'  title: string;',
'  url: string | null;',
'  kind: string | null;',
'  tags: string[];',
'  note: string | null;',
'  source: string | null;',
'};',
'',
'function isObj(v: unknown): v is Record<string, unknown> {',
'  return !!v && typeof v === "object" && !Array.isArray(v);',
'}',
'function asStr(v: unknown): string | null {',
'  return typeof v === "string" ? v : null;',
'}',
'function asArr(v: unknown): unknown[] {',
'  return Array.isArray(v) ? v : [];',
'}',
'function safeId(v: string, fallback: string): string {',
'  const s = (v || "").trim();',
'  if (!s) return fallback;',
'  return s.replace(/[^a-zA-Z0-9_-]+/g, "-").replace(/-+/g, "-").replace(/^-|-$/g, "").toLowerCase() || fallback;',
'}',
'',
'function normalizeAcervo(input: unknown): Prova[] {',
'  const rawItems: unknown[] = (() => {',
'    if (Array.isArray(input)) return input;',
'    if (isObj(input)) {',
'      const a = (input as Record<string, unknown>)["items"];',
'      const b = (input as Record<string, unknown>)["provas"];',
'      const c = (input as Record<string, unknown>)["evidence"];',
'      if (Array.isArray(a)) return a;',
'      if (Array.isArray(b)) return b;',
'      if (Array.isArray(c)) return c;',
'    }',
'    return [];',
'  })();',
'',
'  const out: Prova[] = [];',
'  for (let i = 0; i < rawItems.length; i++) {',
'    const it = rawItems[i];',
'    if (!isObj(it)) continue;',
'    const id = safeId(asStr(it["id"]) || "", "p" + (i + 1));',
'    const title = asStr(it["title"]) || asStr(it["nome"]) || asStr(it["label"]) || ("Prova " + (i + 1));',
'    const url = asStr(it["url"]) || asStr(it["link"]);',
'    const kind = asStr(it["kind"]) || asStr(it["tipo"]);',
'    const note = asStr(it["note"]) || asStr(it["nota"]) || asStr(it["quote"]) || asStr(it["trecho"]);',
'    const source = asStr(it["source"]) || asStr(it["fonte"]);',
'',
'    const tags: string[] = [];',
'    const tagsRaw = it["tags"];',
'    if (Array.isArray(tagsRaw)) for (const t of tagsRaw) if (typeof t === "string") tags.push(t);',
'',
'    out.push({ id, title, url, kind, tags, note, source });',
'  }',
'',
'  if (out.length === 0) {',
'    out.push({',
'      id: "p1",',
'      title: "Adicione itens em acervo.json para aparecer aqui",',
'      url: null,',
'      kind: "placeholder",',
'      tags: ["acervo"],',
'      note: "Formato sugerido: { items: [ { id, title, url, kind, tags, note } ] }",',
'      source: null',
'    });',
'  }',
'',
'  return out;',
'}',
'',
'function uniq(arr: string[]): string[] {',
'  const s = new Set<string>();',
'  for (const x of arr) if (x) s.add(x);',
'  return Array.from(s);',
'}',
'',
'function mkCite(p: Prova): string {',
'  const t = p.title || "Fonte";',
'  if (p.url) {',
'    const base = "- [" + t + "](" + p.url + ")";',
'    const tail = p.note ? (" — " + p.note) : "";',
'    return base + tail;',
'  }',
'  const base2 = "- " + t;',
'  const tail2 = p.note ? (" — " + p.note) : "";',
'  return base2 + tail2;',
'}',
'',
'async function copyText(text: string) {',
'  try {',
'    if (!text) return;',
'    if (typeof navigator !== "undefined" && navigator.clipboard && navigator.clipboard.writeText) {',
'      await navigator.clipboard.writeText(text);',
'    }',
'  } catch {',
'    // ok',
'  }',
'}',
'',
'export default function ProvasV2(props: { slug: string; title: string; acervo: unknown }) {',
'  const items = useMemo(() => normalizeAcervo(props.acervo), [props.acervo]);',
'  const [active, setActive] = useState<string>(items[0]?.id || "p1");',
'  const [q, setQ] = useState<string>("");',
'  const [kind, setKind] = useState<string>("");',
'  const [tag, setTag] = useState<string>("");',
'',
'  const kinds = useMemo(() => {',
'    return uniq(items.map((i) => (i.kind || "").trim()).filter(Boolean));',
'  }, [items]);',
'  const tags = useMemo(() => {',
'    const all: string[] = [];',
'    for (const i of items) for (const t of i.tags) all.push(t);',
'    return uniq(all.map((t) => t.trim()).filter(Boolean)).sort((a,b) => a.localeCompare(b));',
'  }, [items]);',
'',
'  const filtered = useMemo(() => {',
'    const qq = q.trim().toLowerCase();',
'    return items.filter((i) => {',
'      if (kind && (i.kind || "") !== kind) return false;',
'      if (tag && !i.tags.includes(tag)) return false;',
'      if (!qq) return true;',
'      const hay = (i.title + " " + (i.note || "") + " " + (i.source || "")).toLowerCase();',
'      const hasTag = i.tags.some((t) => t.toLowerCase().includes(qq));',
'      return hay.includes(qq) || hasTag;',
'    });',
'  }, [items, q, kind, tag]);',
'',
'  const activeItem = useMemo(() => filtered.find((i) => i.id === active) || items.find((i) => i.id === active) || filtered[0] || items[0], [filtered, items, active]);',
'',
'  return (',
'    <div style={{ display: "flex", flexWrap: "wrap", gap: 12, alignItems: "stretch" }}>',
'      <aside style={{ flex: "0 1 380px", border: "1px solid rgba(255,255,255,0.12)", borderRadius: 14, padding: 14 }}>',
'        <div style={{ display: "flex", justifyContent: "space-between", gap: 10, alignItems: "baseline", flexWrap: "wrap" }}>',
'          <h2 style={{ margin: 0, fontSize: 14, fontWeight: 900, letterSpacing: "-0.01em" }}>Provas</h2>',
'          <div style={{ opacity: 0.65, fontSize: 12 }}>Acervo V2 • {props.title}</div>',
'        </div>',
'',
'        <div style={{ marginTop: 10, display: "flex", gap: 8, alignItems: "center" }}>',
'          <input',
'            value={q}',
'            onChange={(e) => setQ(e.target.value)}',
'            placeholder="buscar titulo, nota, fonte, tag..."',
'            style={{',
'              width: "100%",',
'              border: "1px solid rgba(255,255,255,0.18)",',
'              background: "rgba(0,0,0,0.25)",',
'              color: "rgba(255,255,255,0.9)",',
'              borderRadius: 12, padding: "8px 10px", fontSize: 12',
'            }}',
'          />',
'        </div>',
'',
'        <div style={{ marginTop: 10, display: "flex", gap: 8, flexWrap: "wrap", alignItems: "center" }}>',
'          <span style={{ opacity: 0.65, fontSize: 12 }}>tipo:</span>',
'          <button onClick={() => setKind("")} style={{ border: "1px solid rgba(255,255,255,0.14)", background: kind ? "rgba(0,0,0,0.18)" : "rgba(255,255,255,0.12)", color: "rgba(255,255,255,0.92)", borderRadius: 999, padding: "4px 8px", fontSize: 12, cursor: "pointer" }}>todos</button>',
'          {kinds.map((k) => (',
'            <button key={k} onClick={() => setKind(k)} style={{ border: "1px solid rgba(255,255,255,0.14)", background: kind === k ? "rgba(255,255,255,0.12)" : "rgba(0,0,0,0.18)", color: "rgba(255,255,255,0.92)", borderRadius: 999, padding: "4px 8px", fontSize: 12, cursor: "pointer" }}>{k}</button>',
'          ))}',
'        </div>',
'',
'        <div style={{ marginTop: 10, display: "flex", gap: 8, flexWrap: "wrap", alignItems: "center" }}>',
'          <span style={{ opacity: 0.65, fontSize: 12 }}>tag:</span>',
'          <button onClick={() => setTag("")} style={{ border: "1px solid rgba(255,255,255,0.14)", background: tag ? "rgba(0,0,0,0.18)" : "rgba(255,255,255,0.12)", color: "rgba(255,255,255,0.92)", borderRadius: 999, padding: "4px 8px", fontSize: 12, cursor: "pointer" }}>todas</button>',
'          {tags.slice(0, 24).map((t) => (',
'            <button key={t} onClick={() => setTag(t)} style={{ border: "1px solid rgba(255,255,255,0.14)", background: tag === t ? "rgba(255,255,255,0.12)" : "rgba(0,0,0,0.18)", color: "rgba(255,255,255,0.92)", borderRadius: 999, padding: "4px 8px", fontSize: 12, cursor: "pointer" }}>{t}</button>',
'          ))}',
'          {tags.length > 24 ? <span style={{ opacity: 0.55, fontSize: 12 }}>+{tags.length - 24}</span> : null}',
'        </div>',
'',
'        <div style={{ marginTop: 12, opacity: 0.7, fontSize: 12 }}>itens: <b>{filtered.length}</b> / {items.length}</div>',
'',
'        <div style={{ marginTop: 10, display: "flex", flexDirection: "column", gap: 8 }}>',
'          {filtered.map((it) => {',
'            const on = it.id === active;',
'            return (',
'              <button',
'                key={it.id}',
'                onClick={() => setActive(it.id)}',
'                style={{',
'                  textAlign: "left",',
'                  border: "1px solid rgba(255,255,255,0.14)",',
'                  background: on ? "rgba(255,255,255,0.12)" : "rgba(0,0,0,0.18)",',
'                  color: "rgba(255,255,255,0.92)",',
'                  borderRadius: 14, padding: "10px 10px",',
'                  cursor: "pointer"',
'                }}',
'              >',
'                <div style={{ fontWeight: 950, letterSpacing: "-0.01em" }}>{it.title}</div>',
'                <div style={{ marginTop: 6, opacity: 0.65, fontSize: 12, display: "flex", gap: 8, flexWrap: "wrap" }}>',
'                  {it.kind ? <span style={{ border: "1px solid rgba(255,255,255,0.12)", borderRadius: 999, padding: "2px 7px" }}>{it.kind}</span> : null}',
'                  {it.tags.slice(0, 3).map((t) => (',
'                    <span key={t} style={{ border: "1px solid rgba(255,255,255,0.12)", borderRadius: 999, padding: "2px 7px" }}>{t}</span>',
'                  ))}',
'                  {it.url ? <span style={{ opacity: 0.7 }}>link</span> : <span style={{ opacity: 0.55 }}>sem link</span>}',
'                </div>',
'              </button>',
'            );',
'          })}',
'        </div>',
'      </aside>',
'',
'      <section style={{ flex: "1 1 700px", border: "1px solid rgba(255,255,255,0.12)", borderRadius: 14, padding: 16 }}>',
'        {!activeItem ? (',
'          <p style={{ opacity: 0.75 }}>Sem itens.</p>',
'        ) : (',
'          <div>',
'            <div style={{ opacity: 0.7, fontSize: 12, textTransform: "uppercase", letterSpacing: "0.08em" }}>Prova selecionada</div>',
'            <h1 style={{ marginTop: 8, fontSize: 22, fontWeight: 950, letterSpacing: "-0.03em" }}>{activeItem.title}</h1>',
'',
'            <div style={{ marginTop: 10, display: "flex", gap: 8, flexWrap: "wrap", alignItems: "center" }}>',
'              {activeItem.kind ? <span style={{ border: "1px solid rgba(255,255,255,0.14)", borderRadius: 999, padding: "4px 8px", fontSize: 12, opacity: 0.9 }}>{activeItem.kind}</span> : null}',
'              {activeItem.tags.map((t) => (',
'                <span key={t} style={{ border: "1px solid rgba(255,255,255,0.14)", borderRadius: 999, padding: "4px 8px", fontSize: 12, opacity: 0.9 }}>{t}</span>',
'              ))}',
'              <div style={{ marginLeft: "auto", display: "flex", gap: 8, flexWrap: "wrap" }}>',
'                <button onClick={() => copyText(mkCite(activeItem))} style={{ border: "1px solid rgba(255,255,255,0.18)", background: "rgba(255,255,255,0.10)", color: "rgba(255,255,255,0.92)", borderRadius: 12, padding: "8px 10px", fontSize: 12, cursor: "pointer" }}>copiar citacao</button>',
'                {activeItem.url ? (',
'                  <button onClick={() => copyText(activeItem.url || "")} style={{ border: "1px solid rgba(255,255,255,0.18)", background: "rgba(0,0,0,0.18)", color: "rgba(255,255,255,0.92)", borderRadius: 12, padding: "8px 10px", fontSize: 12, cursor: "pointer" }}>copiar url</button>',
'                ) : null}',
'              </div>',
'            </div>',
'',
'            {activeItem.source ? (',
'              <p style={{ marginTop: 10, opacity: 0.85 }}><b>Fonte:</b> {activeItem.source}</p>',
'            ) : null}',
'',
'            {activeItem.note ? (',
'              <div style={{ marginTop: 10, border: "1px solid rgba(255,255,255,0.14)", borderRadius: 14, padding: 12, background: "rgba(0,0,0,0.14)" }}>',
'                <div style={{ opacity: 0.7, fontSize: 12, textTransform: "uppercase", letterSpacing: "0.08em" }}>Nota / trecho</div>',
'                <div style={{ marginTop: 8, opacity: 0.92, lineHeight: 1.6, whiteSpace: "pre-wrap" }}>{activeItem.note}</div>',
'              </div>',
'            ) : null}',
'',
'            {activeItem.url ? (',
'              <div style={{ marginTop: 12, borderTop: "1px solid rgba(255,255,255,0.10)", paddingTop: 12 }}>',
'                <div style={{ opacity: 0.7, fontSize: 12, textTransform: "uppercase", letterSpacing: "0.08em" }}>Link</div>',
'                <div style={{ marginTop: 8, display: "flex", gap: 10, flexWrap: "wrap", alignItems: "center" }}>',
'                  <a href={activeItem.url} target="_blank" rel="noreferrer" style={{ textDecoration: "underline", opacity: 0.92 }}>{activeItem.url}</a>',
'                  <span style={{ opacity: 0.55, fontSize: 12 }}>(abre em nova aba)</span>',
'                </div>',
'              </div>',
'            ) : null}',
'',
'            <div style={{ marginTop: 12, borderTop: "1px solid rgba(255,255,255,0.10)", paddingTop: 12 }}>',
'              <div style={{ opacity: 0.7, fontSize: 12, textTransform: "uppercase", letterSpacing: "0.08em" }}>Citacao pronta (markdown)</div>',
'              <pre style={{ marginTop: 8, padding: 12, borderRadius: 14, background: "rgba(0,0,0,0.22)", border: "1px solid rgba(255,255,255,0.12)", overflowX: "auto", fontSize: 12, lineHeight: 1.5 }}>',
'                {mkCite(activeItem)}',
'              </pre>',
'            </div>',
'          </div>',
'        )}',
'      </section>',
'    </div>',
'  );',
'}',
''
) -join "`n"

WriteUtf8NoBom $compProvas $comp
Write-Host "[OK] wrote: ProvasV2.tsx"
if ($bkC) { Write-Host ("[BK] " + $bkC) }

# -------------------------
# PATCH 2: Page server /c/[slug]/v2/provas
# -------------------------
EnsureDir (Split-Path -Parent $pageProvas)
$bkP = BackupFile $pageProvas

$page = @(
'import Link from "next/link";',
'import ProvasV2 from "@/components/v2/ProvasV2";',
'import { loadCadernoV2 } from "@/lib/v2";',
'',
'function isObj(v: unknown): v is Record<string, unknown> {',
'  return !!v && typeof v === "object" && !Array.isArray(v);',
'}',
'function asStr(v: unknown): string | null {',
'  return typeof v === "string" ? v : null;',
'}',
'',
'export default async function Page({ params }: { params: Promise<{ slug: string }> }) {',
'  const { slug } = await params;',
'',
'  let title = slug;',
'  let acervo: unknown = { items: [] };',
'',
'  try {',
'    const c = await loadCadernoV2(slug);',
'    const cObj = isObj(c) ? c : null;',
'    const metaObj = cObj && isObj(cObj["meta"]) ? (cObj["meta"] as Record<string, unknown>) : null;',
'    title = asStr(metaObj ? metaObj["title"] : null) || slug;',
'    acervo = cObj ? cObj["acervo"] : acervo;',
'  } catch {',
'    // ok',
'  }',
'',
'  return (',
'    <main style={{ padding: 24, maxWidth: 1240, margin: "0 auto" }}>',
'      <header style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", gap: 16, flexWrap: "wrap" }}>',
'        <div>',
'          <div style={{ opacity: 0.75, fontSize: 12, letterSpacing: "0.08em", textTransform: "uppercase" }}>Concreto Zen • V2</div>',
'          <h1 style={{ fontSize: 26, fontWeight: 900, letterSpacing: "-0.03em", marginTop: 6 }}>Provas</h1>',
'          <p style={{ marginTop: 6, opacity: 0.85 }}>{title}</p>',
'        </div>',
'        <nav style={{ display: "flex", gap: 12, flexWrap: "wrap" }}>',
'          <Link href={"/c/" + slug + "/v2"} style={{ textDecoration: "underline" }}>← Home V2</Link>',
'          <Link href={"/c/" + slug + "/v2/mapa"} style={{ textDecoration: "underline" }}>Mapa</Link>',
'          <Link href={"/c/" + slug + "/v2/debate"} style={{ textDecoration: "underline" }}>Debate</Link>',
'          <Link href={"/c/" + slug} style={{ textDecoration: "underline" }}>V1</Link>',
'        </nav>',
'      </header>',
'',
'      <section style={{ marginTop: 14 }}>',
'        <ProvasV2 slug={slug} title={title} acervo={acervo} />',
'      </section>',
'',
'      <footer style={{ marginTop: 18, opacity: 0.6, fontSize: 12 }}>',
'        Proximo: Tijolo D5 (Linha do tempo V2 derivada do mapa.json).',
'      </footer>',
'    </main>',
'  );',
'}',
''
) -join "`n"

WriteUtf8NoBom $pageProvas $page
Write-Host "[OK] wrote: /c/[slug]/v2/provas (D4)"
if ($bkP) { Write-Host ("[BK] " + $bkP) }

# -------------------------
# VERIFY
# -------------------------
Run $npmExe @("run","lint")
Run $npmExe @("run","build")

# -------------------------
# REPORT
# -------------------------
$reports = Join-Path $repo "reports"
EnsureDir $reports
$reportPath = Join-Path $reports "cv-v2-tijolo-d4-provas-v2-galeria-filtros-preview-v0_1.md"

$report = @(
  "# CV — V2 — Tijolo D4 (Provas V2)",
  "",
  "## Entrega",
  "- Galeria de provas baseada em acervo.json (ou acervo como array).",
  "- Busca + filtros por tipo (kind) e tag.",
  "- Painel de preview com nota/trecho, fonte e link (quando existir).",
  "- Botao para copiar citacao pronta em markdown.",
  "",
  "## Arquivos",
  "- src/components/v2/ProvasV2.tsx",
  "- src/app/c/[slug]/v2/provas/page.tsx",
  "",
  "## Verify",
  "- npm run lint",
  "- npm run build",
  ""
) -join "`n"

WriteUtf8NoBom $reportPath $report
Write-Host ("[OK] Report: " + $reportPath)
Write-Host "[OK] Tijolo D4 aplicado."