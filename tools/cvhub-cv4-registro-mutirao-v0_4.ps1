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

function WriteLines([string]$p, [string[]]$lines) {
  $content = ($lines -join "`n") + "`n"
  WriteUtf8NoBom $p $content
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

# -------------------------
# DIAG
# -------------------------
$repo = ResolveRepoHere
$npmExe = ResolveExe "npm.cmd"

$compDir = Join-Path $repo "src\components"
$appDir  = Join-Path $repo "src\app"
$cv4Page = Join-Path $repo "src\app\c\[slug]\registro\page.tsx"
$cv4Comp = Join-Path $repo "src\components\MutiraoRegistro.tsx"
$mapComp = Join-Path $repo "src\components\TerritoryMap.tsx"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] Will write: " + $cv4Comp)
WL ("[DIAG] Will write: " + $cv4Page)

# -------------------------
# PATCH: component MutiraoRegistro.tsx
# -------------------------
EnsureDir $compDir
BackupFile $cv4Comp

$comp = @(
'"use client";',
'',
'import { useMemo, useState } from "react";',
'import { usePathname } from "next/navigation";',
'import type { MapPoint } from "@/components/TerritoryMap";',
'',
'type Registro = {',
'  id: string;',
'  title: string;',
'  when: string;',
'  where: string;',
'  pointId?: string;',
'  summary: string;',
'  evidence: string;',
'  pedidoConcreto: string;',
'  acaoAjudaMutua: string;',
'  proximoPasso: string;',
'  tags: string;',
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
'  return "cv:" + slug + ":mutirao:v1";',
'}',
'',
'function emptyRegistro(): Registro {',
'  const id = String(Date.now());',
'  return {',
'    id,',
'    title: "Mutirao",',
'    when: "",',
'    where: "",',
'    pointId: "",',
'    summary: "",',
'    evidence: "",',
'    pedidoConcreto: "",',
'    acaoAjudaMutua: "",',
'    proximoPasso: "",',
'    tags: "",',
'  };',
'}',
'',
'function safeLoad(k: string): Registro[] {',
'  if (typeof window === "undefined") return [];',
'  try {',
'    const raw = window.localStorage.getItem(k);',
'    if (!raw) return [];',
'    const data = JSON.parse(raw) as unknown;',
'    if (!Array.isArray(data)) return [];',
'    return data as Registro[];',
'  } catch {',
'    return [];',
'  }',
'}',
'',
'function safeSave(k: string, items: Registro[]) {',
'  if (typeof window === "undefined") return;',
'  try {',
'    window.localStorage.setItem(k, JSON.stringify(items));',
'  } catch {}',
'}',
'',
'function titleOfPoint(p: MapPoint): string {',
'  return p.title || p.label || p.name || p.id;',
'}',
'',
'export default function MutiraoRegistro({',
'  slug,',
'  points,',
'}: {',
'  slug?: string;',
'  points?: MapPoint[];',
'}) {',
'  const pathname = usePathname();',
'  const inferred = useMemo(() => (slug && slug.length ? slug : inferSlugFromPath(pathname)), [slug, pathname]);',
'  const storageKey = useMemo(() => (inferred ? keyFor(inferred) : ""), [inferred]);',
'',
'  const initList = useMemo(() => (storageKey ? safeLoad(storageKey) : []), [storageKey]);',
'  const boot = useMemo(() => (initList.length ? initList : [emptyRegistro()]), [initList]);',
'',
'  const [items, setItems] = useState<Registro[]>(boot);',
'  const [selectedId, setSelectedId] = useState<string>(boot[0]?.id || "");',
'  const [status, setStatus] = useState<"" | "salvo" | "copiado">("");',
'',
'  const current = useMemo(() => items.find((x) => x.id === selectedId) || items[0], [items, selectedId]);',
'  const pts = points || [];',
'',
'  const persist = (next: Registro[]) => {',
'    setItems(next);',
'    if (storageKey) safeSave(storageKey, next);',
'  };',
'',
'  const update = (patch: Partial<Registro>) => {',
'    const next = items.map((x) => (x.id === current.id ? { ...x, ...patch } : x));',
'    persist(next);',
'  };',
'',
'  const addNew = () => {',
'    const n = emptyRegistro();',
'    const next = [n, ...items];',
'    persist(next);',
'    setSelectedId(n.id);',
'  };',
'',
'  const remove = () => {',
'    if (items.length <= 1) return;',
'    const next = items.filter((x) => x.id !== current.id);',
'    persist(next);',
'    setSelectedId(next[0]?.id || "");',
'  };',
'',
'  const saveNow = () => {',
'    if (!storageKey) return;',
'    safeSave(storageKey, items);',
'    setStatus("salvo");',
'    window.setTimeout(() => setStatus(""), 1200);',
'  };',
'',
'  const copyJson = async () => {',
'    try {',
'      await navigator.clipboard.writeText(JSON.stringify({ slug: inferred, registros: items }, null, 2));',
'      setStatus("copiado");',
'      window.setTimeout(() => setStatus(""), 1200);',
'    } catch {}',
'  };',
'',
'  const copyPost = async () => {',
'    const p = current;',
'    const point = pts.find((x) => x.id === (p.pointId || ""));',
'    const pointLine = point ? ("Ponto: " + titleOfPoint(point)) : "";',
'    const text = [',
'      "REGISTRO DO MUTIRAO",',
'      p.title ? ("Titulo: " + p.title) : "",',
'      p.where ? ("Onde: " + p.where) : "",',
'      p.when ? ("Quando: " + p.when) : "",',
'      pointLine,',
'      "",',
'      "O que aconteceu (sem tribunal):",',
'      p.summary || "",',
'      "",',
'      "Evidencias / pistas:",',
'      p.evidence || "",',
'      "",',
'      "Pedido concreto:",',
'      p.pedidoConcreto || "",',
'      "",',
'      "Acao simples de ajuda mutua:",',
'      p.acaoAjudaMutua || "",',
'      "",',
'      "Proximo passo:",',
'      p.proximoPasso || "",',
'      "",',
'      p.tags ? ("Tags: " + p.tags) : "",',
'    ].filter(Boolean).join("\\n");',
'    try {',
'      await navigator.clipboard.writeText(text);',
'      setStatus("copiado");',
'      window.setTimeout(() => setStatus(""), 1200);',
'    } catch {}',
'  };',
'',
'  return (',
'    <div className="grid gap-4">',

'      <div className="card p-5">',
'        <h2 className="text-xl font-semibold">Registro do mutirao</h2>',
'        <p className="muted mt-2">',
'          Isto aqui e ferramenta do Cadernos Vivos: memoria do territorio + organizacao. Nao e o app ECO.',
'        </p>',
'      </div>',

'      <div className="grid gap-4 lg:grid-cols-[0.8fr_1.2fr]">',
'        <div className="card p-4">',
'          <div className="flex items-center justify-between gap-2">',
'            <div className="text-sm font-semibold">Registros</div>',
'            <button className="card px-3 py-2 hover:bg-white/10 transition" onClick={addNew}>',
'              <span className="accent">Novo</span>',
'            </button>',
'          </div>',
'          <div className="mt-3 grid gap-2">',
'            {items.map((r) => (',
'              <button',
'                key={r.id}',
'                onClick={() => setSelectedId(r.id)}',
'                className={"text-left card px-3 py-2 hover:bg-white/10 transition " + (r.id === selectedId ? "ring-2 ring-white/20" : "")}',
'              >',
'                <div className="text-sm font-semibold">{r.title || "Mutirao"}</div>',
'                <div className="text-xs muted">{r.when || "sem data"} • {r.where || "sem local"}</div>',
'              </button>',
'            ))}',
'          </div>',
'          <div className="mt-3 flex flex-wrap gap-2">',
'            <button className="card px-3 py-2 hover:bg-white/10 transition" onClick={remove}>Remover</button>',
'          </div>',
'        </div>',

'        <div className="card p-5">',
'          <div className="text-xs muted">Edicao</div>',
'          <div className="mt-3 grid gap-3">',
'            <div>',
'              <div className="text-sm muted">Titulo</div>',
'              <input',
'                className="mt-2 w-full rounded-xl border border-white/10 bg-black/20 p-3 outline-none focus:border-white/20"',
'                value={current.title}',
'                onChange={(e) => update({ title: e.target.value })}',
'              />',
'            </div>',
'            <div className="grid gap-3 lg:grid-cols-2">',
'              <div>',
'                <div className="text-sm muted">Quando</div>',
'                <input',
'                  className="mt-2 w-full rounded-xl border border-white/10 bg-black/20 p-3 outline-none focus:border-white/20"',
'                  value={current.when}',
'                  onChange={(e) => update({ when: e.target.value })}',
'                  placeholder="ex: 27/12 15:00"',
'                />',
'              </div>',
'              <div>',
'                <div className="text-sm muted">Onde</div>',
'                <input',
'                  className="mt-2 w-full rounded-xl border border-white/10 bg-black/20 p-3 outline-none focus:border-white/20"',
'                  value={current.where}',
'                  onChange={(e) => update({ where: e.target.value })}',
'                  placeholder="bairro/rua/referencia"',
'                />',
'              </div>',
'            </div>',
'            <div>',
'              <div className="text-sm muted">Vincular ao ponto do mapa (opcional)</div>',
'              <select',
'                className="mt-2 w-full rounded-xl border border-white/10 bg-black/20 p-3 outline-none focus:border-white/20"',
'                value={current.pointId || ""}',
'                onChange={(e) => update({ pointId: e.target.value })}',
'              >',
'                <option value="">(sem ponto)</option>',
'                {pts.map((p) => (',
'                  <option key={p.id} value={p.id}>{titleOfPoint(p)}</option>',
'                ))}',
'              </select>',
'            </div>',
'            <div>',
'              <div className="text-sm muted">O que aconteceu (sem tribunal)</div>',
'              <textarea',
'                className="mt-2 w-full rounded-xl border border-white/10 bg-black/20 p-3 outline-none focus:border-white/20"',
'                rows={5}',
'                value={current.summary}',
'                onChange={(e) => update({ summary: e.target.value })}',
'              />',
'            </div>',
'            <div>',
'              <div className="text-sm muted">Evidencias / pistas (links, fotos, testemunhos)</div>',
'              <textarea',
'                className="mt-2 w-full rounded-xl border border-white/10 bg-black/20 p-3 outline-none focus:border-white/20"',
'                rows={3}',
'                value={current.evidence}',
'                onChange={(e) => update({ evidence: e.target.value })}',
'              />',
'            </div>',
'            <div>',
'              <div className="text-sm muted">Pedido concreto</div>',
'              <textarea',
'                className="mt-2 w-full rounded-xl border border-white/10 bg-black/20 p-3 outline-none focus:border-white/20"',
'                rows={2}',
'                value={current.pedidoConcreto}',
'                onChange={(e) => update({ pedidoConcreto: e.target.value })}',
'              />',
'            </div>',
'            <div>',
'              <div className="text-sm muted">Acao simples de ajuda mutua</div>',
'              <textarea',
'                className="mt-2 w-full rounded-xl border border-white/10 bg-black/20 p-3 outline-none focus:border-white/20"',
'                rows={2}',
'                value={current.acaoAjudaMutua}',
'                onChange={(e) => update({ acaoAjudaMutua: e.target.value })}',
'              />',
'            </div>',
'            <div>',
'              <div className="text-sm muted">Proximo passo</div>',
'              <textarea',
'                className="mt-2 w-full rounded-xl border border-white/10 bg-black/20 p-3 outline-none focus:border-white/20"',
'                rows={2}',
'                value={current.proximoPasso}',
'                onChange={(e) => update({ proximoPasso: e.target.value })}',
'              />',
'            </div>',
'            <div>',
'              <div className="text-sm muted">Tags (separadas por virgula)</div>',
'              <input',
'                className="mt-2 w-full rounded-xl border border-white/10 bg-black/20 p-3 outline-none focus:border-white/20"',
'                value={current.tags}',
'                onChange={(e) => update({ tags: e.target.value })}',
'                placeholder="ex: poluicao, bairro, denuncia"',
'              />',
'            </div>',
'          </div>',

'          <div className="mt-4 flex flex-wrap gap-2">',
'            <button className="card px-3 py-2 hover:bg-white/10 transition" onClick={saveNow}>',
'              <span className="accent">{status === "salvo" ? "Salvo!" : "Salvar"}</span>',
'            </button>',
'            <button className="card px-3 py-2 hover:bg-white/10 transition" onClick={copyPost}>',
'              <span className="accent">{status === "copiado" ? "Copiado!" : "Copiar texto pronto"}</span>',
'            </button>',
'            <button className="card px-3 py-2 hover:bg-white/10 transition" onClick={copyJson}>Copiar JSON</button>',
'          </div>',
'        </div>',
'      </div>',

'    </div>',
'  );',
'}'
)

WriteLines $cv4Comp $comp
WL "[OK] wrote: MutiraoRegistro.tsx"

# -------------------------
# PATCH: page route /c/[slug]/registro
# -------------------------
EnsureDir (Split-Path -Parent $cv4Page)
BackupFile $cv4Page

$page = @(
'import path from "path";',
'import { readFile } from "fs/promises";',
'import type { CSSProperties } from "react";',
'',
'import CadernoHeader from "@/components/CadernoHeader";',
'import { NavPills } from "@/components/CadernoHeader";',
'import MutiraoRegistro from "@/components/MutiraoRegistro";',
'import { getCaderno } from "@/lib/cadernos";',
'import type { MapPoint } from "@/components/TerritoryMap";',
'',
'type AccentStyle = CSSProperties & { ["--accent"]?: string };',
'',
'function pointsFromJson(raw: string): MapPoint[] {',
'  try {',
'    const data = JSON.parse(raw) as unknown;',
'    if (Array.isArray(data)) return data as MapPoint[];',
'    if (data && typeof data === "object") {',
'      const obj = data as Record<string, unknown>;',
'      const pts = obj["points"];',
'      if (Array.isArray(pts)) return pts as MapPoint[];',
'    }',
'    return [];',
'  } catch {',
'    return [];',
'  }',
'}',
'',
'export default async function Page({ params }: { params: Promise<{ slug: string }> }) {',
'  const { slug } = await params;',
'  const data = await getCaderno(slug);',
'  const s: AccentStyle = { ["--accent"]: data.meta.accent };',
'',
'  let points: MapPoint[] = [];',
'  try {',
'    const p = path.join(process.cwd(), "content", "cadernos", slug, "mapa.json");',
'    const raw = await readFile(p, "utf8");',
'    points = pointsFromJson(raw);',
'  } catch {',
'    points = [];',
'  }',
'',
'  return (',
'    <main className="space-y-5" style={s}>',
'      <CadernoHeader title={data.meta.title} subtitle={data.meta.subtitle} ethos={data.meta.ethos} />',
'      <NavPills slug={slug} />',
'      <MutiraoRegistro points={points} />',
'    </main>',
'  );',
'}'
)

WriteLines $cv4Page $page
WL "[OK] wrote: /c/[slug]/registro/page.tsx"

# -------------------------
# PATCH: fix eslint any in TerritoryMap (se existir)
# -------------------------
if (TestP $mapComp) {
  $rawMap = Get-Content -LiteralPath $mapComp -Raw
  if ($rawMap -match ":\s*any") {
    BackupFile $mapComp
    $fixed = $rawMap -replace ":\s*any", ": unknown"
    WriteUtf8NoBom $mapComp $fixed
    WL "[OK] patched: TerritoryMap.tsx (any -> unknown)"
  } else {
    WL "[OK] TerritoryMap.tsx sem any (nada a fazer)."
  }
}

# -------------------------
# REPORT
# -------------------------
$repDir = Join-Path $repo "reports"
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$repPath = Join-Path $repDir "cv-4-registro-mutirao-v0_4.md"
$rep = @(
("# CV-4 — Registro do Mutirao — " + $now),
"",
"## O que entrou",
"- Nova rota: /c/[slug]/registro",
"- Novo componente MutiraoRegistro (client): salva no aparelho, copia texto pronto, copia JSON",
"- Vinculo opcional a pontos do mapa (se mapa.json existir)",
"",
"## Nota importante",
"- Aqui e metodo do Cadernos Vivos (pedagogia). Nao e o app ECO.",
"",
"## Verify",
"- npm run lint",
"- npm run build",
"",
"## Abrir",
"- /c/poluicao-vr/registro"
)
WriteLines $repPath $rep
WL ("[OK] Report: " + $repPath)

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
WL "[OK] CV-4 pronto. Abra /c/poluicao-vr/registro"