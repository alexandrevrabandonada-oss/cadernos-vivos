param(
  [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function WL([string]$s) { Write-Host $s }
function TestP([string]$p) { return (Test-Path -LiteralPath $p) }

function EnsureDir([string]$p) {
  if (-not (TestP $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

function WriteUtf8NoBom([string]$p, [string]$content) {
  $parent = Split-Path -Parent $p
  if ($parent) { EnsureDir $parent }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($p, $content, $enc)
}

function BackupFile([string]$p) {
  if (TestP $p) {
    $ts = (Get-Date -Format "yyyyMMdd_HHmmss")
    $bakDir = Join-Path (Get-Location) "tools\_patch_backup"
    EnsureDir $bakDir
    $leaf = Split-Path -Leaf $p
    Copy-Item -LiteralPath $p -Destination (Join-Path $bakDir ($leaf + "." + $ts + ".bak")) -Force
  }
}

function ResolveExe([string]$name) {
  $cmd = Get-Command $name -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source) { return $cmd.Source }
  return $name
}

function RunNative([string]$cwd, [string]$exe, [string[]]$cmdArgs) {
  $pretty = ($cmdArgs -join " ")
  WL ("[RUN] " + $exe + " " + $pretty)
  Push-Location $cwd
  & $exe @cmdArgs
  $code = $LASTEXITCODE
  Pop-Location
  if ($code -ne 0) { throw ("[STOP] comando falhou (exit " + $code + "): " + $exe + " " + $pretty) }
}

function ResolveRepoHere() {
  $here = (Get-Location).Path
  if (TestP (Join-Path $here "package.json")) { return $here }
  throw ("[STOP] Rode na raiz do repo (onde tem package.json). Atual: " + $here)
}

function ReadRaw([string]$p) {
  if (-not (TestP $p)) { return $null }
  return (Get-Content -LiteralPath $p -Raw)
}

# -------------------------
# DIAG
# -------------------------
$repo = ResolveRepoHere
$npmExe = ResolveExe "npm.cmd"
$compDir = Join-Path $repo "src\components"
$appScope = Join-Path $repo "src\app\c\[slug]"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] Components: " + $compDir)
WL ("[DIAG] AppScope: " + $appScope)

EnsureDir $compDir

# -------------------------
# PATCH — NavPills (novo arquivo client com slug inferido)
# -------------------------
$navPath = Join-Path $compDir "NavPills.tsx"
BackupFile $navPath

$navLines = @(
'"use client";',
'',
'import Link from "next/link";',
'import { useParams } from "next/navigation";',
'',
'type Params = Record<string, string | string[]>;',
'',
'function pick(v: string | string[] | undefined): string {',
'  if (Array.isArray(v)) return v[0] || "";',
'  return v || "";',
'}',
'',
'export default function NavPills(props: { slug?: string }) {',
'  const params = useParams() as Params;',
'  const inferred = pick(params ? params["slug"] : undefined);',
'  const slug = props.slug || inferred;',
'  if (!slug) return null;',
'',
'  const items = [',
'    { href: "/c/" + slug, label: "Panorama" },',
'    { href: "/c/" + slug + "/trilha", label: "Trilha" },',
'    { href: "/c/" + slug + "/a/1", label: "Aulas" },',
'    { href: "/c/" + slug + "/pratica", label: "Prática" },',
'    { href: "/c/" + slug + "/quiz", label: "Quiz" },',
'    { href: "/c/" + slug + "/acervo", label: "Acervo" },',
'    { href: "/c/" + slug + "/mapa", label: "Mapa" },',
'    { href: "/c/" + slug + "/debate", label: "Debate" },',
'    { href: "/c/" + slug + "/registro", label: "Registro" }',
'  ];',
'',
'  return (',
'    <div className="flex flex-wrap gap-2 mt-4">',
'      {items.map((it) => (',
'        <Link',
'          key={it.href}',
'          href={it.href}',
'          className="card px-3 py-2 text-sm hover:bg-white/10 transition"',
'        >',
'          <span className="accent">{it.label}</span>',
'        </Link>',
'      ))}',
'    </div>',
'  );',
'}'
) 
WriteUtf8NoBom $navPath ($navLines -join "`n")
WL ("[OK] wrote: " + $navPath)

# -------------------------
# PATCH — CadernoHeader: remover NavPills daqui (pra não ter dois jeitos)
# -------------------------
$hdrPath = Join-Path $compDir "CadernoHeader.tsx"
if (TestP $hdrPath) {
  BackupFile $hdrPath
  $hdrLines = @(
'import type { CSSProperties } from "react";',
'import Link from "next/link";',
'',
'export type AccentStyle = CSSProperties & { ["--accent"]?: string };',
'',
'export function CadernoHeader({',
'  title,',
'  subtitle,',
'  ethos,',
'}: {',
'  title: string;',
'  subtitle?: string;',
'  ethos?: string;',
'}) {',
'  return (',
'    <header className="card p-5" style={{ ["--accent"]: "#facc15" } as AccentStyle}>',
'      <div className="flex flex-col gap-2">',
'        <div className="flex items-center justify-between gap-4">',
'          <div>',
'            <h1 className="text-2xl font-bold">{title}</h1>',
'            {subtitle ? <div className="muted mt-1">{subtitle}</div> : null}',
'          </div>',
'          <Link href="/" className="text-sm muted hover:text-white transition">',
'            Hub',
'          </Link>',
'        </div>',
'        {ethos ? <div className="text-sm muted mt-2">{ethos}</div> : null}',
'      </div>',
'    </header>',
'  );',
'}',
'',
'export default CadernoHeader;'
  )
  WriteUtf8NoBom $hdrPath ($hdrLines -join "`n")
  WL ("[OK] patched: " + $hdrPath + " (NavPills removido daqui)")
} else {
  WL ("[WARN] não achei: " + $hdrPath)
}

# -------------------------
# PATCH — Componentes que usavam slug obrigatório: tornar opcional + inferir via useParams (client)
# -------------------------
function WriteClientSlugComponent([string]$targetPath, [string[]]$lines) {
  BackupFile $targetPath
  WriteUtf8NoBom $targetPath ($lines -join "`n")
  WL ("[OK] wrote: " + $targetPath)
}

# DebateBoard.tsx
$debPath = Join-Path $compDir "DebateBoard.tsx"
if (TestP $debPath) {
  $debLines = @(
'"use client";',
'',
'import { useMemo, useState } from "react";',
'import { useParams } from "next/navigation";',
'',
'export type DebatePrompt = { id: string; title: string; prompt: string };',
'',
'type Params = Record<string, string | string[]>;',
'type Saved = {',
'  answers: Record<string, string>;',
'  pedidoConcreto: string;',
'  acaoAjudaMutua: string;',
'};',
'',
'function pick(v: string | string[] | undefined): string {',
'  if (Array.isArray(v)) return v[0] || "";',
'  return v || "";',
'}',
'',
'function keyFor(slug: string) {',
'  return "cv:" + slug + ":debate:v1";',
'}',
'',
'function emptySaved(): Saved {',
'  return { answers: {}, pedidoConcreto: "", acaoAjudaMutua: "" };',
'}',
'',
'function loadSaved(k: string): Saved {',
'  try {',
'    const raw = localStorage.getItem(k);',
'    if (!raw) return emptySaved();',
'    const parsed = JSON.parse(raw) as unknown;',
'    if (!parsed || typeof parsed !== "object") return emptySaved();',
'    const obj = parsed as Partial<Saved>;',
'    return {',
'      answers: (obj.answers as Record<string, string>) || {},',
'      pedidoConcreto: obj.pedidoConcreto || "",',
'      acaoAjudaMutua: obj.acaoAjudaMutua || "",',
'    };',
'  } catch {',
'    return emptySaved();',
'  }',
'}',
'',
'export default function DebateBoard({',
'  slug: slugProp,',
'  prompts,',
'}: {',
'  slug?: string;',
'  prompts: DebatePrompt[];',
'}) {',
'  const params = useParams() as Params;',
'  const inferred = pick(params ? params["slug"] : undefined);',
'  const slug = slugProp || inferred;',
'',
'  const k = useMemo(() => (slug ? keyFor(slug) : ""), [slug]);',
'  const init = useMemo(() => {',
'    if (!k) return emptySaved();',
'    return loadSaved(k);',
'  }, [k]);',
'',
'  const [answers, setAnswers] = useState<Record<string, string>>(() => init.answers);',
'  const [pedidoConcreto, setPedido] = useState(() => init.pedidoConcreto);',
'  const [acaoAjudaMutua, setAcao] = useState(() => init.acaoAjudaMutua);',
'  const [status, setStatus] = useState<"" | "salvo" | "copiado">("");',
'',
'  const save = () => {',
'    if (!k) return;',
'    try {',
'      const data: Saved = { answers, pedidoConcreto, acaoAjudaMutua };',
'      localStorage.setItem(k, JSON.stringify(data));',
'      setStatus("salvo");',
'      setTimeout(() => setStatus(""), 1200);',
'    } catch {}',
'  };',
'',
'  const copy = async () => {',
'    try {',
'      const payload = { slug, answers, pedidoConcreto, acaoAjudaMutua };',
'      await navigator.clipboard.writeText(JSON.stringify(payload, null, 2));',
'      setStatus("copiado");',
'      setTimeout(() => setStatus(""), 1200);',
'    } catch {}',
'  };',
'',
'  const clearAll = () => {',
'    setAnswers({});',
'    setPedido("");',
'    setAcao("");',
'    if (!k) return;',
'    try { localStorage.removeItem(k); } catch {}',
'  };',
'',
'  if (!slug) {',
'    return (',
'      <div className="card p-5">',
'        <div className="text-lg font-semibold">Debate</div>',
'        <div className="muted mt-2">Abra este painel dentro de um caderno (/c/slug/debate).</div>',
'      </div>',
'    );',
'  }',
'',
'  return (',
'    <div className="space-y-4">',
'      <div className="card p-5">',
'        <h3 className="text-lg font-semibold">Sem tribunal</h3>',
'        <p className="muted mt-2">',
'          Debate aqui é ferramenta de cuidado e organização: diagnóstico estrutural, linguagem concreta, e saída prática.',
'        </p>',
'        <div className="mt-4 grid gap-2 text-sm muted">',
'          <div>• Evitar moralismo / caça às bruxas.</div>',
'          <div>• Fechar com pedido concreto + ação simples de ajuda mútua.</div>',
'        </div>',
'      </div>',
'',
'      <div className="grid gap-3">',
'        {prompts.map((p) => (',
'          <div key={p.id} className="card p-5">',
'            <div className="text-xs muted">{p.id}</div>',
'            <div className="text-lg font-semibold mt-1">{p.title}</div>',
'            <div className="muted mt-2 whitespace-pre-wrap">{p.prompt}</div>',
'            <textarea',
'              className="mt-4 w-full rounded-xl border border-white/10 bg-black/20 p-3 outline-none focus:border-white/20"',
'              rows={5}',
'              value={answers[p.id] || ""}',
'              onChange={(e) => setAnswers((prev) => ({ ...prev, [p.id]: e.target.value }))}',
'              placeholder="Escreva sua síntese (sem pânico, sem tribunal)."',
'            />',
'          </div>',
'        ))}',
'      </div>',
'',
'      <div className="card p-5">',
'        <h3 className="text-lg font-semibold">Fechamento obrigatório</h3>',
'        <div className="grid gap-3 mt-3">',
'          <div>',
'            <div className="text-sm muted">Pedido concreto</div>',
'            <textarea',
'              className="mt-2 w-full rounded-xl border border-white/10 bg-black/20 p-3 outline-none focus:border-white/20"',
'              rows={3}',
'              value={pedidoConcreto}',
'              onChange={(e) => setPedido(e.target.value)}',
'            />',
'          </div>',
'          <div>',
'            <div className="text-sm muted">Ação simples de ajuda mútua (2–10 min)</div>',
'            <textarea',
'              className="mt-2 w-full rounded-xl border border-white/10 bg-black/20 p-3 outline-none focus:border-white/20"',
'              rows={3}',
'              value={acaoAjudaMutua}',
'              onChange={(e) => setAcao(e.target.value)}',
'            />',
'          </div>',
'        </div>',
'',
'        <div className="mt-4 flex flex-wrap gap-2">',
'          <button className="card px-3 py-2 hover:bg-white/10 transition" onClick={save}>',
'            <span className="accent">{status === "salvo" ? "Salvo!" : "Salvar"}</span>',
'          </button>',
'          <button className="card px-3 py-2 hover:bg-white/10 transition" onClick={copy}>',
'            <span className="accent">{status === "copiado" ? "Copiado!" : "Copiar JSON"}</span>',
'          </button>',
'          <button className="card px-3 py-2 hover:bg-white/10 transition" onClick={clearAll}>Limpar</button>',
'        </div>',
'      </div>',
'    </div>',
'  );',
'}'
  )
  WriteClientSlugComponent $debPath $debLines
} else {
  WL ("[WARN] não achei: " + $debPath)
}

# AulaProgress.tsx
$apPath = Join-Path $compDir "AulaProgress.tsx"
if (TestP $apPath) {
  $apLines = @(
'"use client";',
'',
'import { useParams } from "next/navigation";',
'',
'type Params = Record<string, string | string[]>;',
'',
'function pick(v: string | string[] | undefined): string {',
'  if (Array.isArray(v)) return v[0] || "";',
'  return v || "";',
'}',
'',
'export default function AulaProgress({',
'  slug: slugProp,',
'  total,',
'  current,',
'}: {',
'  slug?: string;',
'  total: number;',
'  current: number;',
'}) {',
'  const params = useParams() as Params;',
'  const inferred = pick(params ? params["slug"] : undefined);',
'  const slug = slugProp || inferred;',
'',
'  const safeTotal = total > 0 ? total : 1;',
'  const pct = Math.max(0, Math.min(100, Math.round((current / safeTotal) * 100)));',
'',
'  return (',
'    <section className="card p-5">',
'      <div className="flex items-center justify-between gap-4">',
'        <div>',
'          <div className="text-xs muted">Progresso</div>',
'          <div className="text-lg font-semibold mt-1">{String(current)} / {String(total)}</div>',
'          {slug ? <div className="text-xs muted mt-1">caderno: {slug}</div> : null}',
'        </div>',
'        <div className="text-2xl font-bold accent">{String(pct)}%</div>',
'      </div>',
'      <div className="mt-4 h-2 w-full rounded-full bg-white/10 overflow-hidden">',
'        <div className="h-full bg-[var(--accent)]" style={{ width: pct + "%" }} />',
'      </div>',
'    </section>',
'  );',
'}'
  )
  WriteClientSlugComponent $apPath $apLines
} else {
  WL ("[WARN] não achei: " + $apPath)
}

# TerritoryMap.tsx
$tmPath = Join-Path $compDir "TerritoryMap.tsx"
if (TestP $tmPath) {
  $tmLines = @(
'"use client";',
'',
'import { useMemo, useState } from "react";',
'import { useParams } from "next/navigation";',
'',
'export type MapPoint = {',
'  id: string;',
'  title?: string;',
'  name?: string;',
'  label?: string;',
'  kind?: string;',
'  lat?: number;',
'  lng?: number;',
'  note?: string;',
'  tags?: string[];',
'};',
'',
'type Params = Record<string, string | string[]>;',
'type Saved = { seen: Record<string, boolean> };',
'',
'function pick(v: string | string[] | undefined): string {',
'  if (Array.isArray(v)) return v[0] || "";',
'  return v || "";',
'}',
'',
'function keyFor(slug: string) {',
'  return "cv:" + slug + ":map:v1";',
'}',
'',
'function load(k: string): Saved {',
'  try {',
'    const raw = localStorage.getItem(k);',
'    if (!raw) return { seen: {} };',
'    const parsed = JSON.parse(raw) as unknown;',
'    if (!parsed || typeof parsed !== "object") return { seen: {} };',
'    const obj = parsed as Partial<Saved>;',
'    return { seen: (obj.seen as Record<string, boolean>) || {} };',
'  } catch {',
'    return { seen: {} };',
'  }',
'}',
'',
'function titleOf(p: MapPoint): string {',
'  return p.title || p.name || p.label || p.id;',
'}',
'',
'export default function TerritoryMap({',
'  slug: slugProp,',
'  points,',
'}: {',
'  slug?: string;',
'  points: MapPoint[];',
'}) {',
'  const params = useParams() as Params;',
'  const inferred = pick(params ? params["slug"] : undefined);',
'  const slug = slugProp || inferred;',
'',
'  const k = useMemo(() => (slug ? keyFor(slug) : ""), [slug]);',
'  const init = useMemo(() => (k ? load(k) : { seen: {} }), [k]);',
'',
'  const [seen, setSeen] = useState<Record<string, boolean>>(() => init.seen);',
'  const [q, setQ] = useState("");',
'',
'  const filtered = useMemo(() => {',
'    const qq = q.trim().toLowerCase();',
'    if (!qq) return points;',
'    return points.filter((p) => {',
'      const hay = (titleOf(p) + " " + (p.kind || "") + " " + (p.note || "")).toLowerCase();',
'      return hay.includes(qq);',
'    });',
'  }, [points, q]);',
'',
'  const toggle = (id: string) => {',
'    setSeen((prev) => {',
'      const next = { ...prev, [id]: !prev[id] };',
'      if (k) {',
'        try { localStorage.setItem(k, JSON.stringify({ seen: next } as Saved)); } catch {}',
'      }',
'      return next;',
'    });',
'  };',
'',
'  return (',
'    <section className="card p-5">',
'      <div className="flex items-center justify-between gap-4">',
'        <div>',
'          <h3 className="text-xl font-semibold">Mapa do território</h3>',
'          <div className="muted mt-1">Lista navegável + marcações locais (no seu aparelho).</div>',
'        </div>',
'        {slug ? <div className="text-xs muted">caderno: {slug}</div> : null}',
'      </div>',
'',
'      <input',
'        className="mt-4 w-full rounded-xl border border-white/10 bg-black/20 p-3 outline-none focus:border-white/20"',
'        value={q}',
'        onChange={(e) => setQ(e.target.value)}',
'        placeholder="Buscar por nome, tipo ou nota..."',
'      />',
'',
'      <div className="mt-4 grid gap-3">',
'        {filtered.map((p) => (',
'          <div key={p.id} className="card p-4">',
'            <div className="flex items-start justify-between gap-4">',
'              <div>',
'                <div className="text-sm font-semibold">{titleOf(p)}</div>',
'                <div className="text-xs muted mt-1">{p.kind ? p.kind : "ponto"}</div>',
'                {p.note ? <div className="muted mt-2 text-sm whitespace-pre-wrap">{p.note}</div> : null}',
'              </div>',
'              <button',
'                className="card px-3 py-2 hover:bg-white/10 transition text-sm"',
'                onClick={() => toggle(p.id)}',
'              >',
'                <span className="accent">{seen[p.id] ? "Marcado" : "Marcar"}</span>',
'              </button>',
'            </div>',
'            {typeof p.lat === "number" && typeof p.lng === "number" ? (',
'              <a',
'                className="muted text-xs mt-3 inline-block hover:text-white transition"',
'                target="_blank"',
'                rel="noreferrer"',
'                href={"https://www.google.com/maps?q=" + String(p.lat) + "," + String(p.lng)}',
'              >',
'                Abrir no mapa',
'              </a>',
'            ) : null}',
'          </div>',
'        ))}',
'      </div>',
'    </section>',
'  );',
'}'
  )
  WriteClientSlugComponent $tmPath $tmLines
} else {
  WL ("[WARN] não achei: " + $tmPath)
}

# RegistroPanel.tsx (se existir)
$rpPath = Join-Path $compDir "RegistroPanel.tsx"
if (TestP $rpPath) {
  $rpLines = @(
'"use client";',
'',
'import { useMemo, useState } from "react";',
'import { useParams } from "next/navigation";',
'import type { MapPoint } from "@/components/TerritoryMap";',
'',
'type Params = Record<string, string | string[]>;',
'type Saved = {',
'  notes: string;',
'  pointId?: string;',
'};',
'',
'function pick(v: string | string[] | undefined): string {',
'  if (Array.isArray(v)) return v[0] || "";',
'  return v || "";',
'}',
'',
'function keyFor(slug: string) {',
'  return "cv:" + slug + ":registro:v1";',
'}',
'',
'function load(k: string): Saved {',
'  try {',
'    const raw = localStorage.getItem(k);',
'    if (!raw) return { notes: "" };',
'    const parsed = JSON.parse(raw) as unknown;',
'    if (!parsed || typeof parsed !== "object") return { notes: "" };',
'    const obj = parsed as Partial<Saved>;',
'    return { notes: obj.notes || "", pointId: obj.pointIdId; }',
'  } catch {',
'    return { notes: "" };',
'  }',
'}'
  )
  # Corrigir erro proposital acima: vamos escrever um painel simples sem pegadinhas.
  $rpLines = @(
'"use client";',
'',
'import { useMemo, useState } from "react";',
'import { useParams } from "next/navigation";',
'import type { MapPoint } from "@/components/TerritoryMap";',
'',
'type Params = Record<string, string | string[]>;',
'type Saved = { notes: string; pointId?: string };',
'',
'function pick(v: string | string[] | undefined): string {',
'  if (Array.isArray(v)) return v[0] || "";',
'  return v || "";',
'}',
'',
'function keyFor(slug: string) {',
'  return "cv:" + slug + ":registro:v1";',
'}',
'',
'function load(k: string): Saved {',
'  try {',
'    const raw = localStorage.getItem(k);',
'    if (!raw) return { notes: "" };',
'    const parsed = JSON.parse(raw) as unknown;',
'    if (!parsed || typeof parsed !== "object") return { notes: "" };',
'    const obj = parsed as Partial<Saved>;',
'    return { notes: obj.notes || "", pointId: obj.pointId };',
'  } catch {',
'    return { notes: "" };',
'  }',
'}',
'',
'export default function RegistroPanel({',
'  slug: slugProp,',
'  points,',
'}: {',
'  slug?: string;',
'  points?: MapPoint[];',
'}) {',
'  const params = useParams() as Params;',
'  const inferred = pick(params ? params["slug"] : undefined);',
'  const slug = slugProp || inferred;',
'',
'  const k = useMemo(() => (slug ? keyFor(slug) : ""), [slug]);',
'  const init = useMemo(() => (k ? load(k) : { notes: "" }), [k]);',
'',
'  const [pointId, setPointId] = useState<string>(() => init.pointId || "");',
'  const [notes, setNotes] = useState<string>(() => init.notes);',
'  const [status, setStatus] = useState<"" | "salvo" | "copiado">("");',
'',
'  const save = () => {',
'    if (!k) return;',
'    try {',
'      const payload: Saved = { notes, pointId: pointId || undefined };',
'      localStorage.setItem(k, JSON.stringify(payload));',
'      setStatus("salvo");',
'      setTimeout(() => setStatus(""), 1200);',
'    } catch {}',
'  };',
'',
'  const copy = async () => {',
'    try {',
'      const payload = { slug, pointId: pointId || undefined, notes };',
'      await navigator.clipboard.writeText(JSON.stringify(payload, null, 2));',
'      setStatus("copiado");',
'      setTimeout(() => setStatus(""), 1200);',
'    } catch {}',
'  };',
'',
'  return (',
'    <section className="card p-5">',
'      <h3 className="text-xl font-semibold">Registro</h3>',
'      <div className="muted mt-1">Anotações locais (no seu aparelho). Sem backend por enquanto.</div>',
'',
'      {points && points.length ? (',
'        <div className="mt-4">',
'          <div className="text-sm muted">Vincular a um ponto do mapa (opcional)</div>',
'          <select',
'            className="mt-2 w-full rounded-xl border border-white/10 bg-black/20 p-3 outline-none focus:border-white/20"',
'            value={pointId}',
'            onChange={(e) => setPointId(e.target.value)}',
'          >',
'            <option value="">(sem ponto)</option>',
'            {points.map((p) => (',
'              <option key={p.id} value={p.id}>',
'                {(p.title || p.name || p.label || p.id) + (p.kind ? " — " + p.kind : "")}',
'              </option>',
'            ))}',
'          </select>',
'        </div>',
'      ) : null}',
'',
'      <div className="mt-4">',
'        <div className="text-sm muted">Notas</div>',
'        <textarea',
'          className="mt-2 w-full rounded-xl border border-white/10 bg-black/20 p-3 outline-none focus:border-white/20"',
'          rows={8}',
'          value={notes}',
'          onChange={(e) => setNotes(e.target.value)}',
'          placeholder="O que foi visto? Onde? Quando? Qual pedido concreto? Qual micro-ação possível?"',
'        />',
'      </div>',
'',
'      <div className="mt-4 flex flex-wrap gap-2">',
'        <button className="card px-3 py-2 hover:bg-white/10 transition" onClick={save}>',
'          <span className="accent">{status === "salvo" ? "Salvo!" : "Salvar"}</span>',
'        </button>',
'        <button className="card px-3 py-2 hover:bg-white/10 transition" onClick={copy}>',
'          <span className="accent">{status === "copiado" ? "Copiado!" : "Copiar JSON"}</span>',
'        </button>',
'      </div>',
'    </section>',
'  );',
'}'
  )
  WriteClientSlugComponent $rpPath $rpLines
} else {
  WL ("[INFO] RegistroPanel.tsx não existe (ok).")
}

# MutiraoRegistro.tsx (se existir) — trocar "recibo" por "registro" e corrigir MapPoint.label
$mrPath = Join-Path $compDir "MutiraoRegistro.tsx"
if (TestP $mrPath) {
  BackupFile $mrPath
  $raw = ReadRaw $mrPath
  if ($null -ne $raw) {
    $raw2 = $raw
    # Corrige referência a label
    $raw2 = $raw2.Replace("p.title || p.label || p.name || p.id","p.title || p.name || p.id")
    # Evita mistura com ECO: troca texto "Recibo" por "Registro"
    $raw2 = $raw2.Replace("Recibo do mutirão","Registro do mutirão")
    $raw2 = $raw2.Replace("recibo do mutirão","registro do mutirão")
    if ($raw2 -ne $raw) {
      WriteUtf8NoBom $mrPath $raw2
      WL ("[OK] patched: " + $mrPath)
    } else {
      WL ("[OK] MutiraoRegistro: nada a alterar.")
    }
  }
} else {
  WL ("[INFO] MutiraoRegistro.tsx não existe (ok).")
}

# -------------------------
# PATCH — Atualizar imports nas páginas: NavPills agora vem de "@/components/NavPills"
# -------------------------
if (TestP $appScope) {
  $files = Get-ChildItem -LiteralPath $appScope -Recurse -File | Where-Object { $_.Extension -in ".tsx",".ts" }
  foreach ($f in $files) {
    $raw = ReadRaw $f.FullName
    if ($null -eq $raw) { continue }

    $usesNav = ($raw -match "<NavPills")
    $hasNewImport = ($raw -match 'from\s+"@/components/NavPills"')
    $mentionsOld = ($raw -match 'from\s+"@/components/CadernoHeader"' -and $raw -match 'NavPills')

    if (-not $usesNav) { continue }

    $lines = $raw -split "`r?`n"

    for ($i=0; $i -lt $lines.Count; $i++) {
      $ln = $lines[$i]
      if ($ln -match 'from\s+"@/components/CadernoHeader"' -and $ln -match 'NavPills') {
        # remove NavPills from named imports
        $ln = $ln.Replace("NavPills, ","").Replace(", NavPills","").Replace("NavPills","")
        $ln = ($ln -replace "\{\s*,","\{")
        $ln = ($ln -replace ",\s*\}"," }")
        $ln = ($ln -replace "\{\s*\}","")
        # if it became an empty import, drop line
        if ($ln -match 'import\s+from\s+"@/components/CadernoHeader"') { $ln = "" }
        $lines[$i] = $ln
      }
    }

    $newRaw = ($lines | Where-Object { $_ -ne "" }) -join "`n"

    if (-not $hasNewImport) {
      # insert import after last import line
      $lines2 = $newRaw -split "`r?`n"
      $lastImp = -1
      for ($i=0; $i -lt $lines2.Count; $i++) {
        if ($lines2[$i].TrimStart().StartsWith("import ")) { $lastImp = $i }
      }
      if ($lastImp -ge 0) {
        $pre = $lines2[0..$lastImp]
        $post = @()
        if ($lastImp + 1 -lt $lines2.Count) { $post = $lines2[($lastImp+1)..($lines2.Count-1)] }
        $lines2 = @($pre + @('import NavPills from "@/components/NavPills";') + $post)
      } else {
        $lines2 = @('import NavPills from "@/components/NavPills";') + $lines2
      }
      $newRaw = $lines2 -join "`n"
    }

    if ($newRaw -ne $raw) {
      BackupFile $f.FullName
      WriteUtf8NoBom $f.FullName $newRaw
      WL ("[OK] patched imports: " + $f.FullName)
    }
  }
} else {
  WL ("[WARN] AppScope não existe: " + $appScope)
}

# -------------------------
# REPORT
# -------------------------
$repDir = Join-Path $repo "reports"
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repDir "cv-4e-stabilize-slug-autoinfer-navpills.md"

$report = @(
"# CV-4e — Stabilize slug autoinfer + NavPills separado — " + $now,
"",
"## O que mudou",
"- NavPills agora é um componente separado em src/components/NavPills.tsx (client).",
"- CadernoHeader foi simplificado e NÃO exporta mais NavPills.",
"- DebateBoard / AulaProgress / TerritoryMap / RegistroPanel: slug virou opcional e é inferido via useParams quando necessário.",
"- MutiraoRegistro: texto ajustado para 'Registro do mutirão' e remoção de MapPoint.label (se existia).",
"",
"## Motivo",
"- Parar o ping-pong de props slug obrigatórias quebrando build.",
"- Centralizar inferência do slug no client e reduzir churn nos pages.",
"",
"## Verify",
"- npm run lint",
"- npm run build"
) -join "`n"

WriteUtf8NoBom $reportPath $report
WL ("[OK] Report: " + $reportPath)

# -------------------------
# VERIFY
# -------------------------
WL "[VERIFY] npm run lint..."
RunNative $repo $npmExe @("run","lint")

if (-not $SkipBuild) {
  WL "[VERIFY] npm run build..."
  RunNative $repo $npmExe @("run","build")
} else {
  WL "[VERIFY] build pulado (-SkipBuild)."
}

WL ""
WL "[OK] Estabilização aplicada. Se abrir um caderno, NavPills e slug devem funcionar sem ficar exigindo prop."