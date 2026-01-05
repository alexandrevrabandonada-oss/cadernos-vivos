# CV — V2 — Tijolo D3: Debate V2 (perguntas + posições + provas + ações) — v0_1
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

$pagePath = Join-Path $repo "src\app\c\[slug]\v2\debate\page.tsx"
$compPath = Join-Path $repo "src\components\v2\DebateV2.tsx"

Write-Host ("[DIAG] page: " + $pagePath)
Write-Host ("[DIAG] comp: " + $compPath)

# -------------------------
# PATCH 1: Client component DebateV2
# -------------------------
EnsureDir (Split-Path -Parent $compPath)
$bkC = BackupFile $compPath

$comp = @(
'"use client";',
'',
'import React, { useMemo, useState } from "react";',
'',
'type JsonPrimitive = string | number | boolean | null;',
'type JsonValue = JsonPrimitive | JsonValue[] | { [k: string]: JsonValue };',
'',
'type Evidence = { id: string; title: string; url: string | null; note: string | null };',
'type Position = { id: string; title: string; stance: string | null; bullets: string[] };',
'type DebateItem = {',
'  id: string;',
'  question: string;',
'  summary: string | null;',
'  tags: string[];',
'  positions: Position[];',
'  evidence: Evidence[];',
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
'',
'function safeId(v: string, fallback: string): string {',
'  const s = (v || "").trim();',
'  if (!s) return fallback;',
'  return s.replace(/[^a-zA-Z0-9_-]+/g, "-").replace(/-+/g, "-").replace(/^-|-$/g, "").toLowerCase() || fallback;',
'}',
'',
'function normalizeDebate(input: unknown): DebateItem[] {',
'  const rawItems: unknown[] = (() => {',
'    if (Array.isArray(input)) return input;',
'    if (isObj(input)) {',
'      const a = (input as Record<string, unknown>)["items"];',
'      const b = (input as Record<string, unknown>)["threads"];',
'      const c = (input as Record<string, unknown>)["debates"];',
'      if (Array.isArray(a)) return a;',
'      if (Array.isArray(b)) return b;',
'      if (Array.isArray(c)) return c;',
'    }',
'    return [];',
'  })();',
'',
'  const out: DebateItem[] = [];',
'  for (let i = 0; i < rawItems.length; i++) {',
'    const it = rawItems[i];',
'    if (!isObj(it)) continue;',
'    const id = safeId(asStr(it["id"]) || "", "q" + (i + 1));',
'    const question = asStr(it["question"]) || asStr(it["q"]) || asStr(it["title"]) || asStr(it["pergunta"]) || ("Pergunta " + (i + 1));',
'    const summary = asStr(it["summary"]) || asStr(it["resumo"]) || asStr(it["nota"]);',
'',
'    const tagsRaw = it["tags"];',
'    const tags: string[] = [];',
'    if (Array.isArray(tagsRaw)) for (const t of tagsRaw) if (typeof t === "string") tags.push(t);',
'',
'    const posRaw = it["positions"] ?? it["posicoes"] ?? it["lados"] ?? it["sides"];',
'    const positions: Position[] = [];',
'    const posArr = asArr(posRaw);',
'    for (let j = 0; j < posArr.length; j++) {',
'      const p = posArr[j];',
'      if (!isObj(p)) continue;',
'      const pid = safeId(asStr(p["id"]) || "", id + "-p" + (j + 1));',
'      const title = asStr(p["title"]) || asStr(p["lado"]) || asStr(p["posicao"]) || ("Posicao " + (j + 1));',
'      const stance = asStr(p["stance"]) || asStr(p["tese"]) || asStr(p["tom"]);',
'      const bullets: string[] = [];',
'      const bl = p["bullets"] ?? p["pontos"] ?? p["claims"] ?? p["argumentos"];',
'      const blArr = asArr(bl);',
'      for (const b of blArr) {',
'        const s = asStr(b);',
'        if (s) bullets.push(s);',
'      }',
'      const text = asStr(p["text"]);',
'      if (text && bullets.length === 0) bullets.push(text);',
'      positions.push({ id: pid, title, stance, bullets });',
'    }',
'',
'    const evRaw = it["evidence"] ?? it["provas"] ?? it["refs"] ?? it["referencias"];',
'    const evidence: Evidence[] = [];',
'    const evArr = asArr(evRaw);',
'    for (let k = 0; k < evArr.length; k++) {',
'      const e = evArr[k];',
'      if (!isObj(e)) continue;',
'      const eid = safeId(asStr(e["id"]) || "", id + "-e" + (k + 1));',
'      const title = asStr(e["title"]) || asStr(e["nome"]) || asStr(e["label"]) || ("Prova " + (k + 1));',
'      const url = asStr(e["url"]) || asStr(e["link"]);',
'      const note = asStr(e["note"]) || asStr(e["nota"]) || asStr(e["quote"]);',
'      evidence.push({ id: eid, title, url, note });',
'    }',
'',
'    out.push({ id, question, summary, tags, positions, evidence });',
'  }',
'',
'  // fallback: se veio vazio, cria um item de placeholder',
'  if (out.length === 0) {',
'    out.push({',
'      id: "q1",',
'      question: "Qual e a pergunta central deste caderno?",',
'      summary: "Adicione debate.json com items/threads para aparecer aqui.",',
'      tags: ["placeholder"],',
'      positions: [',
'        { id: "q1-p1", title: "Hipotese A", stance: "rascunho", bullets: ["Escreva 3 pontos aqui."] },',
'        { id: "q1-p2", title: "Hipotese B", stance: "rascunho", bullets: ["Escreva 3 pontos aqui."] },',
'      ],',
'      evidence: [',
'        { id: "q1-e1", title: "Fonte ou prova (link)", url: null, note: "Coloque URL em debate.json para virar link clicavel." }',
'      ]',
'    });',
'  }',
'',
'  return out;',
'}',
'',
'function joinText(item: DebateItem): string {',
'  const lines: string[] = [];',
'  lines.push(item.question);',
'  if (item.summary) lines.push("", item.summary);',
'  if (item.tags.length) lines.push("", "Tags: " + item.tags.join(", "));',
'  lines.push("");',
'  for (const p of item.positions) {',
'    lines.push("[" + p.title + (p.stance ? " - " + p.stance : "") + "]");',
'    for (const b of p.bullets) lines.push("- " + b);',
'    lines.push("");',
'  }',
'  if (item.evidence.length) {',
'    lines.push("Provas:");',
'    for (const e of item.evidence) {',
'      const u = e.url ? (" (" + e.url + ")") : "";',
'      lines.push("- " + e.title + u);',
'      if (e.note) lines.push("  " + e.note);',
'    }',
'  }',
'  return lines.join("\\n");',
'}',
'',
'export default function DebateV2(props: { slug: string; title: string; debate: unknown }) {',
'  const items = useMemo(() => normalizeDebate(props.debate), [props.debate]);',
'  const [active, setActive] = useState<string>(items[0]?.id || "q1");',
'',
'  const activeItem = useMemo(() => items.find((i) => i.id === active) || items[0], [items, active]);',
'',
'  const [q, setQ] = useState<string>("");',
'  const filtered = useMemo(() => {',
'    const qq = q.trim().toLowerCase();',
'    if (!qq) return items;',
'    return items.filter((it) => it.question.toLowerCase().includes(qq) || it.tags.some((t) => t.toLowerCase().includes(qq)));',
'  }, [items, q]);',
'',
'  async function copyActive() {',
'    try {',
'      const text = activeItem ? joinText(activeItem) : "";',
'      if (!text) return;',
'      if (typeof navigator !== "undefined" && navigator.clipboard && navigator.clipboard.writeText) {',
'        await navigator.clipboard.writeText(text);',
'      }',
'    } catch {',
'      // ok',
'    }',
'  }',
'',
'  return (',
'    <div style={{ display: "flex", flexWrap: "wrap", gap: 12, alignItems: "stretch" }}>',
'      <aside style={{ flex: "0 1 360px", border: "1px solid rgba(255,255,255,0.12)", borderRadius: 14, padding: 14 }}>',
'        <div style={{ display: "flex", justifyContent: "space-between", gap: 10, alignItems: "baseline", flexWrap: "wrap" }}>',
'          <h2 style={{ margin: 0, fontSize: 14, fontWeight: 900, letterSpacing: "-0.01em" }}>Perguntas</h2>',
'          <div style={{ opacity: 0.65, fontSize: 12 }}>Debate V2 • {props.title}</div>',
'        </div>',
'',
'        <div style={{ marginTop: 10, display: "flex", gap: 8, alignItems: "center" }}>',
'          <input',
'            value={q}',
'            onChange={(e) => setQ(e.target.value)}',
'            placeholder="buscar pergunta ou tag..."',
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
'                <div style={{ fontWeight: 900, letterSpacing: "-0.01em" }}>{it.question}</div>',
'                <div style={{ marginTop: 6, opacity: 0.65, fontSize: 12, display: "flex", gap: 8, flexWrap: "wrap" }}>',
'                  <span>posicoes: <b>{it.positions.length}</b></span>',
'                  <span>provas: <b>{it.evidence.length}</b></span>',
'                  {it.tags.slice(0, 3).map((t) => (',
'                    <span key={t} style={{ border: "1px solid rgba(255,255,255,0.12)", borderRadius: 999, padding: "2px 7px" }}>{t}</span>',
'                  ))}',
'                </div>',
'              </button>',
'            );',
'          })}',
'        </div>',
'      </aside>',
'',
'      <section style={{ flex: "1 1 680px", border: "1px solid rgba(255,255,255,0.12)", borderRadius: 14, padding: 16 }}>',
'        {!activeItem ? (',
'          <p style={{ opacity: 0.75 }}>Sem itens de debate.</p>',
'        ) : (',
'          <div>',
'            <div style={{ opacity: 0.7, fontSize: 12, textTransform: "uppercase", letterSpacing: "0.08em" }}>Pergunta</div>',
'            <h1 style={{ marginTop: 8, fontSize: 22, fontWeight: 950, letterSpacing: "-0.03em" }}>{activeItem.question}</h1>',
'',
'            {activeItem.summary ? (',
'              <p style={{ marginTop: 10, opacity: 0.9, lineHeight: 1.6 }}>{activeItem.summary}</p>',
'            ) : null}',
'',
'            <div style={{ marginTop: 12, display: "flex", gap: 8, flexWrap: "wrap", alignItems: "center" }}>',
'              {activeItem.tags.map((t) => (',
'                <span key={t} style={{ border: "1px solid rgba(255,255,255,0.14)", borderRadius: 999, padding: "4px 8px", fontSize: 12, opacity: 0.9 }}>{t}</span>',
'              ))}',
'              <div style={{ marginLeft: "auto", display: "flex", gap: 8, flexWrap: "wrap" }}>',
'                <button onClick={copyActive} style={{',
'                  border: "1px solid rgba(255,255,255,0.18)",',
'                  background: "rgba(255,255,255,0.10)",',
'                  color: "rgba(255,255,255,0.92)",',
'                  borderRadius: 12, padding: "8px 10px", fontSize: 12, cursor: "pointer"',
'                }}>copiar sintese</button>',
'              </div>',
'            </div>',
'',
'            <div style={{ marginTop: 14, borderTop: "1px solid rgba(255,255,255,0.10)", paddingTop: 14 }}>',
'              <div style={{ opacity: 0.7, fontSize: 12, textTransform: "uppercase", letterSpacing: "0.08em" }}>Posicoes</div>',
'              <div style={{ marginTop: 10, display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(260px, 1fr))", gap: 10 }}>',
'                {activeItem.positions.map((p) => (',
'                  <article key={p.id} style={{ border: "1px solid rgba(255,255,255,0.14)", borderRadius: 14, padding: 12, background: "rgba(0,0,0,0.14)" }}>',
'                    <div style={{ display: "flex", justifyContent: "space-between", gap: 10, flexWrap: "wrap", alignItems: "baseline" }}>',
'                      <div style={{ fontWeight: 950, letterSpacing: "-0.01em" }}>{p.title}</div>',
'                      {p.stance ? <div style={{ opacity: 0.7, fontSize: 12 }}>{p.stance}</div> : null}',
'                    </div>',
'                    <ul style={{ marginTop: 10, paddingLeft: 18, opacity: 0.92, lineHeight: 1.55 }}>',
'                      {p.bullets.length ? p.bullets.map((b, idx) => <li key={p.id + "-" + idx}>{b}</li>) : <li>(sem pontos ainda)</li>}',
'                    </ul>',
'                  </article>',
'                ))}',
'              </div>',
'            </div>',
'',
'            <div style={{ marginTop: 14, borderTop: "1px solid rgba(255,255,255,0.10)", paddingTop: 14 }}>',
'              <div style={{ opacity: 0.7, fontSize: 12, textTransform: "uppercase", letterSpacing: "0.08em" }}>Provas</div>',
'              <div style={{ marginTop: 10, display: "flex", flexDirection: "column", gap: 8 }}>',
'                {activeItem.evidence.length ? activeItem.evidence.map((e) => (',
'                  <div key={e.id} style={{ border: "1px solid rgba(255,255,255,0.14)", borderRadius: 14, padding: 12, background: "rgba(0,0,0,0.14)" }}>',
'                    <div style={{ fontWeight: 900 }}>{e.title}</div>',
'                    {e.note ? <div style={{ marginTop: 6, opacity: 0.85, lineHeight: 1.5 }}>{e.note}</div> : null}',
'                    {e.url ? (',
'                      <div style={{ marginTop: 8 }}>',
'                        <a href={e.url} target="_blank" rel="noreferrer" style={{ textDecoration: "underline", opacity: 0.92 }}>{e.url}</a>',
'                      </div>',
'                    ) : null}',
'                  </div>',
'                )) : (',
'                  <div style={{ opacity: 0.75 }}>(sem provas ainda)</div>',
'                )}',
'              </div>',
'            </div>',
'          </div>',
'        )}',
'      </section>',
'    </div>',
'  );',
'}',
''
) -join "`n"

WriteUtf8NoBom $compPath $comp
Write-Host "[OK] wrote: DebateV2.tsx"
if ($bkC) { Write-Host ("[BK] " + $bkC) }

# -------------------------
# PATCH 2: Page server /c/[slug]/v2/debate
# -------------------------
EnsureDir (Split-Path -Parent $pagePath)
$bkP = BackupFile $pagePath

$page = @(
'import Link from "next/link";',
'import DebateV2 from "@/components/v2/DebateV2";',
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
'  let debate: unknown = { items: [] };',
'',
'  try {',
'    const c = await loadCadernoV2(slug);',
'    const cObj = isObj(c) ? c : null;',
'    const metaObj = cObj && isObj(cObj["meta"]) ? (cObj["meta"] as Record<string, unknown>) : null;',
'    title = asStr(metaObj ? metaObj["title"] : null) || slug;',
'    debate = cObj ? cObj["debate"] : debate;',
'  } catch {',
'    // ok',
'  }',
'',
'  return (',
'    <main style={{ padding: 24, maxWidth: 1240, margin: "0 auto" }}>',
'      <header style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", gap: 16, flexWrap: "wrap" }}>',
'        <div>',
'          <div style={{ opacity: 0.75, fontSize: 12, letterSpacing: "0.08em", textTransform: "uppercase" }}>Concreto Zen • V2</div>',
'          <h1 style={{ fontSize: 26, fontWeight: 900, letterSpacing: "-0.03em", marginTop: 6 }}>Debate</h1>',
'          <p style={{ marginTop: 6, opacity: 0.85 }}>{title}</p>',
'        </div>',
'        <nav style={{ display: "flex", gap: 12, flexWrap: "wrap" }}>',
'          <Link href={"/c/" + slug + "/v2"} style={{ textDecoration: "underline" }}>← Home V2</Link>',
'          <Link href={"/c/" + slug + "/v2/mapa"} style={{ textDecoration: "underline" }}>Mapa</Link>',
'          <Link href={"/c/" + slug + "/v2/provas"} style={{ textDecoration: "underline" }}>Provas</Link>',
'          <Link href={"/c/" + slug} style={{ textDecoration: "underline" }}>V1</Link>',
'        </nav>',
'      </header>',
'',
'      <section style={{ marginTop: 14 }}>',
'        <DebateV2 slug={slug} title={title} debate={debate} />',
'      </section>',
'',
'      <footer style={{ marginTop: 18, opacity: 0.6, fontSize: 12 }}>',
'        Proximo: Tijolo D4 (Provas V2: acervo, filtros, citacoes e export).',
'      </footer>',
'    </main>',
'  );',
'}',
''
) -join "`n"

WriteUtf8NoBom $pagePath $page
Write-Host "[OK] wrote: /c/[slug]/v2/debate (D3)"
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
$reportPath = Join-Path $reports "cv-v2-tijolo-d3-debate-v2-perguntas-posicoes-provas-v0_1.md"

$report = @(
  "# CV — V2 — Tijolo D3 (Debate V2)",
  "",
  "## Entrega",
  "- Debate V2 com lista de perguntas, painel de posicoes e secao de provas.",
  "- Busca por pergunta/tag e botao de copiar sintese (clipboard).",
  "- Sem any: apenas unknown + guards.",
  "",
  "## Arquivos",
  "- src/components/v2/DebateV2.tsx",
  "- src/app/c/[slug]/v2/debate/page.tsx",
  "",
  "## Verify",
  "- npm run lint",
  "- npm run build",
  ""
) -join "`n"

WriteUtf8NoBom $reportPath $report
Write-Host ("[OK] Report: " + $reportPath)
Write-Host "[OK] Tijolo D3 aplicado."