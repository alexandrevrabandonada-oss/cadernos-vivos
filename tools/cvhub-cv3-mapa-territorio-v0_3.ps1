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

function ReadText([string]$p) {
  if (-not (TestP $p)) { return "" }
  return [System.IO.File]::ReadAllText($p)
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

function ResolveAppRoot([string]$repo) {
  $a = Join-Path $repo "src\app"
  if (TestP $a) { return $a }
  $b = Join-Path $repo "app"
  if (TestP $b) { return $b }
  throw ("[STOP] Não achei app root (src\app ou app). Repo: " + $repo)
}

function InsertAfterNeedle([string]$raw, [string]$needle, [string]$insert) {
  $i = $raw.IndexOf($needle)
  if ($i -lt 0) { return $raw }
  $j = $i + $needle.Length
  return ($raw.Substring(0, $j) + $insert + $raw.Substring($j))
}

function InsertBeforeLast([string]$raw, [string]$needle, [string]$insert) {
  $i = $raw.LastIndexOf($needle)
  if ($i -lt 0) { return $raw + $insert }
  return ($raw.Substring(0, $i) + $insert + $raw.Substring($i))
}

# -------------------------
# DIAG
# -------------------------
$repo = ResolveRepoHere
$appRoot = ResolveAppRoot $repo
$npmExe = ResolveExe "npm.cmd"

$componentsDir = Join-Path $repo "src\components"
EnsureDir $componentsDir

$territoryPath = Join-Path $componentsDir "TerritoryMap.tsx"
$headerPath = Join-Path $componentsDir "CadernoHeader.tsx"

$mapPageDir = Join-Path $appRoot "c\[slug]\mapa"
$mapPagePath = Join-Path $mapPageDir "page.tsx"

$contentMapPath = Join-Path $repo "content\cadernos\poluicao-vr\mapa.json"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] AppRoot: " + $appRoot)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] TerritoryMap: " + $territoryPath)
WL ("[DIAG] Mapa page: " + $mapPagePath)
WL ("[DIAG] Seed mapa.json: " + $contentMapPath)

# -------------------------
# PATCH 1/3 — TerritoryMap.tsx
# -------------------------
BackupFile $territoryPath

$territory = @(
'"use client";',
'',
'import Link from "next/link";',
'import { useMemo, useState } from "react";',
'',
'export type MapLink = { label: string; href: string };',
'',
'export type MapPoint = {',
'  id: string;',
'  title: string;',
'  category: string;',
'  summary?: string;',
'  lat?: number;',
'  lng?: number;',
'  x?: number; // 0..100 (para mapa-imagem futuro)',
'  y?: number; // 0..100 (para mapa-imagem futuro)',
'  links?: MapLink[];',
'};',
'',
'function clamp(n: number, a: number, b: number) {',
'  return Math.max(a, Math.min(b, n));',
'}',
'',
'function osmEmbed(lat: number, lng: number) {',
'  const d = 0.01;',
'  const left = lng - d;',
'  const right = lng + d;',
'  const top = lat + d;',
'  const bottom = lat - d;',
'  const bbox = `${left},${bottom},${right},${top}`;',
'  return `https://www.openstreetmap.org/export/embed.html?bbox=${encodeURIComponent(bbox)}&layer=mapnik&marker=${lat}%2C${lng}`;',
'}',
'',
'function osmLink(lat: number, lng: number) {',
'  const z = 16;',
'  return `https://www.openstreetmap.org/?mlat=${lat}&mlon=${lng}#map=${z}/${lat}/${lng}`;',
'}',
'',
'export default function TerritoryMap({',
'  slug,',
'  points,',
'}: {',
'  slug: string;',
'  points: MapPoint[];',
'}) {',
'  const cats = useMemo(() => {',
'    const s = new Set<string>();',
'    points.forEach((p) => s.add(p.category || "Geral"));',
'    return ["Tudo", ...Array.from(s).sort((a, b) => a.localeCompare(b))];',
'  }, [points]);',
'',
'  const [cat, setCat] = useState("Tudo");',
'  const filtered = useMemo(() => {',
'    if (cat === "Tudo") return points;',
'    return points.filter((p) => (p.category || "Geral") === cat);',
'  }, [points, cat]);',
'',
'  const [selId, setSelId] = useState<string>(() => (points[0]?.id ? points[0].id : ""));',
'  const selected = useMemo(() => filtered.find((p) => p.id === selId) || filtered[0], [filtered, selId]);',
'',
'  const hasCoords = !!(selected && typeof selected.lat === "number" && typeof selected.lng === "number");',
'  const lat = hasCoords ? clamp(selected!.lat as number, -90, 90) : -22.52;',
'  const lng = hasCoords ? clamp(selected!.lng as number, -180, 180) : -44.10;',
'',
'  return (',
'    <section className="grid gap-4 lg:grid-cols-[360px_1fr]">',
'      <div className="space-y-4">',
'        <div className="card p-5">',
'          <h3 className="text-lg font-semibold">Filtros</h3>',
'          <div className="mt-3 flex flex-wrap gap-2">',
'            {cats.map((c) => (',
'              <button',
'                key={c}',
'                onClick={() => {',
'                  setCat(c);',
'                  setSelId("");',
'                }}',
'                className={"card px-3 py-2 transition hover:bg-white/10 " + (cat === c ? "border-white/30" : "")}',
'              >',
'                <span className="accent">{c}</span>',
'              </button>',
'            ))}',
'          </div>',
'          <p className="muted text-sm mt-3">',
'            Mapa aqui é ferramenta de leitura do território: organizar fatos, conectar pontos,',
'            e transformar em pedido concreto + ação simples.',
'          </p>',
'        </div>',
'',
'        <div className="card p-5">',
'          <h3 className="text-lg font-semibold">Pontos</h3>',
'          {filtered.length === 0 ? (',
'            <p className="muted mt-2">Sem pontos nessa categoria.</p>',
'          ) : (',
'            <div className="mt-3 grid gap-2">',
'              {filtered.map((p) => (',
'                <button',
'                  key={p.id}',
'                  onClick={() => setSelId(p.id)}',
'                  className={"text-left card p-3 hover:bg-white/10 transition " + (selected?.id === p.id ? "border-white/30" : "")}',
'                >',
'                  <div className="text-xs muted">{p.category}</div>',
'                  <div className="font-semibold">{p.title}</div>',
'                  {p.summary ? <div className="muted text-sm mt-1">{p.summary}</div> : null}',
'                </button>',
'              ))}',
'            </div>',
'          )}',
'',
'          <div className="mt-4 text-sm muted">',
'            Edita os pontos em: <code className="muted">content/cadernos/{slug}/mapa.json</code>',
'          </div>',
'        </div>',
'      </div>',
'',
'      <div className="space-y-4">',
'        <div className="card p-5">',
'          <div className="flex flex-wrap items-center justify-between gap-3">',
'            <div>',
'              <div className="text-xs muted">{selected?.category || "Geral"}</div>',
'              <h3 className="text-xl font-semibold">{selected?.title || "Mapa do território"}</h3>',
'            </div>',
'            <div className="flex flex-wrap gap-2">',
'              <Link className="card px-3 py-2 hover:bg-white/10 transition" href={`/c/${slug}`}>',
'                <span className="accent">Voltar ao caderno</span>',
'              </Link>',
'              {hasCoords ? (',
'                <a className="card px-3 py-2 hover:bg-white/10 transition" href={osmLink(lat, lng)} target="_blank" rel="noreferrer">',
'                  <span className="accent">Abrir no OSM</span>',
'                </a>',
'              ) : null}',
'            </div>',
'          </div>',
'',
'          {selected?.summary ? <p className="muted mt-3">{selected.summary}</p> : null}',
'',
'          {selected?.links && selected.links.length ? (',
'            <div className="mt-4 flex flex-wrap gap-2">',
'              {selected.links.map((l) => (',
'                <a key={l.href} className="card px-3 py-2 hover:bg-white/10 transition" href={l.href} target="_blank" rel="noreferrer">',
'                  <span className="accent">{l.label}</span>',
'                </a>',
'              ))}',
'            </div>',
'          ) : null}',
'        </div>',
'',
'        <div className="card p-2 overflow-hidden">',
'          <div className="muted text-sm px-4 pt-3">',
'            {hasCoords ? "Mapa (OSM embed) do ponto selecionado" : "Sem coordenadas nesse ponto (adicione lat/lng no mapa.json)"}',
'          </div>',
'          <div className="mt-3 aspect-[16/10] w-full">',
'            <iframe',
'              title="Mapa" ',
'              className="h-full w-full border-0 opacity-95" ',
'              src={osmEmbed(lat, lng)}',
'              loading="lazy"',
'            />',
'          </div>',
'        </div>',
'',
'        <div className="card p-5">',
'          <h3 className="text-lg font-semibold">Fechamento</h3>',
'          <p className="muted mt-2">',
'            1) O que esse ponto prova/indica (sem pânico). 2) O que ele conecta (cadeia).',
'            3) Qual pedido concreto nasce daqui. 4) Qual ação simples de ajuda mútua dá pra fazer hoje.',
'          </p>',
'        </div>',
'      </div>',
'    </section>',
'  );',
'}',
''
) -join "`n"

WriteUtf8NoBom $territoryPath $territory
WL "[OK] wrote: src/components/TerritoryMap.tsx"

# -------------------------
# PATCH 2/3 — /c/[slug]/mapa/page.tsx
# -------------------------
EnsureDir $mapPageDir
BackupFile $mapPagePath

$mapPage = @(
'import type { CSSProperties } from "react";',
'import fs from "fs/promises";',
'import path from "path";',
'',
'import CadernoHeader from "@/components/CadernoHeader";',
'import TerritoryMap from "@/components/TerritoryMap";',
'import type { MapPoint } from "@/components/TerritoryMap";',
'import { getCaderno } from "@/lib/cadernos";',
'',
'type AccentStyle = CSSProperties & { ["--accent"]?: string };',
'type Params = Promise<{ slug: string }> | { slug: string };',
'',
'async function loadPoints(slug: string): Promise<MapPoint[]> {',
'  try {',
'    const p = path.join(process.cwd(), "content", "cadernos", slug, "mapa.json");',
'    const raw = await fs.readFile(p, "utf8");',
'    const data = JSON.parse(raw) as { points?: MapPoint[] };',
'    return Array.isArray(data.points) ? data.points : [];',
'  } catch {',
'    return [];',
'  }',
'}',
'',
'export default async function Page({ params }: { params: Params }) {',
'  const { slug } = await params;',
'  const data = await getCaderno(slug);',
'  const points = await loadPoints(slug);',
'  const s: AccentStyle = { ["--accent"]: data.meta.accent };',
'',
'  return (',
'    <main className="space-y-5" style={s}>',
'      <CadernoHeader slug={slug} title={data.meta.title} subtitle={data.meta.subtitle} />',
'',
'      <section className="card p-5">',
'        <h2 className="text-xl font-semibold">Mapa do território</h2>',
'        <p className="muted mt-2">',
'          Uma cartografia prática: pontos, cadeias e conexões. Sem moralismo — com saída.',
'        </p>',
'        <p className="muted text-sm mt-3">',
'          Dica: comece com poucos pontos, mas bem nomeados. Depois a gente evolui para camadas e “reincidência”.',
'        </p>',
'      </section>',
'',
'      <TerritoryMap slug={slug} points={points} />',
'    </main>',
'  );',
'}',
''
) -join "`n"

WriteUtf8NoBom $mapPagePath $mapPage
WL "[OK] wrote: /c/[slug]/mapa/page.tsx"

# -------------------------
# PATCH 3/3 — adiciona aba "Mapa" no CadernoHeader (se existir)
# -------------------------
if (TestP $headerPath) {
  $raw = ReadText $headerPath
  if ($raw -and ($raw.IndexOf('label: "Mapa"') -lt 0) -and ($raw.IndexOf('label:"Mapa"') -lt 0)) {
    BackupFile $headerPath

    $insertObj = "`n    { href: `/c/`${slug}`/mapa`, label: `"Mapa`" },"
    $insertObj = $insertObj.Replace('`/c/`${slug}`/mapa', '/c/${slug}/mapa') # garante template literal correto no TSX

    if ($raw.IndexOf('label: "Acervo"') -ge 0) {
      $raw2 = InsertAfterNeedle $raw 'label: "Acervo"' $insertObj
    } else {
      $raw2 = InsertBeforeLast $raw '];' ("  " + $insertObj + "`n")
    }

    WriteUtf8NoBom $headerPath $raw2
    WL "[OK] patched: CadernoHeader.tsx (aba Mapa)"
  } else {
    WL "[OK] CadernoHeader já tem Mapa (ou não dá pra detectar com segurança)."
  }
} else {
  WL "[WARN] Não achei CadernoHeader.tsx em src/components. (Sem problema: a rota /mapa funciona.)"
}

# -------------------------
# SEED — content/cadernos/poluicao-vr/mapa.json (se não existir)
# -------------------------
if (-not (TestP $contentMapPath)) {
  EnsureDir (Split-Path -Parent $contentMapPath)

  $seed = @(
'{',
'  "points": [',
'    {',
'      "id": "centro-vr",',
'      "title": "Centro de Volta Redonda (referência geral)",',
'      "category": "Referência",',
'      "summary": "Ponto de referência para começar o mapa. Ajuste/adicione outros pontos com calma.",',
'      "lat": -22.5200,',
'      "lng": -44.1040,',
'      "links": [',
'        { "label": "OSM (VR)", "href": "https://www.openstreetmap.org/search?query=Volta%20Redonda%20RJ" }',
'      ]',
'    },',
'    {',
'      "id": "rio-paraiba",',
'      "title": "Rio Paraíba do Sul (trecho urbano — referência)",',
'      "category": "Água",',
'      "summary": "Use esse ponto como gancho para discutir risco hídrico, poeira/assoreamento, e impactos cumulativos.",',
'      "lat": -22.5150,',
'      "lng": -44.1100',
'    }',
'  ]',
'}',
''
) -join "`n"

  WriteUtf8NoBom $contentMapPath $seed
  WL "[OK] seed: content/cadernos/poluicao-vr/mapa.json"
} else {
  WL "[OK] seed já existe: mapa.json"
}

# -------------------------
# REPORT
# -------------------------
$repDir = Join-Path $repo "reports"
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repDir "cv-3-mapa-territorio-v0_3.md"

$report = @(
  ("# CV-3 — Mapa do Território — " + $now),
  "",
  "## O que entrou",
  "- Nova rota: `/c/[slug]/mapa`",
  "- Novo componente: `src/components/TerritoryMap.tsx` (client, sem libs)",
  "- Leitura de `content/cadernos/<slug>/mapa.json` (opcional; se faltar, fica vazio)",
  "- Seed: `content/cadernos/poluicao-vr/mapa.json` (2 pontos de referência)",
  "",
  "## Próximo tijolo (CV-4)",
  "- Camadas do mapa (Abandono x Cuidado), dedupe e histórico (reincidência) + export para card/share."
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
WL "[OK] CV-3 pronto."
WL "[NEXT] Rode: npm run dev  | abra: /c/poluicao-vr/mapa"