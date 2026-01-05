# CV — V2 Tijolo D3 — DebateV2 (hash focus + search + copy link) — v0_31
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

$repo = Resolve-Path (Join-Path $PSScriptRoot "..")
$bootstrap = Join-Path $PSScriptRoot "_bootstrap.ps1"
if (Test-Path -LiteralPath $bootstrap) { . $bootstrap } else { throw "[STOP] tools/_bootstrap.ps1 não encontrado." }

# fallbacks mínimos (se algo do bootstrap falhar)
if (-not (Get-Command EnsureDir -ErrorAction SilentlyContinue)) {
  function EnsureDir([string]$p) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}
if (-not (Get-Command WriteUtf8NoBom -ErrorAction SilentlyContinue)) {
  function WriteUtf8NoBom([string]$file,[string]$content) {
    EnsureDir (Split-Path -Parent $file)
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($file,$content,$enc)
  }
}
if (-not (Get-Command BackupFile -ErrorAction SilentlyContinue)) {
  function BackupFile([string]$file) {
    if (-not (Test-Path -LiteralPath $file)) { return $null }
    $bkDir = Join-Path $repo "tools\_patch_backup"
    EnsureDir $bkDir
    $stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
    $name = Split-Path -Leaf $file
    $bk = Join-Path $bkDir ($stamp + "-" + $name + ".bak")
    Copy-Item -LiteralPath $file -Destination $bk -Force
    return $bk
  }
}

Write-Host ("[DIAG] Repo: " + $repo)

$compPath = Join-Path $repo "src\components\v2\DebateV2.tsx"
$pagePath = Join-Path $repo "src\app\c\[slug]\v2\debate\page.tsx"

# -----------------------
# 1) COMPONENT: DebateV2
# -----------------------
$bk1 = BackupFile $compPath

$lines = @(
'"use client";',
'',
'import Link from "next/link";',
'import { useEffect, useMemo, useState } from "react";',
'',
'type DebateItem = {',
'  id: string;',
'  title?: string;',
'  author?: string;',
'  role?: string;',
'  date?: string;',
'  tags?: string[];',
'  text?: string;',
'};',
'',
'function isRecord(v: unknown): v is Record<string, unknown> {',
'  return typeof v === "object" && v !== null;',
'}',
'',
'function asString(v: unknown): string | undefined {',
'  return typeof v === "string" ? v : undefined;',
'}',
'',
'function asStringArray(v: unknown): string[] | undefined {',
'  if (!Array.isArray(v)) return undefined;',
'  const out: string[] = [];',
'  for (const x of v) {',
'    if (typeof x === "string") out.push(x);',
'  }',
'  return out.length ? out : undefined;',
'}',
'',
'function pickFirstString(obj: Record<string, unknown>, keys: string[]): string | undefined {',
'  for (const k of keys) {',
'    const s = asString(obj[k]);',
'    if (s && s.trim()) return s;',
'  }',
'  return undefined;',
'}',
'',
'function pickFirstArray(obj: Record<string, unknown>, keys: string[]): unknown[] | undefined {',
'  for (const k of keys) {',
'    const v = obj[k];',
'    if (Array.isArray(v)) return v as unknown[];',
'  }',
'  return undefined;',
'}',
'',
'function safeIdFrom(title: string, i: number): string {',
'  const base = title.toLowerCase().trim()',
'    .replace(/[^a-z0-9\\s_-]+/g, "")',
'    .replace(/\\s+/g, "-")',
'    .slice(0, 48);',
'  return (base ? base : "fala") + "-" + String(i + 1);',
'}',
'',
'function normalizeDebate(input: unknown): DebateItem[] {',
'  let arr: unknown[] | undefined;',
'',
'  if (Array.isArray(input)) {',
'    arr = input;',
'  } else if (isRecord(input)) {',
'    arr = pickFirstArray(input, ["items","list","debate","comments","mensagens","messages","falas","threads","entries"]);',
'    if (!arr) {',
'      const d = input["debate"];',
'      if (isRecord(d)) {',
'        arr = pickFirstArray(d, ["items","list","comments","messages","entries"]);',
'      }',
'    }',
'  }',
'',
'  if (!arr) return [];',
'',
'  const out: DebateItem[] = [];',
'  for (let i = 0; i < arr.length; i++) {',
'    const it = arr[i];',
'    if (typeof it === "string") {',
'      const text = it;',
'      out.push({ id: safeIdFrom(text, i), text });',
'      continue;',
'    }',
'    if (!isRecord(it)) continue;',
'',
'    const title = pickFirstString(it, ["title","titulo","name","nome","label"]);',
'    const text = pickFirstString(it, ["text","texto","body","conteudo","content","desc","descricao","description","note","nota"]);',
'    const author = pickFirstString(it, ["author","autor","by","pessoa","nomeAutor","nameAuthor"]);',
'    const role = pickFirstString(it, ["role","papel","tipoAutor","cargo"]);',
'    const date = pickFirstString(it, ["date","data","when"]);',
'    const tags = asStringArray(it["tags"]) ?? asStringArray(it["tag"]);',
'    const id = pickFirstString(it, ["id","slug","key"]) ?? safeIdFrom((title ?? text ?? "fala"), i);',
'',
'    out.push({ id, title, author, role, date, tags, text });',
'  }',
'  return out;',
'}',
'',
'function readHashId(): string {',
'  if (typeof window === "undefined") return "";',
'  const h = window.location.hash || "";',
'  return h.startsWith("#") ? h.slice(1) : h;',
'}',
'',
'export default function DebateV2(props: { slug: string; title: string; debate: unknown }) {',
'  const { slug, title, debate } = props;',
'  const items = useMemo(() => normalizeDebate(debate), [debate]);',
'  const [q, setQ] = useState<string>("");',
'  const [copied, setCopied] = useState<string>("");',
'  const [selectedId, setSelectedId] = useState<string>(() => (typeof window !== "undefined" ? readHashId() : ""));',
'',
'  useEffect(() => {',
'    const onHash = () => setSelectedId(readHashId());',
'    window.addEventListener("hashchange", onHash);',
'    return () => window.removeEventListener("hashchange", onHash);',
'  }, []);',
'',
'  useEffect(() => {',
'    if (!selectedId) return;',
'    const el = document.getElementById(selectedId);',
'    if (!el) return;',
'    el.scrollIntoView({ behavior: "smooth", block: "start" });',
'  }, [selectedId]);',
'',
'  const filtered = useMemo(() => {',
'    const qq = q.trim().toLowerCase();',
'    if (!qq) return items;',
'    return items.filter((it) => {',
'      const hay = (',
'        (it.title ?? "") + " " + (it.author ?? "") + " " + (it.role ?? "") + " " + (it.date ?? "") + " " + (it.text ?? "") + " " + (it.tags?.join(" ") ?? "")',
'      ).toLowerCase();',
'      return hay.includes(qq);',
'    });',
'  }, [items, q]);',
'',
'  async function copyLink(id: string) {',
'    try {',
'      const url = window.location.origin + "/c/" + slug + "/v2/debate#" + id;',
'      await navigator.clipboard.writeText(url);',
'      setCopied(id);',
'      setTimeout(() => setCopied(""), 1200);',
'    } catch {',
'      /* noop */',
'    }',
'  }',
'',
'  return (',
'    <section style={{ marginTop: 12 }}>',
'      <header style={{ display: "flex", justifyContent: "space-between", gap: 12, alignItems: "flex-end", flexWrap: "wrap" }}>',
'        <div>',
'          <h1 style={{ margin: 0, fontSize: 22, letterSpacing: 0.2 }}>Debate</h1>',
'          <div style={{ opacity: 0.75, marginTop: 2 }}>{title} • {items.length} fala(s)</div>',
'        </div>',
'        <nav style={{ display: "flex", gap: 10, flexWrap: "wrap", opacity: 0.9 }}>',
'          <Link href={"/c/" + slug + "/v2"} style={{ textDecoration: "underline" }}>V2 Home</Link>',
'          <Link href={"/c/" + slug + "/v2/mapa"} style={{ textDecoration: "underline" }}>Mapa</Link>',
'          <Link href={"/c/" + slug + "/v2/linha"} style={{ textDecoration: "underline" }}>Linha</Link>',
'          <Link href={"/c/" + slug + "/v2/provas"} style={{ textDecoration: "underline" }}>Provas</Link>',
'          <Link href={"/c/" + slug + "/v2/trilhas"} style={{ textDecoration: "underline" }}>Trilhas</Link>',
'        </nav>',
'      </header>',
'',
'      <div style={{ marginTop: 12, display: "flex", gap: 10, alignItems: "center", flexWrap: "wrap" }}>',
'        <input',
'          value={q}',
'          onChange={(e) => setQ(e.target.value)}',
'          placeholder="Buscar por autor, texto, tags..."',
'          style={{ flex: "1 1 260px", padding: 10, borderRadius: 10, border: "1px solid rgba(255,255,255,0.12)", background: "rgba(0,0,0,0.25)", color: "white" }}',
'        />',
'        <div style={{ opacity: 0.75 }}>{filtered.length} resultado(s)</div>',
'      </div>',
'',
'      <div style={{ marginTop: 12, display: "grid", gap: 10 }}>',
'        {filtered.map((it) => {',
'          const isSel = selectedId === it.id;',
'          return (',
'            <article',
'              key={it.id}',
'              id={it.id}',
'              style={{',
'                border: "1px solid rgba(255,255,255,0.10)",',
'                borderRadius: 12,',
'                padding: 12,',
'                background: isSel ? "rgba(255,255,255,0.06)" : "rgba(0,0,0,0.20)",',
'              }}',
'            >',
'              <div style={{ display: "flex", justifyContent: "space-between", gap: 10, alignItems: "flex-start", flexWrap: "wrap" }}>',
'                <div style={{ minWidth: 220 }}>',
'                  <a href={"#" + it.id} style={{ textDecoration: "underline", fontWeight: 700, color: "white" }}>',
'                    {it.title ?? (it.author ? it.author : "Fala")}',
'                  </a>',
'                  <div style={{ marginTop: 4, opacity: 0.75, fontSize: 13 }}>',
'                    {(it.author ? it.author + " • " : "")}{(it.role ? it.role + " • " : "")}{it.date ?? ""}',
'                  </div>',
'                </div>',
'',
'                <div style={{ display: "flex", gap: 10, alignItems: "center", flexWrap: "wrap" }}>',
'                  <button',
'                    type="button"',
'                    onClick={() => copyLink(it.id)}',
'                    style={{ padding: "8px 10px", borderRadius: 10, border: "1px solid rgba(255,255,255,0.18)", background: "rgba(0,0,0,0.25)", color: "white", cursor: "pointer" }}',
'                  >',
'                    {copied === it.id ? "Copiado!" : "Copiar link"}',
'                  </button>',
'                </div>',
'              </div>',
'',
'              {it.tags?.length ? (',
'                <div style={{ marginTop: 10, display: "flex", gap: 6, flexWrap: "wrap" }}>',
'                  {it.tags.map((t) => (',
'                    <span key={t} style={{ fontSize: 12, opacity: 0.85, padding: "3px 8px", borderRadius: 999, border: "1px solid rgba(255,255,255,0.12)" }}>',
'                      {t}',
'                    </span>',
'                  ))}',
'                </div>',
'              ) : null}',
'',
'              {it.text ? (',
'                <p style={{ marginTop: 10, marginBottom: 0, opacity: 0.9, lineHeight: 1.35, whiteSpace: "pre-wrap" }}>',
'                  {it.text}',
'                </p>',
'              ) : null}',
'            </article>',
'          );',
'        })}',
'',
'        {!filtered.length ? (',
'          <div style={{ opacity: 0.75, padding: 12, border: "1px dashed rgba(255,255,255,0.18)", borderRadius: 12 }}>',
'            Nada encontrado. Ajuste a busca ou alimente o debate do caderno.',
'          </div>',
'        ) : null}',
'      </div>',
'    </section>',
'  );',
'}'
)

EnsureDir (Split-Path -Parent $compPath)
$bk1 = BackupFile $compPath
WriteUtf8NoBom $compPath ($lines -join "`n")
Write-Host ("[OK] wrote: " + $compPath)
if ($bk1) { Write-Host ("[BK] " + $bk1) }

# -----------------------
# 2) PAGE: /v2/debate
# -----------------------
EnsureDir (Split-Path -Parent $pagePath)
$bk2 = BackupFile $pagePath

$page = @(
'import V2Nav from "@/components/v2/V2Nav";',
'import DebateV2 from "@/components/v2/DebateV2";',
'import { loadCadernoV2 } from "@/lib/v2";',
'',
'function titleFromMeta(meta: unknown, fallback: string): string {',
'  if (typeof meta !== "object" || meta === null) return fallback;',
'  const r = meta as { title?: unknown };',
'  return typeof r.title === "string" && r.title.trim() ? r.title : fallback;',
'}',
'',
'export default async function Page(props: { params: { slug: string } }) {',
'  const slug = props.params.slug;',
'  const c = await loadCadernoV2(slug);',
'',
'  const meta = (c as unknown as { meta?: unknown }).meta;',
'  const title = titleFromMeta(meta, slug);',
'',
'  const bag = c as unknown as { debate?: unknown; discussao?: unknown; forum?: unknown; comentarios?: unknown; comments?: unknown; mensagens?: unknown; messages?: unknown };',
'  const debate = bag.debate ?? bag.discussao ?? bag.forum ?? bag.comentarios ?? bag.comments ?? bag.mensagens ?? bag.messages ?? null;',
'',
'  return (',
'    <main style={{ padding: 18 }}>',
'      <V2Nav slug={slug} active="debate" />',
'      <DebateV2 slug={slug} title={title} debate={debate} />',
'    </main>',
'  );',
'}'
) -join "`n"

WriteUtf8NoBom $pagePath $page
Write-Host ("[OK] wrote: " + $pagePath)
if ($bk2) { Write-Host ("[BK] " + $bk2) }

# -----------------------
# 3) VERIFY
# -----------------------
RunPs1 (Join-Path $repo "tools\cv-verify.ps1")

# -----------------------
# 4) REPORT
# -----------------------
$report = @(
"# CV — V2 Tijolo D3 v0_31 — DebateV2 (hash focus)",
"",
"## O que entrou",
"- DebateV2 client resiliente (props unknown, normaliza array/obj).",
"- Foco por hash sem mutar window.location (scrollIntoView + hashchange).",
"- Busca local (autor/texto/tags).",
"- Copiar link com hash (#id) + feedback Copiado!.",
"- Links cruzados no header (V2 Home/Mapa/Linha/Provas/Trilhas).",
"",
"## Arquivos",
"- src/components/v2/DebateV2.tsx",
"- src/app/c/[slug]/v2/debate/page.tsx",
"",
"## Verify",
"- tools/cv-verify.ps1 (guard + lint + build)",
""
) -join "`n"

WriteReport "cv-v2-tijolo-d3-debate-v2-hashfocus-v0_31.md" $report | Out-Null
Write-Host "[OK] D3 v0_31 aplicado e verificado."