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

function WriteLines([string]$path, [string[]]$lines) {
  $content = ($lines -join "`n") + "`n"
  WriteUtf8NoBom $path $content
}

# -------------------------
# DIAG
# -------------------------
$repo = ResolveRepoHere
$npmExe = ResolveExe "npm.cmd"

$debPath  = Join-Path $repo "src\components\DebateBoard.tsx"
$mapPath  = Join-Path $repo "src\components\TerritoryMap.tsx"
$progPath = Join-Path $repo "src\components\AulaProgress.tsx"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] DebateBoard: " + $debPath)
WL ("[DIAG] TerritoryMap: " + $mapPath)
WL ("[DIAG] AulaProgress: " + $progPath)

if (-not (TestP $debPath))  { throw ("[STOP] Não achei: " + $debPath) }
if (-not (TestP $mapPath))  { throw ("[STOP] Não achei: " + $mapPath) }
if (-not (TestP $progPath)) { throw ("[STOP] Não achei: " + $progPath) }

# -------------------------
# PATCH
# -------------------------
BackupFile $debPath
BackupFile $mapPath
BackupFile $progPath

# DebateBoard.tsx (slug opcional, inferido por pathname)
$deb = @(
'"use client";',
'',
'import { useMemo, useState } from "react";',
'import { usePathname } from "next/navigation";',
'',
'export type DebatePrompt = { id: string; title: string; prompt: string };',
'',
'type Saved = {',
'  answers: Record<string, string>;',
'  pedidoConcreto: string;',
'  acaoAjudaMutua: string;',
'};',
'',
'function inferSlugFromPath(pathname: string): string {',
'  const parts = pathname.split("/").filter(Boolean);',
'  const i = parts.indexOf("c");',
'  if (i >= 0 && parts.length > i + 1) return parts[i + 1] || "";',
'  return "";',
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
'function safeLoad(k: string): Saved {',
'  if (typeof window === "undefined") return emptySaved();',
'  try {',
'    const raw = window.localStorage.getItem(k);',
'    if (!raw) return emptySaved();',
'    const data = JSON.parse(raw) as Partial<Saved>;',
'    return {',
'      answers: (data.answers as Record<string, string>) || {},',
'      pedidoConcreto: (data.pedidoConcreto as string) || "",',
'      acaoAjudaMutua: (data.acaoAjudaMutua as string) || "",',
'    };',
'  } catch {',
'    return emptySaved();',
'  }',
'}',
'',
'export default function DebateBoard({',
'  slug,',
'  prompts,',
'}: {',
'  slug?: string;',
'  prompts: DebatePrompt[];',
'}) {',
'  const pathname = usePathname();',
'  const inferred = useMemo(() => (slug && slug.length ? slug : inferSlugFromPath(pathname)), [slug, pathname]);',
'  const storageKey = useMemo(() => (inferred ? keyFor(inferred) : ""), [inferred]);',
'',
'  const init = useMemo(() => (storageKey ? safeLoad(storageKey) : emptySaved()), [storageKey]);',
'  const [answers, setAnswers] = useState<Record<string, string>>(init.answers);',
'  const [pedidoConcreto, setPedido] = useState(init.pedidoConcreto);',
'  const [acaoAjudaMutua, setAcao] = useState(init.acaoAjudaMutua);',
'  const [status, setStatus] = useState<"" | "salvo" | "copiado">("");',
'',
'  const save = () => {',
'    if (!storageKey || typeof window === "undefined") return;',
'    try {',
'      const data: Saved = { answers, pedidoConcreto, acaoAjudaMutua };',
'      window.localStorage.setItem(storageKey, JSON.stringify(data));',
'      setStatus("salvo");',
'      window.setTimeout(() => setStatus(""), 1200);',
'    } catch {}',
'  };',
'',
'  const copy = async () => {',
'    try {',
'      const payload = { slug: inferred, answers, pedidoConcreto, acaoAjudaMutua };',
'      await navigator.clipboard.writeText(JSON.stringify(payload, null, 2));',
'      setStatus("copiado");',
'      window.setTimeout(() => setStatus(""), 1200);',
'    } catch {}',
'  };',
'',
'  const clearAll = () => {',
'    setAnswers({});',
'    setPedido("");',
'    setAcao("");',
'    if (!storageKey || typeof window === "undefined") return;',
'    try {',
'      window.localStorage.removeItem(storageKey);',
'    } catch {}',
'  };',
'',
'  return (',
'    <div className="space-y-4">',

'      <div className="card p-5">',
'        <h3 className="text-lg font-semibold">Sem tribunal</h3>',
'        <p className="muted mt-2">',
'          Debate aqui e ferramenta de cuidado e organizacao: diagnostico estrutural,',
'          linguagem concreta, e saida pratica.',
'        </p>',
'        <div className="mt-4 grid gap-2 text-sm muted">',
'          <div>• Evitar moralismo / caca as bruxas.</div>',
'          <div>• Sempre fechar com pedido concreto + acao simples de ajuda mutua.</div>',
'        </div>',
'      </div>',

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
'              placeholder="Escreva sua sintese."',
'            />',
'          </div>',
'        ))}',
'      </div>',

'      <div className="card p-5">',
'        <h3 className="text-lg font-semibold">Fechamento obrigatorio</h3>',
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
'            <div className="text-sm muted">Acao simples de ajuda mutua (2-10 min)</div>',
'            <textarea',
'              className="mt-2 w-full rounded-xl border border-white/10 bg-black/20 p-3 outline-none focus:border-white/20"',
'              rows={3}',
'              value={acaoAjudaMutua}',
'              onChange={(e) => setAcao(e.target.value)}',
'            />',
'          </div>',
'        </div>',

'        <div className="mt-4 flex flex-wrap gap-2">',
'          <button className="card px-3 py-2 hover:bg-white/10 transition" onClick={save}>',
'            <span className="accent">{status === "salvo" ? "Salvo!" : "Salvar"}</span>',
'          </button>',
'          <button className="card px-3 py-2 hover:bg-white/10 transition" onClick={copy}>',
'            <span className="accent">{status === "copiado" ? "Copiado!" : "Copiar JSON"}</span>',
'          </button>',
'          <button className="card px-3 py-2 hover:bg-white/10 transition" onClick={clearAll}>',
'            Limpar',
'          </button>',
'        </div>',
'      </div>',

'    </div>',
'  );',
'}'
)

WriteLines $debPath $deb
WL "[OK] DebateBoard.tsx atualizado (slug opcional + infer)."

# TerritoryMap.tsx (remove any + slug opcional inferido)
$map = @(
'"use client";',
'',
'import { useMemo, useState } from "react";',
'import { usePathname } from "next/navigation";',
'',
'export type MapPoint = {',
'  id: string;',
'  title?: string;',
'  label?: string;',
'  name?: string;',
'  kind?: string;',
'  category?: string;',
'  lat?: number;',
'  lng?: number;',
'  x?: number;',
'  y?: number;',
'  desc?: string;',
'  description?: string;',
'  source?: string;',
'  url?: string;',
'};',
'',
'type Saved = { selectedId?: string; notes?: Record<string, string> };',
'',
'function inferSlugFromPath(pathname: string): string {',
'  const parts = pathname.split("/").filter(Boolean);',
'  const i = parts.indexOf("c");',
'  if (i >= 0 && parts.length > i + 1) return parts[i + 1] || "";',
'  return "";',
'}',
'',
'function keyFor(slug: string) {',
'  return "cv:" + slug + ":mapa:v1";',
'}',
'',
'function safeLoad(k: string): Saved {',
'  if (typeof window === "undefined") return {};',
'  try {',
'    const raw = window.localStorage.getItem(k);',
'    if (!raw) return {};',
'    return JSON.parse(raw) as Saved;',
'  } catch {',
'    return {};',
'  }',
'}',
'',
'function safeSave(k: string, data: Saved) {',
'  if (typeof window === "undefined") return;',
'  try { window.localStorage.setItem(k, JSON.stringify(data)); } catch {}',
'}',
'',
'function titleOf(p: MapPoint): string {',
'  return p.title || p.label || p.name || p.id;',
'}',
'',
'function descOf(p: MapPoint): string {',
'  return p.desc || p.description || "";',
'}',
'',
'function normalize(points: MapPoint[]) {',
'  const withLatLng = points.filter((p) => typeof p.lat === "number" && typeof p.lng === "number");',
'  if (withLatLng.length === 0) return points;',
'  const lats = withLatLng.map((p) => p.lat as number);',
'  const lngs = withLatLng.map((p) => p.lng as number);',
'  const minLat = Math.min(...lats);',
'  const maxLat = Math.max(...lats);',
'  const minLng = Math.min(...lngs);',
'  const maxLng = Math.max(...lngs);',
'  const dLat = maxLat - minLat || 1;',
'  const dLng = maxLng - minLng || 1;',
'  return points.map((p) => {',
'    if (typeof p.x === "number" && typeof p.y === "number") return p;',
'    if (typeof p.lat === "number" && typeof p.lng === "number") {',
'      const x = ((p.lng - minLng) / dLng) * 100;',
'      const y = (1 - (p.lat - minLat) / dLat) * 100;',
'      return { ...p, x, y };',
'    }',
'    return { ...p, x: 50, y: 50 };',
'  });',
'}',
'',
'export default function TerritoryMap({',
'  slug,',
'  points,',
'}: {',
'  slug?: string;',
'  points: MapPoint[];',
'}) {',
'  const pathname = usePathname();',
'  const inferred = useMemo(() => (slug && slug.length ? slug : inferSlugFromPath(pathname)), [slug, pathname]);',
'  const storageKey = useMemo(() => (inferred ? keyFor(inferred) : ""), [inferred]);',
'',
'  const norm = useMemo(() => normalize(points || []), [points]);',
'  const init = useMemo(() => (storageKey ? safeLoad(storageKey) : {}), [storageKey]);',
'',
'  const [selectedId, setSelectedId] = useState<string>(init.selectedId || (norm[0]?.id || ""));',
'  const [notes, setNotes] = useState<Record<string, string>>(init.notes || {});',
'',
'  const selected = useMemo(() => norm.find((p) => p.id === selectedId), [norm, selectedId]);',
'',
'  const save = (nextSelectedId: string, nextNotes: Record<string, string>) => {',
'    if (!storageKey) return;',
'    safeSave(storageKey, { selectedId: nextSelectedId, notes: nextNotes });',
'  };',
'',
'  return (',
'    <div className="grid gap-4">',
'      <div className="card p-5">',
'        <h2 className="text-xl font-semibold">Mapa do territorio</h2>',
'        <p className="muted mt-2">',
'          Clique nos pontos. Use as notas para registrar observacoes e pistas do territorio.',
'        </p>',
'      </div>',
'',
'      <div className="grid gap-4 lg:grid-cols-[1.4fr_0.9fr]">',
'        <div className="card p-4">',
'          <div className="relative w-full overflow-hidden rounded-xl border border-white/10 bg-black/20" style={{ height: 420 }}>',
'            <div className="absolute inset-0" style={{ backgroundImage: "linear-gradient(rgba(255,255,255,0.06) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.06) 1px, transparent 1px)", backgroundSize: "24px 24px" }} />',
'            {norm.map((p) => {',
'              const x = typeof p.x === "number" ? p.x : 50;',
'              const y = typeof p.y === "number" ? p.y : 50;',
'              const active = p.id === selectedId;',
'              return (',
'                <button',
'                  key={p.id}',
'                  onClick={() => { setSelectedId(p.id); save(p.id, notes); }}',
'                  className={"absolute -translate-x-1/2 -translate-y-1/2 rounded-full border border-white/20 bg-black/60 px-2 py-1 text-xs hover:bg-white/10 " + (active ? "ring-2 ring-white/30" : "")}',
'                  style={{ left: x + "%", top: y + "%" }}',
'                  title={titleOf(p)}',
'                >',
'                  {titleOf(p)}',
'                </button>',
'              );',
'            })}',
'          </div>',
'          <div className="mt-3 text-xs muted">Dica: se mapa.json tiver lat/lng, a posicao e normalizada automaticamente.</div>',
'        </div>',
'',
'        <div className="grid gap-4">',
'          <div className="card p-5">',
'            <div className="text-xs muted">Ponto selecionado</div>',
'            <div className="text-lg font-semibold mt-1">{selected ? titleOf(selected) : "Nenhum"}</div>',
'            {selected ? (',
'              <div className="mt-2 grid gap-2 text-sm muted">',
'                {descOf(selected) ? <div className="whitespace-pre-wrap">{descOf(selected)}</div> : <div>Sem descricao.</div>}',
'                {(typeof selected.lat === "number" && typeof selected.lng === "number") ? (',
'                  <div>Coord: {String(selected.lat)}, {String(selected.lng)}</div>',
'                ) : null}',
'                {(selected.url || selected.source) ? (',
'                  <div className="break-all">Fonte: {String(selected.url || selected.source)}</div>',
'                ) : null}',
'              </div>',
'            ) : null}',
'          </div>',
'',
'          <div className="card p-5">',
'            <div className="text-sm font-semibold">Notas do ponto</div>',
'            <textarea',
'              className="mt-3 w-full rounded-xl border border-white/10 bg-black/20 p-3 outline-none focus:border-white/20"',
'              rows={8}',
'              value={notes[selectedId] || ""}',
'              onChange={(e) => {',
'                const next = { ...notes, [selectedId]: e.target.value };',
'                setNotes(next);',
'                save(selectedId, next);',
'              }}',
'              placeholder="O que voce viu? Qual pista? O que falta medir, documentar, cobrar?"',
'            />',
'          </div>',
'        </div>',
'      </div>',
'    </div>',
'  );',
'}'
)

WriteLines $mapPath $map
WL "[OK] TerritoryMap.tsx atualizado (sem any + slug opcional + infer)."

# AulaProgress.tsx (slug opcional inferido)
$prog = @(
'"use client";',
'',
'import { useMemo, useState } from "react";',
'import { usePathname } from "next/navigation";',
'',
'type Saved = { done: number[] };',
'',
'function inferSlugFromPath(pathname: string): string {',
'  const parts = pathname.split("/").filter(Boolean);',
'  const i = parts.indexOf("c");',
'  if (i >= 0 && parts.length > i + 1) return parts[i + 1] || "";',
'  return "";',
'}',
'',
'function keyFor(slug: string) {',
'  return "cv:" + slug + ":aulas:v1";',
'}',
'',
'function safeLoad(k: string): Saved {',
'  if (typeof window === "undefined") return { done: [] };',
'  try {',
'    const raw = window.localStorage.getItem(k);',
'    if (!raw) return { done: [] };',
'    const data = JSON.parse(raw) as Partial<Saved>;',
'    return { done: Array.isArray(data.done) ? (data.done as number[]) : [] };',
'  } catch {',
'    return { done: [] };',
'  }',
'}',
'',
'function safeSave(k: string, data: Saved) {',
'  if (typeof window === "undefined") return;',
'  try { window.localStorage.setItem(k, JSON.stringify(data)); } catch {}',
'}',
'',
'export default function AulaProgress({',
'  slug,',
'  total,',
'  current,',
'}: {',
'  slug?: string;',
'  total: number;',
'  current: number;',
'}) {',
'  const pathname = usePathname();',
'  const inferred = useMemo(() => (slug && slug.length ? slug : inferSlugFromPath(pathname)), [slug, pathname]);',
'  const storageKey = useMemo(() => (inferred ? keyFor(inferred) : ""), [inferred]);',
'  const init = useMemo(() => (storageKey ? safeLoad(storageKey) : { done: [] }), [storageKey]);',
'',
'  const [done, setDone] = useState<number[]>(init.done);',
'',
'  const pct = useMemo(() => {',
'    const d = Math.min(Math.max(done.length, 0), total);',
'    return total ? Math.round((d / total) * 100) : 0;',
'  }, [done, total]);',
'',
'  const markDone = () => {',
'    if (!storageKey) return;',
'    const n = current;',
'    const next = Array.from(new Set([...(done || []), n])).sort((a, b) => a - b);',
'    setDone(next);',
'    safeSave(storageKey, { done: next });',
'  };',
'',
'  const clear = () => {',
'    if (!storageKey) return;',
'    setDone([]);',
'    safeSave(storageKey, { done: [] });',
'  };',
'',
'  return (',
'    <div className="card p-4">',
'      <div className="flex items-center justify-between gap-3">',
'        <div>',
'          <div className="text-xs muted">Progresso</div>',
'          <div className="text-sm font-semibold mt-1">{pct}% concluido</div>',
'        </div>',
'        <div className="flex gap-2">',
'          <button className="card px-3 py-2 hover:bg-white/10 transition" onClick={markDone}>',
'            <span className="accent">Marcar aula {String(current)} como feita</span>',
'          </button>',
'          <button className="card px-3 py-2 hover:bg-white/10 transition" onClick={clear}>Limpar</button>',
'        </div>',
'      </div>',
'      <div className="mt-3 h-2 w-full overflow-hidden rounded-full bg-black/30 border border-white/10">',
'        <div className="h-full bg-white/20" style={{ width: pct + "%" }} />',
'      </div>',
'      <div className="mt-2 text-xs muted">Feito: {String(done.length)} / {String(total)}</div>',
'    </div>',
'  );',
'}'
)

WriteLines $progPath $prog
WL "[OK] AulaProgress.tsx atualizado (slug opcional + infer)."

# -------------------------
# REPORT
# -------------------------
$repDir = Join-Path $repo "reports"
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repDir "cv-3m-hotfix-slug-autoinfer-components.md"
$reportLines = @(
("# CV-3m — Hotfix slug opcional e autoinfer — " + $now),
"",
"## Problema",
"- Build quebrava quando algum componente client exigia slug e a pagina esquecia de passar.",
"",
"## Estrategia nova",
"- slug vira opcional em componentes client e e inferido via pathname (/c/<slug>/...).",
"",
"## Alteracoes",
"- DebateBoard: slug?: string + infer + localStorage seguro",
"- TerritoryMap: slug?: string + infer + remove any (eslint)",
"- AulaProgress: slug?: string + infer + localStorage seguro",
"",
"## Verify",
"- npm run lint",
"- npm run build"
)
WriteLines $reportPath $reportLines
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
WL "[OK] Hotfix aplicado. Agora pages podem omitir slug nos componentes client."