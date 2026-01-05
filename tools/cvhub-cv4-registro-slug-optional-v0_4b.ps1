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
  # fallback: sobe até 4 níveis
  $p = $here
  for ($i=0; $i -lt 4; $i++) {
    $p2 = Split-Path -Parent $p
    if (-not $p2 -or $p2 -eq $p) { break }
    $p = $p2
    if (TestP (Join-Path $p "package.json")) { return $p }
  }
  throw ("[STOP] Rode na raiz do repo (onde tem package.json). Atual: " + $here)
}

# -------------------------
# DIAG
# -------------------------
$repo = ResolveRepoHere
$npmExe = ResolveExe "npm.cmd"
$compDir = Join-Path $repo "src\components"
$appRegistro = Join-Path $repo "src\app\c\[slug]\registro\page.tsx"

$debPath = Join-Path $compDir "DebateBoard.tsx"
$apPath  = Join-Path $compDir "AulaProgress.tsx"
$mapPath = Join-Path $compDir "TerritoryMap.tsx"
$regPanelPath = Join-Path $compDir "RegistroPanel.tsx"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] Components: " + $compDir)

EnsureDir $compDir

# -------------------------
# PATCH: DebateBoard (slug opcional/autoinfer)
# -------------------------
BackupFile $debPath
$debLines = @(
'"use client";',
'',
'import { useMemo, useState } from "react";',
'import { useParams } from "next/navigation";',
'',
'export type DebatePrompt = { id: string; title: string; prompt: string };',
'',
'type Saved = {',
'  answers: Record<string, string>;',
'  pedidoConcreto: string;',
'  acaoAjudaMutua: string;',
'};',
'',
'function slugFromParams(p: unknown): string | undefined {',
'  if (!p || typeof p !== "object") return;',
'  const v = (p as Record<string, unknown>).slug;',
'  return typeof v === "string" ? v : undefined;',
'}',
'',
'function keyFor(slug: string) {',
'  return `cv:${slug}:debate:v1`;',
'}',
'',
'function emptySaved(): Saved {',
'  return { answers: {}, pedidoConcreto: "", acaoAjudaMutua: "" };',
'}',
'',
'function safeGetItem(k: string): string | null {',
'  try {',
'    if (typeof window === "undefined") return null;',
'    return window.localStorage.getItem(k);',
'  } catch {',
'    return null;',
'  }',
'}',
'',
'function safeSetItem(k: string, v: string) {',
'  try {',
'    if (typeof window === "undefined") return;',
'    window.localStorage.setItem(k, v);',
'  } catch {}',
'}',
'',
'function safeRemoveItem(k: string) {',
'  try {',
'    if (typeof window === "undefined") return;',
'    window.localStorage.removeItem(k);',
'  } catch {}',
'}',
'',
'function loadSaved(k: string): Saved {',
'  try {',
'    const raw = safeGetItem(k);',
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
'  const params = useParams();',
'  const s = slug ?? slugFromParams(params);',
'  if (!s) return null;',
'',
'  const k = useMemo(() => keyFor(s), [s]);',
'  const init = useMemo(() => loadSaved(k), [k]);',
'',
'  const [answers, setAnswers] = useState<Record<string, string>>(init.answers);',
'  const [pedidoConcreto, setPedido] = useState(init.pedidoConcreto);',
'  const [acaoAjudaMutua, setAcao] = useState(init.acaoAjudaMutua);',
'  const [status, setStatus] = useState<"" | "salvo" | "copiado">("");',
'',
'  const save = () => {',
'    try {',
'      const data: Saved = { answers, pedidoConcreto, acaoAjudaMutua };',
'      safeSetItem(k, JSON.stringify(data));',
'      setStatus("salvo");',
'      setTimeout(() => setStatus(""), 1200);',
'    } catch {}',
'  };',
'',
'  const copy = async () => {',
'    try {',
'      const payload = { slug: s, answers, pedidoConcreto, acaoAjudaMutua };',
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
'    safeRemoveItem(k);',
'  };',
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
'          <div>',
'            • Sempre terminar com: <span className="accent">pedido concreto</span> +{" "}',
'            <span className="accent">ação simples de ajuda mútua</span>.',
'          </div>',
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
'            <div className="text-sm muted">Pedido concreto (poder público / empresa / órgão / bairro)</div>',
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
'          <button className="card px-3 py-2 hover:bg-white/10 transition" onClick={clearAll}>',
'            Limpar',
'          </button>',
'        </div>',
'      </div>',
'    </div>',
'  );',
'}'
) -join "`n"
WriteUtf8NoBom $debPath $debLines
WL "[OK] wrote: DebateBoard.tsx"

# -------------------------
# PATCH: AulaProgress (slug opcional/autoinfer, sem setState em effect)
# -------------------------
BackupFile $apPath
$apLines = @(
'"use client";',
'',
'import { useEffect, useMemo } from "react";',
'import { useParams } from "next/navigation";',
'',
'type Stored = { total: number; current: number; updatedAt: number };',
'',
'function slugFromParams(p: unknown): string | undefined {',
'  if (!p || typeof p !== "object") return;',
'  const v = (p as Record<string, unknown>).slug;',
'  return typeof v === "string" ? v : undefined;',
'}',
'',
'function keyV1(slug: string) {',
'  return `cv:${slug}:aulaProgress:v1`;',
'}',
'',
'function keyAlt(slug: string) {',
'  return `cv:${slug}:progress:v1`;',
'}',
'',
'function safeGet(k: string): string | null {',
'  try {',
'    if (typeof window === "undefined") return null;',
'    return window.localStorage.getItem(k);',
'  } catch {',
'    return null;',
'  }',
'}',
'',
'function safeSet(k: string, v: string) {',
'  try {',
'    if (typeof window === "undefined") return;',
'    window.localStorage.setItem(k, v);',
'  } catch {}',
'}',
'',
'function load(slug: string): Stored | null {',
'  const keys = [keyV1(slug), keyAlt(slug)];',
'  for (const k of keys) {',
'    const raw = safeGet(k);',
'    if (!raw) continue;',
'    try {',
'      const data = JSON.parse(raw) as Partial<Stored>;',
'      if (typeof data.current === "number" && typeof data.total === "number") {',
'        return {',
'          current: data.current,',
'          total: data.total,',
'          updatedAt: typeof data.updatedAt === "number" ? data.updatedAt : Date.now(),',
'        };',
'      }',
'    } catch {}',
'  }',
'  return null;',
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
'  const params = useParams();',
'  const s = slug ?? slugFromParams(params);',
'  const stored = useMemo(() => (s ? load(s) : null), [s]);',
'',
'  const best = useMemo(() => {',
'    const prev = stored?.current ?? 0;',
'    const cur = Number.isFinite(current) ? current : 0;',
'    return Math.max(prev, cur);',
'  }, [stored, current]);',
'',
'  const pct = useMemo(() => {',
'    if (!total || total <= 0) return 0;',
'    return Math.max(0, Math.min(100, Math.round((best / total) * 100)));',
'  }, [best, total]);',
'',
'  useEffect(() => {',
'    if (!s) return;',
'    const data: Stored = { total, current: best, updatedAt: Date.now() };',
'    safeSet(keyV1(s), JSON.stringify(data));',
'  }, [s, total, best]);',
'',
'  return (',
'    <div className="card p-5">',
'      <div className="flex items-center justify-between gap-3">',
'        <div>',
'          <div className="text-xs muted">Progresso</div>',
'          <div className="text-lg font-semibold mt-1">{best} / {total} aulas</div>',
'        </div>',
'        <div className="text-sm muted">{pct}%</div>',
'      </div>',
'      <div className="mt-3 h-2 rounded-full bg-white/10 overflow-hidden">',
'        <div className="h-2 bg-[var(--accent)]" style={{ width: pct + "%" }} />',
'      </div>',
'    </div>',
'  );',
'}'
) -join "`n"
WriteUtf8NoBom $apPath $apLines
WL "[OK] wrote: AulaProgress.tsx"

# -------------------------
# PATCH: TerritoryMap (sem any + slug opcional/autoinfer)
# -------------------------
BackupFile $mapPath
$mapLines = @(
'"use client";',
'',
'import { useEffect, useMemo, useState, type ChangeEvent } from "react";',
'import Link from "next/link";',
'import { useParams } from "next/navigation";',
'',
'export type MapPoint = {',
'  id: string;',
'  title: string;',
'  kind?: string;',
'  lat?: number;',
'  lng?: number;',
'  note?: string;',
'};',
'',
'function slugFromParams(p: unknown): string | undefined {',
'  if (!p || typeof p !== "object") return;',
'  const v = (p as Record<string, unknown>).slug;',
'  return typeof v === "string" ? v : undefined;',
'}',
'',
'function keyFor(slug: string) {',
'  return `cv:${slug}:map:v1`;',
'}',
'',
'function safeGet(k: string): string | null {',
'  try {',
'    if (typeof window === "undefined") return null;',
'    return window.localStorage.getItem(k);',
'  } catch {',
'    return null;',
'  }',
'}',
'',
'function safeSet(k: string, v: string) {',
'  try {',
'    if (typeof window === "undefined") return;',
'    window.localStorage.setItem(k, v);',
'  } catch {}',
'}',
'',
'type Visited = Record<string, boolean>;',
'',
'function loadVisited(slug: string): Visited {',
'  try {',
'    const raw = safeGet(keyFor(slug));',
'    if (!raw) return {};',
'    const data = JSON.parse(raw) as unknown;',
'    if (!data || typeof data !== "object") return {};',
'    return data as Visited;',
'  } catch {',
'    return {};',
'  }',
'}',
'',
'export default function TerritoryMap({',
'  slug,',
'  points,',
'}: {',
'  slug?: string;',
'  points: MapPoint[];',
'}) {',
'  const params = useParams();',
'  const s = slug ?? slugFromParams(params);',
'',
'  const [q, setQ] = useState("");',
'  const [selected, setSelected] = useState<MapPoint | null>(null);',
'  const [visited, setVisited] = useState<Visited>(() => (s ? loadVisited(s) : {}));',
'',
'  useEffect(() => {',
'    if (!s) return;',
'    safeSet(keyFor(s), JSON.stringify(visited));',
'  }, [s, visited]);',
'',
'  const list = useMemo(() => {',
'    const term = q.trim().toLowerCase();',
'    if (!term) return points;',
'    return points.filter((p) => {',
'      const a = (p.title || "").toLowerCase();',
'      const b = (p.kind || "").toLowerCase();',
'      const c = (p.note || "").toLowerCase();',
'      return a.includes(term) || b.includes(term) || c.includes(term);',
'    });',
'  }, [q, points]);',
'',
'  const onSearch = (e: ChangeEvent<HTMLInputElement>) => setQ(e.target.value);',
'',
'  const openMaps = (p: MapPoint) => {',
'    if (!p.lat || !p.lng) return;',
'    const href = `https://www.google.com/maps?q=${p.lat},${p.lng}`;',
'    window.open(href, "_blank", "noopener,noreferrer");',
'  };',
'',
'  return (',
'    <div className="space-y-4">',
'      <div className="card p-5">',
'        <div className="flex flex-wrap items-end justify-between gap-3">',
'          <div>',
'            <div className="text-xs muted">Mapa do território</div>',
'            <div className="text-lg font-semibold mt-1">Pontos e lugares citados</div>',
'            <div className="text-sm muted mt-1">Não é mapa “bonitinho”: é ferramenta de leitura do chão.</div>',
'          </div>',
'          <div className="w-full sm:w-72">',
'            <input',
'              className="w-full rounded-xl border border-white/10 bg-black/20 p-3 outline-none focus:border-white/20"',
'              placeholder="Buscar ponto, tipo, nota..."',
'              value={q}',
'              onChange={onSearch}',
'            />',
'          </div>',
'        </div>',
'      </div>',
'',
'      <div className="grid gap-3">',
'        {list.map((p) => (',
'          <button',
'            key={p.id}',
'            onClick={() => {',
'              setSelected(p);',
'              setVisited((v) => ({ ...v, [p.id]: true }));',
'            }}',
'            className="card p-5 text-left hover:bg-white/10 transition"',
'          >',
'            <div className="flex items-start justify-between gap-3">',
'              <div>',
'                <div className="text-xs muted">{p.kind || "ponto"}</div>',
'                <div className="text-lg font-semibold mt-1">{p.title}</div>',
'                {p.note ? <div className="muted mt-2">{p.note}</div> : null}',
'              </div>',
'              <div className="text-xs muted">{visited[p.id] ? "visto" : ""}</div>',
'            </div>',
'          </button>',
'        ))}',
'      </div>',
'',
'      {selected ? (',
'        <div className="card p-5">',
'          <div className="text-xs muted">{selected.kind || "ponto"}</div>',
'          <div className="text-xl font-semibold mt-1">{selected.title}</div>',
'          {selected.note ? <div className="muted mt-2">{selected.note}</div> : null}',
'',
'          <div className="mt-4 flex flex-wrap gap-2">',
'            {selected.lat && selected.lng ? (',
'              <button className="card px-3 py-2 hover:bg-white/10 transition" onClick={() => openMaps(selected)}>',
'                <span className="accent">Abrir no Maps</span>',
'              </button>',
'            ) : null}',
'            {s ? (',
'              <Link className="card px-3 py-2 hover:bg-white/10 transition" href={`/c/${s}/debate`}>',
'                Ir pro debate',
'              </Link>',
'            ) : null}',
'            <button className="card px-3 py-2 hover:bg-white/10 transition" onClick={() => setSelected(null)}>',
'              Fechar',
'            </button>',
'          </div>',
'        </div>',
'      ) : null}',
'    </div>',
'  );',
'}'
) -join "`n"
WriteUtf8NoBom $mapPath $mapLines
WL "[OK] wrote: TerritoryMap.tsx"

# -------------------------
# PATCH: RegistroPanel (novo)
# -------------------------
BackupFile $regPanelPath
$regLines = @(
'"use client";',
'',
'import { useMemo, useState } from "react";',
'import { useParams } from "next/navigation";',
'',
'type DebateSaved = {',
'  answers: Record<string, string>;',
'  pedidoConcreto: string;',
'  acaoAjudaMutua: string;',
'};',
'',
'type ProgressSaved = { total: number; current: number; updatedAt: number };',
'',
'function slugFromParams(p: unknown): string | undefined {',
'  if (!p || typeof p !== "object") return;',
'  const v = (p as Record<string, unknown>).slug;',
'  return typeof v === "string" ? v : undefined;',
'}',
'',
'function kDebate(slug: string) {',
'  return `cv:${slug}:debate:v1`;',
'}',
'',
'function kProg1(slug: string) {',
'  return `cv:${slug}:aulaProgress:v1`;',
'}',
'',
'function kProgAlt(slug: string) {',
'  return `cv:${slug}:progress:v1`;',
'}',
'',
'function safeGet(k: string): string | null {',
'  try {',
'    if (typeof window === "undefined") return null;',
'    return window.localStorage.getItem(k);',
'  } catch {',
'    return null;',
'  }',
'}',
'',
'function safeRemove(k: string) {',
'  try {',
'    if (typeof window === "undefined") return;',
'    window.localStorage.removeItem(k);',
'  } catch {}',
'}',
'',
'function loadDebate(slug: string): DebateSaved | null {',
'  try {',
'    const raw = safeGet(kDebate(slug));',
'    if (!raw) return null;',
'    const data = JSON.parse(raw) as Partial<DebateSaved>;',
'    return {',
'      answers: (data.answers as Record<string, string>) || {},',
'      pedidoConcreto: (data.pedidoConcreto as string) || "",',
'      acaoAjudaMutua: (data.acaoAjudaMutua as string) || "",',
'    };',
'  } catch {',
'    return null;',
'  }',
'}',
'',
'function loadProg(slug: string): ProgressSaved | null {',
'  const keys = [kProg1(slug), kProgAlt(slug)];',
'  for (const k of keys) {',
'    const raw = safeGet(k);',
'    if (!raw) continue;',
'    try {',
'      const data = JSON.parse(raw) as Partial<ProgressSaved>;',
'      if (typeof data.total === "number" && typeof data.current === "number") {',
'        return {',
'          total: data.total,',
'          current: data.current,',
'          updatedAt: typeof data.updatedAt === "number" ? data.updatedAt : Date.now(),',
'        };',
'      }',
'    } catch {}',
'  }',
'  return null;',
'}',
'',
'export default function RegistroPanel({ slug }: { slug?: string }) {',
'  const params = useParams();',
'  const s = slug ?? slugFromParams(params);',
'  if (!s) return null;',
'',
'  const debate = useMemo(() => loadDebate(s), [s]);',
'  const prog = useMemo(() => loadProg(s), [s]);',
'',
'  const [status, setStatus] = useState<"" | "copiado">("");',
'',
'  const copy = async () => {',
'    try {',
'      const payload = {',
'        slug: s,',
'        generatedAt: new Date().toISOString(),',
'        progress: prog,',
'        debate: debate,',
'      };',
'      await navigator.clipboard.writeText(JSON.stringify(payload, null, 2));',
'      setStatus("copiado");',
'      setTimeout(() => setStatus(""), 1200);',
'    } catch {}',
'  };',
'',
'  const clear = () => {',
'    safeRemove(kDebate(s));',
'    safeRemove(kProg1(s));',
'    safeRemove(kProgAlt(s));',
'    window.location.reload();',
'  };',
'',
'  const answered = debate ? Object.values(debate.answers || {}).filter((v) => (v || "").trim().length > 0).length : 0;',
'',
'  return (',
'    <div className="space-y-4">',
'      <div className="card p-5">',
'        <h2 className="text-xl font-semibold">Registro do Caderno</h2>',
'        <p className="muted mt-2">',
'          Aqui a gente fecha o estudo como ferramenta de organização: um resumo do que você fez (progresso + debate).',
'          Isso é o “registro” do Cadernos Vivos — não é “recibo de mutirão” (isso é do app ECO).',
'        </p>',
'      </div>',
'',
'      <div className="card p-5">',
'        <div className="text-xs muted">Progresso</div>',
'        {prog ? (',
'          <div className="mt-2">',
'            <div className="text-lg font-semibold">{prog.current} / {prog.total} aulas</div>',
'            <div className="text-sm muted mt-1">Atualizado: {new Date(prog.updatedAt).toLocaleString()}</div>',
'          </div>',
'        ) : (',
'          <div className="muted mt-2">Sem progresso salvo ainda (abra uma aula pra marcar).</div>',
'        )}',
'      </div>',
'',
'      <div className="card p-5">',
'        <div className="text-xs muted">Debate</div>',
'        {debate ? (',
'          <div className="mt-2 space-y-2">',
'            <div className="text-sm muted">Respostas preenchidas: <span className="accent">{answered}</span></div>',
'            <div className="text-sm muted">Pedido concreto: <span className="accent">{debate.pedidoConcreto ? "ok" : "vazio"}</span></div>',
'            <div className="text-sm muted">Ajuda mútua: <span className="accent">{debate.acaoAjudaMutua ? "ok" : "vazio"}</span></div>',
'          </div>',
'        ) : (',
'          <div className="muted mt-2">Sem debate salvo ainda (vá em Debate e salve).</div>',
'        )}',
'      </div>',
'',
'      <div className="card p-5">',
'        <div className="flex flex-wrap gap-2">',
'          <button className="card px-3 py-2 hover:bg-white/10 transition" onClick={copy}>',
'            <span className="accent">{status === "copiado" ? "Copiado!" : "Copiar JSON do registro"}</span>',
'          </button>',
'          <button className="card px-3 py-2 hover:bg-white/10 transition" onClick={clear}>',
'            Limpar registro local',
'          </button>',
'        </div>',
'      </div>',
'    </div>',
'  );',
'}'
) -join "`n"
WriteUtf8NoBom $regPanelPath $regLines
WL "[OK] wrote: RegistroPanel.tsx"

# -------------------------
# PATCH: rota /registro
# -------------------------
BackupFile $appRegistro
EnsureDir (Split-Path -Parent $appRegistro)

$registroPageLines = @(
'import type { CSSProperties } from "react";',
'import { getCaderno } from "@/lib/cadernos";',
'import CadernoHeader from "@/components/CadernoHeader";',
'import { NavPills } from "@/components/CadernoHeader";',
'import RegistroPanel from "@/components/RegistroPanel";',
'',
'type AccentStyle = CSSProperties & { ["--accent"]?: string };',
'',
'export default async function Page({ params }: { params: Promise<{ slug: string }> }) {',
'  const { slug } = await params;',
'  const data = await getCaderno(slug);',
'  const s: AccentStyle = { ["--accent"]: data.meta.accent };',
'  return (',
'    <main className="space-y-5" style={s}>',
'      <CadernoHeader title={data.meta.title} subtitle={data.meta.subtitle} ethos={data.meta.ethos} />',
'      <NavPills slug={slug} />',
'      <RegistroPanel slug={slug} />',
'    </main>',
'  );',
'}'
) -join "`n"
WriteUtf8NoBom $appRegistro $registroPageLines
WL "[OK] wrote: /c/[slug]/registro/page.tsx"

# -------------------------
# REPORT (sem backtick escapando PowerShell)
# -------------------------
$repDir = Join-Path $repo "reports"
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repDir "cv-4-registro-slug-optional-v0_4b.md"

$reportLines = @(
('# CV-4 — Registro do Caderno + slug opcional (v0.4b) — ' + $now),
'',
'## Por que o v0.4 quebrou',
'- O PowerShell interpreta o caractere ` (backtick) como escape em strings com aspas duplas.',
'- No report eu tinha markdown com `useParams` e isso virou escape unicode (`u...) -> ParserError.',
'',
'## Mudança de estratégia',
'- Componentes client não exigem mais `slug` (agora é opcional e pode ser inferido via useParams()).',
'- Isso evita ficar “caçando slug” e quebrando build por prop faltando.',
'',
'## Entregas',
'- Reescrito: src/components/DebateBoard.tsx (slug opcional/autoinfer)',
'- Reescrito: src/components/AulaProgress.tsx (slug opcional/autoinfer)',
'- Reescrito: src/components/TerritoryMap.tsx (sem any + slug opcional/autoinfer)',
'- Novo: src/components/RegistroPanel.tsx',
'- Nova rota: /c/[slug]/registro',
'',
'## Nota (pra não misturar apps)',
'- “Recibo do mutirão” é do ECO.',
'- Aqui é “Registro do Caderno” (progresso + debate) salvo no aparelho.',
'',
'## Verify',
'- npm run lint',
'- npm run build'
) -join "`n"
WriteUtf8NoBom $reportPath $reportLines
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
WL "[OK] CV-4b aplicado. Teste:"
WL " - npm run dev"
WL " - /c/poluicao-vr/registro"
WL " - /c/poluicao-vr/debate (salva) e /c/poluicao-vr/a/1 (marca progresso)"