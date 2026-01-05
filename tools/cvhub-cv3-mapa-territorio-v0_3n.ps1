param(
  [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function WL([string]$s) { Write-Host $s }

function EnsureDir([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

function WriteUtf8NoBom([string]$p, [string]$content) {
  $parent = Split-Path -Parent $p
  if ($parent) { EnsureDir $parent }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($p, $content, $enc)
}

function WriteFileLines([string]$p, [string[]]$lines) {
  WriteUtf8NoBom $p ($lines -join "`n")
}

function BackupFile([string]$p) {
  if (Test-Path -LiteralPath $p) {
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
  if (Test-Path -LiteralPath (Join-Path $here "package.json")) { return $here }
  $p1 = Split-Path -Parent $here
  if ($p1 -and (Test-Path -LiteralPath (Join-Path $p1 "package.json"))) { return $p1 }
  throw ("[STOP] Rode na raiz do repo (onde tem package.json). Atual: " + $here)
}

# -------------------------
# DIAG
# -------------------------
$repo = ResolveRepoHere
$npmExe = ResolveExe "npm.cmd"

$mapPage = Join-Path $repo "src\app\c\[slug]\mapa\page.tsx"
$mapDir  = Split-Path -Parent $mapPage
$mapComp = Join-Path $repo "src\components\TerritoryMap.tsx"

$contentRoot = Join-Path $repo "content\cadernos"
$polRoot = Join-Path $contentRoot "poluicao-vr"
$polMapJson = Join-Path $polRoot "mapa.json"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] map page: " + $mapPage)
WL ("[DIAG] map comp: " + $mapComp)
WL ("[DIAG] content root: " + $contentRoot)

# -------------------------
# PATCH: TerritoryMap.tsx
# -------------------------
EnsureDir (Split-Path -Parent $mapComp)
BackupFile $mapComp

$compLines = @(
  '"use client";',
  '',
  'import { useMemo, useState } from "react";',
  '',
  'export type MapPoint = {',
  '  id: string;',
  '  title: string;',
  '  kind:',
  '    | "industrial"',
  '    | "agua"',
  '    | "saude"',
  '    | "transporte"',
  '    | "moradia"',
  '    | "educacao"',
  '    | "memoria"',
  '    | "ponto-critico"',
  '    | "mutirao";',
  '  x: number; // 0..100',
  '  y: number; // 0..100',
  '  address?: string;',
  '  note?: string;',
  '  links?: { label: string; href: string }[];',
  '};',
  '',
  'type Props = { slug: string; points: MapPoint[] };',
  '',
  'function kindLabel(k: MapPoint["kind"]) {',
  '  switch (k) {',
  '    case "industrial": return "Industrial";',
  '    case "agua": return "Água";',
  '    case "saude": return "Saúde";',
  '    case "transporte": return "Transporte";',
  '    case "moradia": return "Moradia";',
  '    case "educacao": return "Educação";',
  '    case "memoria": return "Memória";',
  '    case "ponto-critico": return "Ponto crítico";',
  '    case "mutirao": return "Mutirão";',
  '    default: return "Ponto";',
  '  }',
  '}',
  '',
  'export default function TerritoryMap({ slug, points }: Props) {',
  '  const [q, setQ] = useState("");',
  '  const [kind, setKind] = useState<MapPoint["kind"] | "">("");',
  '  const [selectedId, setSelectedId] = useState<string>("");',
  '  const [mode, setMode] = useState<"mapa" | "lista">("mapa");',
  '  const [status, setStatus] = useState<"" | "copiado">("");',
  '',
  '  const kinds = useMemo(() => {',
  '    const s = new Set<MapPoint["kind"]>();',
  '    for (const p of points) s.add(p.kind);',
  '    return Array.from(s);',
  '  }, [points]);',
  '',
  '  const filtered = useMemo(() => {',
  '    const qq = q.trim().toLowerCase();',
  '    return points.filter((p) => {',
  '      if (kind && p.kind !== kind) return false;',
  '      if (!qq) return true;',
  '      const hay = (p.title + " " + (p.address || "") + " " + (p.note || "")).toLowerCase();',
  '      return hay.includes(qq);',
  '    });',
  '  }, [points, q, kind]);',
  '',
  '  const selected = useMemo(() => {',
  '    if (!selectedId) return undefined;',
  '    return points.find((p) => p.id === selectedId);',
  '  }, [points, selectedId]);',
  '',
  '  const copyLink = async (id: string) => {',
  '    try {',
  '      const href = window.location.origin + "/c/" + slug + "/mapa#" + id;',
  '      await navigator.clipboard.writeText(href);',
  '      setStatus("copiado");',
  '      setTimeout(() => setStatus(""), 1200);',
  '    } catch {}',
  '  };',
  '',
  '  return (',
  '    <section className="card p-5 space-y-4">',
  '      <div className="flex flex-wrap gap-2 items-center justify-between">',
  '        <div>',
  '          <h2 className="text-xl font-semibold">Mapa do território</h2>',
  '          <p className="muted mt-1">Pontos de impacto e memória. Sem espetáculo: foco em cuidado e organização.</p>',
  '        </div>',
  '        <div className="flex gap-2">',
  '          <button className="card px-3 py-2 hover:bg-white/10 transition" onClick={() => setMode("mapa")}>Mapa</button>',
  '          <button className="card px-3 py-2 hover:bg-white/10 transition" onClick={() => setMode("lista")}>Lista</button>',
  '        </div>',
  '      </div>',
  '',
  '      <div className="grid gap-2 md:grid-cols-3">',
  '        <div className="md:col-span-2">',
  '          <input',
  '            className="w-full rounded-xl border border-white/10 bg-black/20 p-3 outline-none focus:border-white/20"',
  '            value={q}',
  '            onChange={(e) => setQ(e.target.value)}',
  '            placeholder="Buscar (ex.: rio, CSN, hospital, bairro...)"',
  '          />',
  '        </div>',
  '        <div>',
  '          <select',
  '            className="w-full rounded-xl border border-white/10 bg-black/20 p-3 outline-none focus:border-white/20"',
  '            value={kind}',
  '            onChange={(e) => setKind((e.target.value as any) || "")}',
  '          >',
  '            <option value="">Todas as categorias</option>',
  '            {kinds.map((k) => (',
  '              <option key={k} value={k}>{kindLabel(k)}</option>',
  '            ))}',
  '          </select>',
  '        </div>',
  '      </div>',
  '',
  '      {mode === "mapa" ? (',
  '        <div className="rounded-2xl border border-white/10 bg-black/20 p-4">',
  '          <div className="text-sm muted mb-3">Clique nos pontos. Coordenadas são abstratas (0..100), só para leitura do território.</div>',
  '          <div className="relative w-full" style={{ height: 420 }}>',
  '            <div className="absolute inset-0 rounded-2xl border border-white/10 bg-gradient-to-b from-black/20 to-black/50" />',
  '            {filtered.map((p) => (',
  '              <button',
  '                key={p.id}',
  '                className="absolute -translate-x-1/2 -translate-y-1/2 rounded-full border border-white/30 bg-white/10 hover:bg-white/20 transition"',
  '                style={{ left: p.x + "%", top: p.y + "%", width: 14, height: 14 }}',
  '                title={p.title}',
  '                onClick={() => setSelectedId(p.id)}',
  '              />',
  '            ))}',
  '          </div>',
  '          <div className="mt-3 text-xs muted">Mostrando {filtered.length} / {points.length} pontos.</div>',
  '        </div>',
  '      ) : (',
  '        <div className="grid gap-2">',
  '          {filtered.map((p) => (',
  '            <button key={p.id} className="card p-4 text-left hover:bg-white/10 transition" onClick={() => setSelectedId(p.id)}>',
  '              <div className="flex items-center justify-between gap-3">',
  '                <div className="font-semibold">{p.title}</div>',
  '                <div className="text-xs muted">{kindLabel(p.kind)}</div>',
  '              </div>',
  '              {p.note ? <div className="muted mt-1 text-sm">{p.note}</div> : null}',
  '            </button>',
  '          ))}',
  '          <div className="text-xs muted">Mostrando {filtered.length} / {points.length} pontos.</div>',
  '        </div>',
  '      )}',
  '',
  '      {selected ? (',
  '        <div className="card p-5">',
  '          <div className="flex flex-wrap items-center justify-between gap-2">',
  '            <div>',
  '              <div className="text-xs muted">{selected.id} • {kindLabel(selected.kind)}</div>',
  '              <div className="text-lg font-semibold mt-1">{selected.title}</div>',
  '              {selected.address ? <div className="muted mt-1">{selected.address}</div> : null}',
  '            </div>',
  '            <button className="card px-3 py-2 hover:bg-white/10 transition" onClick={() => copyLink(selected.id)}>',
  '              <span className="accent">{status === "copiado" ? "Link copiado!" : "Copiar link"}</span>',
  '            </button>',
  '          </div>',
  '          {selected.note ? <p className="muted mt-3 whitespace-pre-wrap">{selected.note}</p> : null}',
  '          {selected.links && selected.links.length ? (',
  '            <div className="mt-4 grid gap-2">',
  '              {selected.links.map((l) => (',
  '                <a key={l.href} className="card px-3 py-2 hover:bg-white/10 transition" href={l.href} target="_blank" rel="noreferrer">',
  '                  {l.label}',
  '                </a>',
  '              ))}',
  '            </div>',
  '          ) : null}',
  '        </div>',
  '      ) : null}',
  '    </section>',
  '  );',
  '}'
)

WriteFileLines $mapComp $compLines
WL ("[OK] wrote: " + $mapComp)

# -------------------------
# PATCH: /c/[slug]/mapa/page.tsx
# -------------------------
EnsureDir $mapDir
BackupFile $mapPage

$pageLines = @(
  'import fs from "fs/promises";',
  'import path from "path";',
  'import type { CSSProperties } from "react";',
  '',
  'import CadernoHeader, { NavPills } from "@/components/CadernoHeader";',
  'import TerritoryMap from "@/components/TerritoryMap";',
  'import type { MapPoint } from "@/components/TerritoryMap";',
  'import { getCaderno } from "@/lib/cadernos";',
  '',
  'type AccentStyle = CSSProperties & { ["--accent"]?: string };',
  '',
  'async function readPoints(slug: string): Promise<MapPoint[]> {',
  '  const p = path.join(process.cwd(), "content", "cadernos", slug, "mapa.json");',
  '  try {',
  '    const raw = await fs.readFile(p, "utf8");',
  '    const data = JSON.parse(raw) as unknown;',
  '    if (!Array.isArray(data)) return [];',
  '    return data as MapPoint[];',
  '  } catch {',
  '    return [];',
  '  }',
  '}',
  '',
  'export default async function Page({ params }: { params: Promise<{ slug: string }> }) {',
  '  const { slug } = await params;',
  '  const data = await getCaderno(slug);',
  '  const points = await readPoints(slug);',
  '  const s: AccentStyle = { ["--accent"]: data.meta.accent };',
  '',
  '  return (',
  '    <main className="space-y-5" style={s}>',
  '      <CadernoHeader title={data.meta.title} subtitle={data.meta.subtitle} ethos={data.meta.ethos} />',
  '      <NavPills slug={slug} />',
  '      <TerritoryMap slug={slug} points={points} />',
  '    </main>',
  '  );',
  '}'
)

WriteFileLines $mapPage $pageLines
WL ("[OK] wrote: " + $mapPage)

# -------------------------
# PATCH: seed mapa.json
# -------------------------
if (Test-Path -LiteralPath $contentRoot) {
  if (Test-Path -LiteralPath $polRoot) {
    if (-not (Test-Path -LiteralPath $polMapJson)) {
      BackupFile $polMapJson
      $seed = @(
        '{',
        '  "meta": "mapa.json é uma lista (array) de pontos. x/y são 0..100 (abstrato).",',
        '  "note": "Remova as chaves meta/note se quiser; o loader ignora não-array e retorna [].",',
        '  "points": []',
        '}'
      ) -join "`n"
      # A UI espera um ARRAY. Vamos escrever array direto (sem wrapper).
      $arr = @(
        '[',
        '  {',
        '    "id": "csn-upv",',
        '    "title": "CSN / Usina (UPV)",',
        '    "kind": "industrial",',
        '    "x": 62,',
        '    "y": 46,',
        '    "address": "Volta Redonda",',
        '    "note": "Ponto estruturante da cidade: trabalho, poluição, saúde do trabalhador, e disputa por governança.",',
        '    "links": [',
        '      { "label": "Abrir caderno (Panorama)", "href": "/c/poluicao-vr" }',
        '    ]',
        '  },',
        '  {',
        '    "id": "rio-paraiba",',
        '    "title": "Rio Paraíba do Sul",',
        '    "kind": "agua",',
        '    "x": 40,',
        '    "y": 64,',
        '    "address": "Eixo hídrico regional",',
        '    "note": "Água como infraestrutura: risco ambiental, abastecimento e impacto acumulado.",',
        '    "links": []',
        '  },',
        '  {',
        '    "id": "hospital-sus",',
        '    "title": "Rede SUS / Hospitais",',
        '    "kind": "saude",',
        '    "x": 32,',
        '    "y": 40,',
        '    "address": "Volta Redonda",',
        '    "note": "A cidade respira e adoece no mesmo território. Saúde pública é parte do mapa.",',
        '    "links": []',
        '  },',
        '  {',
        '    "id": "bairros-vulneraveis",',
        '    "title": "Bairros mais expostos",',
        '    "kind": "moradia",',
        '    "x": 52,',
        '    "y": 28,',
        '    "address": "Várias áreas",',
        '    "note": "Onde o vento leva, quem mora perto, quem trabalha dentro. Território é desigual.",',
        '    "links": []',
        '  },',
        '  {',
        '    "id": "rodovias-onibus",',
        '    "title": "Eixos de transporte e deslocamento",',
        '    "kind": "transporte",',
        '    "x": 70,',
        '    "y": 72,',
        '    "address": "Linhas / rodovias",',
        '    "note": "Mobilidade é saúde: tempo de vida, acesso ao cuidado e ao trabalho.",',
        '    "links": []',
        '  }',
        ']'
      ) -join "`n"
      EnsureDir $polRoot
      WriteUtf8NoBom $polMapJson $arr
      WL ("[OK] seed: " + $polMapJson)
    } else {
      WL ("[OK] mapa.json já existe: " + $polMapJson)
    }
  } else {
    WL "[WARN] Não achei content/cadernos/poluicao-vr (seed pulado)."
  }
} else {
  WL "[WARN] Não achei pasta content/cadernos (seed pulado)."
}

# -------------------------
# REPORT
# -------------------------
$repDir = Join-Path $repo "reports"
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repDir "cv-3-mapa-territorio-v0_3n.md"

$rl = @()
$rl += "# CV-3 — Mapa do território (v0.3n) — " + $now
$rl += ""
$rl += "## O que foi feito"
$rl += "- Criou/reescreveu src/components/TerritoryMap.tsx (client, slug obrigatório, filtro + busca + modal)"
$rl += "- Criou/reescreveu rota src/app/c/[slug]/mapa/page.tsx (Next 16 params async)"
$rl += "- Seed opcional: content/cadernos/poluicao-vr/mapa.json (se não existia)"
$rl += ""
$rl += "## Verify"
$rl += "- npm run lint"
$rl += "- npm run build"
$rl += ""
$rl += "## Como testar"
$rl += "- npm run dev"
$rl += "- Abrir: /c/poluicao-vr/mapa"
WriteUtf8NoBom $reportPath ($rl -join "`n")
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
WL "[OK] CV-3 v0.3n pronto. Teste em /c/poluicao-vr/mapa"