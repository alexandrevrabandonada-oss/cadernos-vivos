# CV — V2 Tijolo D4 — ProvasV2 (hash focus + search + copy link) — v0_30a
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

# Repo = pai de /tools
$repo = Resolve-Path (Join-Path $PSScriptRoot "..")
Write-Host ("[DIAG] Repo: " + $repo)

# tenta bootstrap
$bootstrap = Join-Path $PSScriptRoot "_bootstrap.ps1"
if (Test-Path -LiteralPath $bootstrap) {
  . $bootstrap
}

# fallbacks se o bootstrap não carregou
if (-not (Get-Command EnsureDir -ErrorAction SilentlyContinue)) {
  function EnsureDir([string]$p) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
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
if (-not (Get-Command WriteLinesUtf8NoBom -ErrorAction SilentlyContinue)) {
  function WriteLinesUtf8NoBom([string]$file, [string[]]$lines) {
    EnsureDir (Split-Path -Parent $file)
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($file, ($lines -join "`n"), $enc)
  }
}
if (-not (Get-Command WriteReport -ErrorAction SilentlyContinue)) {
  function WriteReport([string]$name, [string]$content) {
    $rdir = Join-Path $repo "reports"
    EnsureDir $rdir
    $full = Join-Path $rdir $name
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($full, $content, $enc)
    return $full
  }
}
if (-not (Get-Command RunPs1 -ErrorAction SilentlyContinue)) {
  function RunPs1([string]$file) {
    $pwsh = (Get-Command pwsh).Source
    & $pwsh -NoProfile -ExecutionPolicy Bypass -File $file
    if ($LASTEXITCODE -ne 0) { throw ("[STOP] falhou: " + $file + " (exit " + $LASTEXITCODE + ")") }
  }
}

# paths
$compPath = Join-Path $repo "src\components\v2\ProvasV2.tsx"
$pagePath = Join-Path $repo "src\app\c\[slug]\v2\provas\page.tsx"
$navPath  = Join-Path $repo "src\components\v2\V2Nav.tsx"

# -----------------------
# PATCH: V2Nav aceitar active como string (pra active="provas" não quebrar TS)
# -----------------------
if (Test-Path -LiteralPath $navPath) {
  $rawNav = Get-Content -LiteralPath $navPath -Raw
  $newNav = $rawNav

  if ($newNav.Contains("active?: Active")) { $newNav = $newNav.Replace("active?: Active", "active?: string") }
  if ($newNav.Contains("active: Active"))  { $newNav = $newNav.Replace("active: Active",  "active: string") }

  if ($newNav -ne $rawNav) {
    $bk = BackupFile $navPath
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($navPath, $newNav, $enc)
    Write-Host "[OK] patched: V2Nav.tsx (active -> string)"
    if ($bk) { Write-Host ("[BK] " + $bk) }
  } else {
    Write-Host "[OK] V2Nav.tsx: sem mudanças (já ok)."
  }
} else {
  Write-Host "[SKIP] Não achei V2Nav.tsx — seguindo."
}

# -----------------------
# 1) COMPONENT: ProvasV2
# -----------------------
$bk1 = BackupFile $compPath

$compLines = @(
'"use client";',
'',
'import Link from "next/link";',
'import { useEffect, useMemo, useState } from "react";',
'',
'type ProofItem = {',
'  id: string;',
'  title: string;',
'  kind?: string;',
'  url?: string;',
'  source?: string;',
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
'    const v = obj[k];',
'    const s = asString(v);',
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
'  return (base ? base : "prova") + "-" + String(i + 1);',
'}',
'',
'function normalizeProofs(input: unknown): ProofItem[] {',
'  let arr: unknown[] | undefined;',
'',
'  if (Array.isArray(input)) {',
'    arr = input;',
'  } else if (isRecord(input)) {',
'    arr = pickFirstArray(input, ["items","list","provas","evidencias","acervo","docs","links","entries","records"]);',
'    if (!arr) {',
'      const ac = input["acervo"];',
'      if (isRecord(ac)) {',
'        arr = pickFirstArray(ac, ["items","list","docs","links","entries"]);',
'      }',
'    }',
'  }',
'',
'  if (!arr) return [];',
'',
'  const out: ProofItem[] = [];',
'  for (let i = 0; i < arr.length; i++) {',
'    const it = arr[i];',
'',
'    if (typeof it === "string") {',
'      const title = it;',
'      out.push({ id: safeIdFrom(title, i), title, url: it });',
'      continue;',
'    }',
'',
'    if (!isRecord(it)) continue;',
'',
'    const title = pickFirstString(it, ["title","titulo","name","nome","label"]) ?? ("Prova " + String(i + 1));',
'    const id = pickFirstString(it, ["id","slug","key"]) ?? safeIdFrom(title, i);',
'    const url = pickFirstString(it, ["url","href","link"]);',
'    const kind = pickFirstString(it, ["kind","type","tipo","categoria"]);',
'    const source = pickFirstString(it, ["source","fonte","origem"]);',
'    const date = pickFirstString(it, ["date","data"]);',
'    const text = pickFirstString(it, ["text","texto","desc","descricao","description","notes","nota"]);',
'    const tags = asStringArray(it["tags"]) ?? asStringArray(it["tag"]);',
'',
'    out.push({ id, title, url, kind, source, date, tags, text });',
'  }',
'',
'  return out;',
'}',
'',
'function readHashId(): string {',
'  if (typeof window === "undefined") return "";',
'  const h = window.location.hash || "";',
'  return h.startsWith("#") ? h.slice(1) : h;',
'}',
'',
'export default function ProvasV2(props: { slug: string; title: string; provas: unknown }) {',
'  const { slug, title, provas } = props;',
'',
'  const items = useMemo(() => normalizeProofs(provas), [provas]);',
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
'        it.title + " " + (it.kind ?? "") + " " + (it.source ?? "") + " " + (it.date ?? "") + " " + (it.text ?? "") + " " + (it.tags?.join(" ") ?? "")',
'      ).toLowerCase();',
'      return hay.includes(qq);',
'    });',
'  }, [items, q]);',
'',
'  async function copyLink(id: string) {',
'    try {',
'      const url = window.location.origin + "/c/" + slug + "/v2/provas#" + id;',
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
'          <h1 style={{ margin: 0, fontSize: 22, letterSpacing: 0.2 }}>Provas</h1>',
'          <div style={{ opacity: 0.75, marginTop: 2 }}>{title} • {items.length} item(ns)</div>',
'        </div>',
'        <nav style={{ display: "flex", gap: 10, flexWrap: "wrap", opacity: 0.9 }}>',
'          <Link href={"/c/" + slug + "/v2"} style={{ textDecoration: "underline" }}>V2 Home</Link>',
'          <Link href={"/c/" + slug + "/v2/mapa"} style={{ textDecoration: "underline" }}>Mapa</Link>',
'          <Link href={"/c/" + slug + "/v2/linha"} style={{ textDecoration: "underline" }}>Linha</Link>',
'          <Link href={"/c/" + slug + "/v2/debate"} style={{ textDecoration: "underline" }}>Debate</Link>',
'          <Link href={"/c/" + slug + "/v2/trilhas"} style={{ textDecoration: "underline" }}>Trilhas</Link>',
'        </nav>',
'      </header>',
'',
'      <div style={{ marginTop: 12, display: "flex", gap: 10, alignItems: "center", flexWrap: "wrap" }}>',
'        <input',
'          value={q}',
'          onChange={(e) => setQ(e.target.value)}',
'          placeholder="Buscar por título, texto, tags, fonte..."',
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
'                    {it.title}',
'                  </a>',
'                  <div style={{ marginTop: 4, opacity: 0.75, fontSize: 13 }}>',
'                    {(it.kind ? it.kind + " • " : "")}{(it.source ? it.source + " • " : "")}{it.date ?? ""}',
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
'                  {it.url ? (',
'                    <a href={it.url} target="_blank" rel="noreferrer" style={{ textDecoration: "underline", opacity: 0.9 }}>',
'                      Abrir',
'                    </a>',
'                  ) : null}',
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
'                <p style={{ marginTop: 10, marginBottom: 0, opacity: 0.9, lineHeight: 1.35 }}>',
'                  {it.text}',
'                </p>',
'              ) : null}',
'            </article>',
'          );',
'        })}',
'',
'        {!filtered.length ? (',
'          <div style={{ opacity: 0.75, padding: 12, border: "1px dashed rgba(255,255,255,0.18)", borderRadius: 12 }}>',
'            Nada encontrado. Ajuste a busca ou alimente o acervo do caderno.',
'          </div>',
'        ) : null}',
'      </div>',
'    </section>',
'  );',
'}'
)

# IMPORTANT: corrige \s no regex (linhas acima têm \\s porque o TS precisa de \s)
# (no arquivo final, isso vira \s corretamente)

WriteLinesUtf8NoBom $compPath $compLines
Write-Host ("[OK] wrote: " + $compPath)
if ($bk1) { Write-Host ("[BK] " + $bk1) }

# -----------------------
# 2) PAGE: /v2/provas
# -----------------------
$bk2 = BackupFile $pagePath

$pageLines = @(
'import V2Nav from "@/components/v2/V2Nav";',
'import ProvasV2 from "@/components/v2/ProvasV2";',
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
'  const bag = c as unknown as { provas?: unknown; acervo?: unknown; evidencias?: unknown; docs?: unknown; links?: unknown };',
'  const provas = bag.provas ?? bag.evidencias ?? bag.acervo ?? bag.docs ?? bag.links ?? null;',
'',
'  return (',
'    <main style={{ padding: 18 }}>',
'      <V2Nav slug={slug} active="provas" />',
'      <ProvasV2 slug={slug} title={title} provas={provas} />',
'    </main>',
'  );',
'}'
)

WriteLinesUtf8NoBom $pagePath $pageLines
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
"# CV — V2 Tijolo D4 v0_30a — ProvasV2 (hash focus)",
"",
"## O que entrou",
"- ProvasV2 client resiliente (props unknown, normaliza array/obj).",
"- Foco por hash sem mutar window.location (scrollIntoView + hashchange).",
"- Busca local (título, texto, tags, fonte).",
"- Copiar link com hash (#id) + feedback Copiado!.",
"- (Compat) V2Nav: active agora aceita string (pra active=provas não quebrar build).",
"",
"## Arquivos",
"- src/components/v2/ProvasV2.tsx",
"- src/app/c/[slug]/v2/provas/page.tsx",
"",
"## Verify",
"- tools/cv-verify.ps1 (guard + lint + build)",
""
) -join "`n"

$rf = WriteReport "cv-v2-tijolo-d4-provas-v2-hashfocus-v0_30a.md" $report
Write-Host ("[OK] report: " + $rf)
Write-Host "[OK] D4 v0_30a aplicado e verificado."