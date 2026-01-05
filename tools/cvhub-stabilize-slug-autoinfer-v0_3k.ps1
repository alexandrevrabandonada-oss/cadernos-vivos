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

function ResolveRepo() {
  $here = (Get-Location).Path
  if (TestP (Join-Path $here "package.json")) { return $here }

  $child = Join-Path $here "cadernos-vivos"
  if (TestP (Join-Path $child "package.json")) { return $child }

  throw ("[STOP] Rode na raiz do repo (onde tem package.json). Atual: " + $here)
}

function FindOne([string]$root, [string]$fileName) {
  $hits = @(Get-ChildItem -LiteralPath $root -Recurse -File -Filter $fileName -ErrorAction SilentlyContinue)
  if ($hits.Count -gt 0) { return $hits[0].FullName }
  return $null
}

# -------------------------
# DIAG
# -------------------------
$repo = ResolveRepo
$npmExe = ResolveExe "npm.cmd"

$navPath = FindOne $repo "NavPills.tsx"
$aulaProgPath = FindOne $repo "AulaProgress.tsx"
$debPath = FindOne $repo "DebateBoard.tsx"
$mapPath = FindOne $repo "TerritoryMap.tsx"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] NavPills: " + ($navPath ?? "(não achei)"))
WL ("[DIAG] AulaProgress: " + ($aulaProgPath ?? "(não achei)"))
WL ("[DIAG] DebateBoard: " + ($debPath ?? "(não achei)"))
WL ("[DIAG] TerritoryMap: " + ($mapPath ?? "(não achei)"))

if (-not $navPath) { throw "[STOP] Não achei NavPills.tsx (preciso dele p/ estabilizar)." }
if (-not $aulaProgPath) { throw "[STOP] Não achei AulaProgress.tsx (preciso dele p/ estabilizar)." }
if (-not $debPath) { throw "[STOP] Não achei DebateBoard.tsx (preciso dele p/ estabilizar)." }
if (-not $mapPath) { throw "[STOP] Não achei TerritoryMap.tsx (preciso dele p/ estabilizar)." }

# -------------------------
# PATCH (rewrite com slug opcional + autoinfer)
# -------------------------
BackupFile $navPath
BackupFile $aulaProgPath
BackupFile $debPath
BackupFile $mapPath

$navLines = @(
  '"use client";',
  '',
  'import Link from "next/link";',
  'import { usePathname, useParams } from "next/navigation";',
  '',
  'function resolveSlug(propSlug?: string) {',
  '  const params = useParams() as Record<string, string | string[] | undefined>;',
  '  const v = propSlug ?? params?.slug;',
  '  if (typeof v === "string") return v;',
  '  if (Array.isArray(v) && v.length) return v[0];',
  '  return "";',
  '}',
  '',
  'export default function NavPills({ slug }: { slug?: string }) {',
  '  const s = resolveSlug(slug);',
  '  const pathname = usePathname();',
  '  if (!s) return null;',
  '',
  '  const items = [',
  '    { href: "/c/" + s, label: "Panorama" },',
  '    { href: "/c/" + s + "/trilha", label: "Trilha" },',
  '    { href: "/c/" + s + "/a/1", label: "Aulas" },',
  '    { href: "/c/" + s + "/pratica", label: "Prática" },',
  '    { href: "/c/" + s + "/quiz", label: "Quiz" },',
  '    { href: "/c/" + s + "/debate", label: "Debate" },',
  '    { href: "/c/" + s + "/acervo", label: "Acervo" },',
  '    { href: "/c/" + s + "/mapa", label: "Mapa" },',
  '  ];',
  '',
  '  return (',
  '    <nav className="flex flex-wrap gap-2">',
  '      {items.map((it) => {',
  '        const active = pathname === it.href || pathname?.startsWith(it.href + "/");',
  '        return (',
  '          <Link',
  '            key={it.href}',
  '            href={it.href}',
  '            className={"card px-3 py-2 text-sm transition " + (active ? "border-white/30" : "hover:bg-white/10")}',
  '          >',
  '            <span className={active ? "accent" : ""}>{it.label}</span>',
  '          </Link>',
  '        );',
  '      })}',
  '    </nav>',
  '  );',
  '}'
) -join "`n"
WriteUtf8NoBom $navPath $navLines
WL "[OK] NavPills.tsx reescrito (slug opcional + autoinfer)."

$aulaProgLines = @(
  '"use client";',
  '',
  'import { useMemo, useEffect } from "react";',
  'import { useParams } from "next/navigation";',
  '',
  'function resolveSlug(propSlug?: string) {',
  '  const params = useParams() as Record<string, string | string[] | undefined>;',
  '  const v = propSlug ?? params?.slug;',
  '  if (typeof v === "string") return v;',
  '  if (Array.isArray(v) && v.length) return v[0];',
  '  return "";',
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
  '  const s = resolveSlug(slug);',
  '  const key = useMemo(() => "cv:" + (s || "global") + ":aula:max:v1", [s]);',
  '',
  '  const storedMax = useMemo(() => {',
  '    try {',
  '      const raw = localStorage.getItem(key);',
  '      const n = raw ? Number(raw) : NaN;',
  '      return Number.isFinite(n) ? n : 0;',
  '    } catch {',
  '      return 0;',
  '    }',
  '  }, [key]);',
  '',
  '  const maxVisited = Math.max(storedMax, current);',
  '',
  '  useEffect(() => {',
  '    try { localStorage.setItem(key, String(maxVisited)); } catch {}',
  '  }, [key, maxVisited]);',
  '',
  '  const pct = total > 0 ? Math.round((maxVisited / total) * 100) : 0;',
  '',
  '  return (',
  '    <div className="card p-4">',
  '      <div className="flex items-center justify-between gap-3">',
  '        <div className="text-sm muted">Progresso</div>',
  '        <div className="text-sm"><span className="accent">{maxVisited}</span><span className="muted">/</span>{total}</div>',
  '      </div>',
  '      <div className="mt-3 h-2 w-full rounded-full bg-white/10 overflow-hidden">',
  '        <div className="h-2 bg-white/30" style={{ width: pct + "%" }} />',
  '      </div>',
  '      <div className="mt-2 text-xs muted">{pct}% concluído (no seu aparelho)</div>',
  '    </div>',
  '  );',
  '}'
) -join "`n"
WriteUtf8NoBom $aulaProgPath $aulaProgLines
WL "[OK] AulaProgress.tsx reescrito (sem state em effect; slug opcional)."

# DebateBoard: mantém estrutura mas torna slug opcional + autoinfer
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
  'function resolveSlug(propSlug?: string) {',
  '  const params = useParams() as Record<string, string | string[] | undefined>;',
  '  const v = propSlug ?? params?.slug;',
  '  if (typeof v === "string") return v;',
  '  if (Array.isArray(v) && v.length) return v[0];',
  '  return "";',
  '}',
  '',
  'function keyFor(slug: string) {',
  '  return `cv:${slug || "global"}:debate:v1`;',
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
  '  const s = resolveSlug(slug);',
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
  '      localStorage.setItem(k, JSON.stringify(data));',
  '      setStatus("salvo");',
  '      setTimeout(() => setStatus(""), 1200);',
  '    } catch {}',
  '  };',
  '',
  '  const copy = async () => {',
  '    try {',
  '      const payload = { slug: s || slug || "", answers, pedidoConcreto, acaoAjudaMutua };',
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
  '    try { localStorage.removeItem(k); } catch {}',
  '  };',
  '',
  '  return (',
  '    <div className="space-y-4">',
  '      <div className="card p-5">',
  '        <h3 className="text-lg font-semibold">Sem tribunal</h3>',
  '        <p className="muted mt-2">',
  '          Debate aqui é ferramenta de cuidado e organização: diagnóstico estrutural,',
  '          linguagem concreta, e saída prática.',
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
) -join "`n"
WriteUtf8NoBom $debPath $debLines
WL "[OK] DebateBoard.tsx reescrito (slug opcional + autoinfer)."

# TerritoryMap: só estabiliza contrato (slug opcional)
$mapLines = @(
  '"use client";',
  '',
  'import { useMemo, useState } from "react";',
  'import { useParams } from "next/navigation";',
  '',
  'export type MapPoint = {',
  '  id: string;',
  '  title: string;',
  '  kind?: string;',
  '  lat?: number;',
  '  lng?: number;',
  '  desc?: string;',
  '  tags?: string[];',
  '  href?: string;',
  '};',
  '',
  'function resolveSlug(propSlug?: string) {',
  '  const params = useParams() as Record<string, string | string[] | undefined>;',
  '  const v = propSlug ?? params?.slug;',
  '  if (typeof v === "string") return v;',
  '  if (Array.isArray(v) && v.length) return v[0];',
  '  return "";',
  '}',
  '',
  'function osmLink(p: MapPoint) {',
  '  if (typeof p.lat === "number" && typeof p.lng === "number") {',
  '    const lat = String(p.lat);',
  '    const lng = String(p.lng);',
  '    return "https://www.openstreetmap.org/?mlat=" + lat + "&mlon=" + lng + "#map=18/" + lat + "/" + lng;',
  '  }',
  '  return "";',
  '}',
  '',
  'export default function TerritoryMap({ slug, points }: { slug?: string; points: MapPoint[] }) {',
  '  const s = resolveSlug(slug);',
  '  const kinds = useMemo(() => {',
  '    const set = new Set<string>();',
  '    for (const p of points) { if (p.kind) set.add(p.kind); }',
  '    return Array.from(set).sort();',
  '  }, [points]);',
  '',
  '  const [filter, setFilter] = useState<string>("");',
  '',
  '  const view = useMemo(() => {',
  '    if (!filter) return points;',
  '    return points.filter((p) => (p.kind || "") === filter);',
  '  }, [points, filter]);',
  '',
  '  return (',
  '    <div className="card p-5">',
  '      <div className="flex flex-wrap items-center justify-between gap-3">',
  '        <div>',
  '          <h3 className="text-lg font-semibold">Território</h3>',
  '          <div className="text-xs muted">Camadas simples (lista) — depois a gente evolui p/ mapa visual.</div>',
  '        </div>',
  '        <div className="text-xs muted">slug: <span className="accent">{s || "global"}</span></div>',
  '      </div>',
  '',
  '      {kinds.length > 0 && (',
  '        <div className="mt-4 flex flex-wrap gap-2">',
  '          <button className={"card px-3 py-2 text-sm " + (!filter ? "border-white/30" : "hover:bg-white/10")} onClick={() => setFilter("")}>',
  '            <span className={!filter ? "accent" : ""}>Tudo</span>',
  '          </button>',
  '          {kinds.map((k) => (',
  '            <button key={k} className={"card px-3 py-2 text-sm " + (filter === k ? "border-white/30" : "hover:bg-white/10")} onClick={() => setFilter(k)}>',
  '              <span className={filter === k ? "accent" : ""}>{k}</span>',
  '            </button>',
  '          ))}',
  '        </div>',
  '      )}',
  '',
  '      <div className="mt-4 grid gap-3">',
  '        {view.map((p) => {',
  '          const link = p.href || osmLink(p);',
  '          return (',
  '            <div key={p.id} className="card p-4">',
  '              <div className="flex items-start justify-between gap-3">',
  '                <div>',
  '                  <div className="text-xs muted">{p.kind || "ponto"}</div>',
  '                  <div className="font-semibold mt-1">{p.title}</div>',
  '                  {p.desc && <div className="muted mt-2 whitespace-pre-wrap">{p.desc}</div>}',
  '                  {p.tags && p.tags.length > 0 && (',
  '                    <div className="mt-2 flex flex-wrap gap-2">',
  '                      {p.tags.map((t) => (',
  '                        <span key={t} className="text-xs rounded-full border border-white/10 bg-black/20 px-2 py-1 muted">{t}</span>',
  '                      ))}',
  '                    </div>',
  '                  )}',
  '                </div>',
  '                {link ? (',
  '                  <a className="text-sm accent hover:underline" href={link} target="_blank" rel="noreferrer">Abrir</a>',
  '                ) : null}',
  '              </div>',
  '            </div>',
  '          );',
  '        })}',
  '      </div>',
  '    </div>',
  '  );',
  '}'
) -join "`n"
WriteUtf8NoBom $mapPath $mapLines
WL "[OK] TerritoryMap.tsx reescrito (slug opcional + autoinfer)."

# -------------------------
# REPORT
# -------------------------
$repDir = Join-Path $repo "reports"
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repDir "cv-3k-stabilize-slug-autoinfer.md"

$r = New-Object System.Collections.Generic.List[string]
$r.Add("# CV-3k — Stabilize slug autoinfer — " + $now)
$r.Add("")
$r.Add("## O que mudou")
$r.Add("- NavPills / AulaProgress / DebateBoard / TerritoryMap: `slug` virou opcional e é inferido via `useParams()` quando não é passado.")
$r.Add("- Isso elimina o whack-a-mole de TypeScript (`Property 'slug' is missing...`).")
$r.Add("")
$r.Add("## Arquivos")
$r.Add("- " + $navPath)
$r.Add("- " + $aulaProgPath)
$r.Add("- " + $debPath)
$r.Add("- " + $mapPath)
$r.Add("")
$r.Add("## Verify")
$r.Add("- npm run lint")
$r.Add("- npm run build")

WriteUtf8NoBom $reportPath ($r -join "`n")
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

WL "[OK] CV-3k aplicado. Agora esses componentes não quebram build se esquecer slug."