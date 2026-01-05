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

function WriteLines([string]$p, [string[]]$lines) {
  $content = ($lines -join "`n")
  WriteUtf8NoBom $p $content
}

# -------------------------
# DIAG
# -------------------------
$repo = ResolveRepoHere
$npmExe = ResolveExe "npm.cmd"

$src = Join-Path $repo "src"
$app = Join-Path $src "app"
$lib = Join-Path $src "lib"
$repDir = Join-Path $repo "reports"

$libIndex = Join-Path $lib "cadernos-index.ts"
$homePage = Join-Path $app "page.tsx"
$cIndexPage = Join-Path $app "c\page.tsx"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] Lib: " + $libIndex)
WL ("[DIAG] Home: " + $homePage)
WL ("[DIAG] /c: " + $cIndexPage)

# -------------------------
# PATCH
# -------------------------
EnsureDir $lib
EnsureDir (Split-Path -Parent $cIndexPage)
EnsureDir $repDir

if (TestP $libIndex) { BackupFile $libIndex }
if (TestP $homePage) { BackupFile $homePage }
if (TestP $cIndexPage) { BackupFile $cIndexPage }

# src/lib/cadernos-index.ts
$libLines = @(
'import fs from "fs/promises";',
'import path from "path";',
'',
'export type CadernoMeta = {',
'  slug: string;',
'  title: string;',
'  subtitle?: string;',
'  accent?: string;',
'  ethos?: string;',
'};',
'',
'type CadernoJson = {',
'  title?: string;',
'  subtitle?: string;',
'  accent?: string;',
'  ethos?: string;',
'};',
'',
'function contentRoot(): string {',
'  return path.join(process.cwd(), "content", "cadernos");',
'}',
'',
'function humanize(slug: string): string {',
'  const s = slug.replace(/[-_]/g, " ");',
'  return s.replace(/\b\w/g, (m) => m.toUpperCase());',
'}',
'',
'async function readMeta(slug: string): Promise<CadernoMeta> {',
'  const root = contentRoot();',
'  const metaPath = path.join(root, slug, "caderno.json");',
'  try {',
'    const raw = await fs.readFile(metaPath, "utf8");',
'    const meta = JSON.parse(raw) as CadernoJson;',
'    return {',
'      slug,',
'      title: meta.title ?? humanize(slug),',
'      subtitle: meta.subtitle,',
'      accent: meta.accent,',
'      ethos: meta.ethos,',
'    };',
'  } catch {',
'    return { slug, title: humanize(slug) };',
'  }',
'}',
'',
'export async function listCadernos(): Promise<CadernoMeta[]> {',
'  const root = contentRoot();',
'  let slugs: string[] = [];',
'  try {',
'    const dirents = await fs.readdir(root, { withFileTypes: true });',
'    slugs = dirents.filter((d) => d.isDirectory()).map((d) => d.name);',
'  } catch {',
'    return [];',
'  }',
'',
'  const items: CadernoMeta[] = [];',
'  for (const slug of slugs) {',
'    items.push(await readMeta(slug));',
'  }',
'',
'  items.sort((a, b) => a.title.localeCompare(b.title, "pt-BR"));',
'  return items;',
'}'
)
WriteLines $libIndex $libLines
WL "[OK] wrote: src/lib/cadernos-index.ts"

# src/app/page.tsx (Home)
$homeLines = @(
'import Link from "next/link";',
'import { listCadernos } from "@/lib/cadernos-index";',
'',
'type AccentStyle = React.CSSProperties & { ["--accent"]?: string };',
'',
'export default async function Page() {',
'  const items = await listCadernos();',
'',
'  return (',
'    <main className="space-y-6">',
'      <section className="card p-6">',
'        <div className="text-xs muted">Hub</div>',
'        <h1 className="text-2xl font-semibold mt-1">Cadernos Vivos</h1>',
'        <p className="muted mt-2">',
'          Um acervo vivo: leitura, prática, debate e registro. Cada caderno nasce do território.',
'        </p>',
'        <div className="mt-4 flex flex-wrap gap-2">',
'          <Link className="card px-3 py-2 hover:bg-white/10 transition" href="/c">',
'            <span className="accent">Ver índice</span>',
'          </Link>',
'        </div>',
'      </section>',
'',
'      <section className="space-y-3">',
'        <div className="flex items-end justify-between">',
'          <h2 className="text-xl font-semibold">Cadernos</h2>',
'          <div className="text-sm muted">{items.length} encontrado(s)</div>',
'        </div>',
'',
'        {items.length === 0 ? (',
'          <div className="card p-6">',
'            <div className="text-lg font-semibold">Nenhum caderno encontrado</div>',
'            <p className="muted mt-2">',
'              Crie uma pasta em content/cadernos/NOME e adicione caderno.json para aparecer aqui.',
'            </p>',
'          </div>',
'        ) : (',
'          <div className="grid gap-3">',
'            {items.map((c) => {',
'              const s: AccentStyle = c.accent ? { ["--accent"]: c.accent } : {};',
'              return (',
'                <Link',
'                  key={c.slug}',
'                  href={"/c/" + c.slug}',
'                  className="card p-6 hover:bg-white/5 transition"',
'                  style={s}',
'                >',
'                  <div className="text-xs muted">/c/{c.slug}</div>',
'                  <div className="text-xl font-semibold mt-1">{c.title}</div>',
'                  {c.subtitle ? <div className="muted mt-2">{c.subtitle}</div> : null}',
'                  <div className="mt-3 text-sm accent">Abrir caderno</div>',
'                </Link>',
'              );',
'            })}',
'          </div>',
'        )}',
'      </section>',
'    </main>',
'  );',
'}'
)
WriteLines $homePage $homeLines
WL "[OK] wrote: src/app/page.tsx"

# src/app/c/page.tsx (Índice)
$cIndexLines = @(
'import Link from "next/link";',
'import { listCadernos } from "@/lib/cadernos-index";',
'',
'type AccentStyle = React.CSSProperties & { ["--accent"]?: string };',
'',
'export default async function Page() {',
'  const items = await listCadernos();',
'',
'  return (',
'    <main className="space-y-6">',
'      <section className="card p-6">',
'        <div className="text-xs muted">Índice</div>',
'        <h1 className="text-2xl font-semibold mt-1">Todos os cadernos</h1>',
'        <p className="muted mt-2">',
'          Lista gerada a partir de content/cadernos. Cada pasta vira um caderno.',
'        </p>',
'        <div className="mt-4 flex flex-wrap gap-2">',
'          <Link className="card px-3 py-2 hover:bg-white/10 transition" href="/">',
'            <span className="accent">Voltar</span>',
'          </Link>',
'        </div>',
'      </section>',
'',
'      {items.length === 0 ? (',
'        <div className="card p-6">',
'          <div className="text-lg font-semibold">Nenhum caderno encontrado</div>',
'          <p className="muted mt-2">Crie um em content/cadernos para ele aparecer aqui.</p>',
'        </div>',
'      ) : (',
'        <div className="grid gap-3">',
'          {items.map((c) => {',
'            const s: AccentStyle = c.accent ? { ["--accent"]: c.accent } : {};',
'            return (',
'              <Link',
'                key={c.slug}',
'                href={"/c/" + c.slug}',
'                className="card p-6 hover:bg-white/5 transition"',
'                style={s}',
'              >',
'                <div className="text-xs muted">/c/{c.slug}</div>',
'                <div className="text-xl font-semibold mt-1">{c.title}</div>',
'                {c.subtitle ? <div className="muted mt-2">{c.subtitle}</div> : null}',
'                <div className="mt-3 text-sm accent">Abrir caderno</div>',
'              </Link>',
'            );',
'          })}',
'        </div>',
'      )}',
'    </main>',
'  );',
'}'
)
WriteLines $cIndexPage $cIndexLines
WL "[OK] wrote: src/app/c/page.tsx"

# -------------------------
# REPORT
# -------------------------
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repDir "cv-9-index-cadernos-v0_9.md"

$reportLines = @(
("# CV-9 — Índice de Cadernos (Home + /c) — " + $now),
"",
"## O que mudou",
"- Home (/) agora lista cadernos automaticamente",
"- Nova rota /c para ver o índice completo",
"- Nova lib src/lib/cadernos-index.ts (lê content/cadernos/*/caderno.json)",
"",
"## Como funciona",
"- Cada pasta em content/cadernos/SLUG vira um item no índice",
"- Se caderno.json faltar, o título vira o slug humanizado",
"",
"## Próximo tijolo (CV-10)",
"- Criador de caderno via script: gerar pasta + arquivos seed (caderno.json, panorama.md, aulas, pratica, quiz, debate, mapa, registro)."
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
WL "[OK] CV-9 pronto. Rode npm run dev e abra / e /c."