param(
  [switch]$SkipVerify
)

$repo = (Get-Location).Path
$boot = Join-Path $repo "tools\_bootstrap.ps1"
if (Test-Path $boot) { . $boot } else {
  function EnsureDir($p){ if(-not (Test-Path $p)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
  function WriteUtf8NoBom($p,$t){ EnsureDir (Split-Path -Parent $p); $enc=New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText($p,$t,$enc) }
  function BackupFile($p){
    if(Test-Path $p){
      $bk = Join-Path $repo ("tools\_patch_backup\" + (Get-Date -Format "yyyyMMdd-HHmmss") )
      EnsureDir $bk
      Copy-Item $p (Join-Path $bk (Split-Path $p -Leaf)) -Force
    }
  }
  function RunNative($cwd,$exe,$args){
    $p = Start-Process -FilePath $exe -ArgumentList $args -WorkingDirectory $cwd -NoNewWindow -Wait -PassThru
    if($p.ExitCode -ne 0){ throw ("[STOP] comando falhou (exit " + $p.ExitCode + "): " + $exe + " " + ($args -join " ")) }
  }
  function NewReport($name,$lines){
    $repDir = Join-Path $repo "reports"
    EnsureDir $repDir
    $rp = Join-Path $repDir $name
    WriteUtf8NoBom $rp ($lines -join "`n")
    return $rp
  }
}

$npmExe = (Get-Command npm -ErrorAction SilentlyContinue).Source
if(-not $npmExe){ $npmExe = "npm" }

Write-Host "[DIAG] Repo: $repo"
Write-Host "[DIAG] npm: $npmExe"

$libV2Dir = Join-Path $repo "src\lib\v2"
EnsureDir $libV2Dir

# -------------------------
# types.ts
# -------------------------
$typesPath = Join-Path $libV2Dir "types.ts"
$typesLines = @(
  'export type UiDefault = "v1" | "v2";',
  '',
  'export type JsonValue = null | boolean | number | string | JsonValue[] | { [k: string]: JsonValue };',
  '',
  'export type MetaV2 = {',
  '  slug: string;',
  '  title: string;',
  '  subtitle?: string;',
  '  mood?: string;',
  '  accent?: string;',
  '  ethos?: string;',
  '  ui?: { default?: UiDefault };',
  '  [k: string]: JsonValue;',
  '};',
  '',
  'export type MapaNodeV2 = {',
  '  id: string;',
  '  label?: string;',
  '  type?: string;',
  '  x?: number;',
  '  y?: number;',
  '  tags?: string[];',
  '  data?: Record<string, JsonValue>;',
  '};',
  '',
  'export type MapaEdgeV2 = { from: string; to: string; kind?: string; label?: string };',
  '',
  'export type MapaV2 = { nodes: MapaNodeV2[]; edges?: MapaEdgeV2[]; [k: string]: JsonValue };',
  '',
  'export type AcervoItemV2 = { id: string; title?: string; url?: string; kind?: string; tags?: string[]; [k: string]: JsonValue };',
  'export type AcervoV2 = { items: AcervoItemV2[]; [k: string]: JsonValue };',
  '',
  'export type DebateV2 = { items?: JsonValue[]; [k: string]: JsonValue };',
  'export type RegistroV2 = { items?: JsonValue[]; [k: string]: JsonValue };',
  '',
  'export type AulaV2 = { slug: string; num: number; markdown: string };',
  '',
  'export type CadernoV2 = {',
  '  meta: MetaV2;',
  '  panoramaMd: string;',
  '  referenciasMd: string;',
  '  mapa: MapaV2;',
  '  acervo: AcervoV2;',
  '  debate: DebateV2;',
  '  registro: RegistroV2;',
  '  aulas: AulaV2[];',
  '  issues: string[];',
  '};'
)
WriteUtf8NoBom $typesPath ($typesLines -join "`n")
Write-Host "[OK] wrote: src/lib/v2/types.ts"

# -------------------------
# normalize.ts
# -------------------------
$normPath = Join-Path $libV2Dir "normalize.ts"
$normLines = @(
  'import type { AcervoV2, CadernoV2, DebateV2, JsonValue, MapaV2, MetaV2, RegistroV2, UiDefault } from "./types";',
  '',
  'function asObj(v: unknown): Record<string, JsonValue> | null {',
  '  if (!v || typeof v !== "object") return null;',
  '  return v as Record<string, JsonValue>;',
  '}',
  '',
  'function asStr(v: unknown): string | undefined {',
  '  return typeof v === "string" ? v : undefined;',
  '}',
  '',
  'function safeParseJson(text: string, issues: string[], label: string): JsonValue {',
  '  try { return JSON.parse(text) as JsonValue; }',
  '  catch { issues.push("bad_json:" + label); return {}; }',
  '}',
  '',
  'export function normalizeMeta(slug: string, raw: unknown, issues: string[]): MetaV2 {',
  '  const o = asObj(raw) || {};',
  '  const title = asStr(o["title"]) || slug;',
  '  const mood = asStr(o["mood"]) || asStr(o["universe"]) || asStr(o["theme"]) || asStr(o["tone"]);',
  '  const uiObj = asObj(o["ui"]);',
  '  const uiDef = (asStr(uiObj ? uiObj["default"] : undefined) as UiDefault | undefined) || "v1";',
  '  const meta: MetaV2 = {',
  '    slug,',
  '    title,',
  '    subtitle: asStr(o["subtitle"]),',
  '    mood: mood,',
  '    accent: asStr(o["accent"]),',
  '    ethos: asStr(o["ethos"]),',
  '    ui: { default: uiDef },',
  '  };',
  '  // preserva chaves extras (superset)',
  '  for (const k of Object.keys(o)) {',
  '    if ((meta as Record<string, JsonValue>)[k] === undefined) (meta as Record<string, JsonValue>)[k] = o[k];',
  '  }',
  '  if (!asStr(o["title"])) issues.push("meta_default:title");',
  '  if (!mood) issues.push("meta_default:mood");',
  '  return meta;',
  '}',
  '',
  'export function normalizeMapa(raw: JsonValue, issues: string[]): MapaV2 {',
  '  const o = (raw && typeof raw === "object") ? (raw as Record<string, JsonValue>) : {};',
  '  const nodesRaw = o["nodes"];',
  '  const nodes = Array.isArray(nodesRaw) ? nodesRaw : [];',
  '  if (!Array.isArray(nodesRaw)) issues.push("mapa_default:nodes");',
  '  return { ...(o as any), nodes: nodes as any };',
  '}',
  '',
  'export function normalizeAcervo(raw: JsonValue, issues: string[]): AcervoV2 {',
  '  const o = (raw && typeof raw === "object") ? (raw as Record<string, JsonValue>) : {};',
  '  const itemsRaw = o["items"];',
  '  const items = Array.isArray(itemsRaw) ? itemsRaw : [];',
  '  if (!Array.isArray(itemsRaw)) issues.push("acervo_default:items");',
  '  return { ...(o as any), items: items as any };',
  '}',
  '',
  'export function normalizeDebate(raw: JsonValue, _issues: string[]): DebateV2 {',
  '  return (raw && typeof raw === "object") ? (raw as any) : {};',
  '}',
  '',
  'export function normalizeRegistro(raw: JsonValue, _issues: string[]): RegistroV2 {',
  '  return (raw && typeof raw === "object") ? (raw as any) : {};',
  '}',
  '',
  'export function normalizeCaderno(input: { slug: string; metaRaw: unknown; panoramaMd: string; referenciasMd: string; mapaRaw: string; acervoRaw: string; debateRaw: string; registroRaw: string; aulas: { slug: string; num: number; markdown: string }[] }): CadernoV2 {',
  '  const issues: string[] = [];',
  '  const mapaJ = safeParseJson(input.mapaRaw, issues, "mapa.json");',
  '  const acervoJ = safeParseJson(input.acervoRaw, issues, "acervo.json");',
  '  const debateJ = safeParseJson(input.debateRaw, issues, "debate.json");',
  '  const registroJ = safeParseJson(input.registroRaw, issues, "registro.json");',
  '  const meta = normalizeMeta(input.slug, input.metaRaw, issues);',
  '  const mapa = normalizeMapa(mapaJ, issues);',
  '  const acervo = normalizeAcervo(acervoJ, issues);',
  '  const debate = normalizeDebate(debateJ, issues);',
  '  const registro = normalizeRegistro(registroJ, issues);',
  '  return {',
  '    meta,',
  '    panoramaMd: input.panoramaMd || "",',
  '    referenciasMd: input.referenciasMd || "",',
  '    mapa, acervo, debate, registro,',
  '    aulas: input.aulas || [],',
  '    issues,',
  '  };',
  '}'
)
WriteUtf8NoBom $normPath ($normLines -join "`n")
Write-Host "[OK] wrote: src/lib/v2/normalize.ts"

# -------------------------
# load.ts (server-only)
# -------------------------
$loadPath = Join-Path $libV2Dir "load.ts"
$loadLines = @(
  'import "server-only";',
  'import path from "path";',
  'import fs from "fs/promises";',
  'import { normalizeCaderno } from "./normalize";',
  '',
  'type LoadOpts = { baseDir?: string };',
  '',
  'function slugToTitle(slug: string) {',
  '  return slug.replace(/[-_]+/g, " ").replace(/\b\w/g, m => m.toUpperCase());',
  '}',
  '',
  'export async function getCadernoV2(slug: string, opts: LoadOpts = {}) {',
  '  const base = opts.baseDir || path.join(process.cwd(), "content", "cadernos");',
  '  const dir = path.join(base, slug);',
  '',
  '  const metaPath = path.join(dir, "meta.json");',
  '  const panoramaPath = path.join(dir, "panorama.md");',
  '  const refsPath = path.join(dir, "referencias.md");',
  '  const mapaPath = path.join(dir, "mapa.json");',
  '  const acervoPath = path.join(dir, "acervo.json");',
  '  const debatePath = path.join(dir, "debate.json");',
  '  const registroPath = path.join(dir, "registro.json");',
  '',
  '  let metaRaw: unknown = { title: slugToTitle(slug) };',
  '  try { metaRaw = JSON.parse(await fs.readFile(metaPath, "utf8")); } catch {}',
  '',
  '  let panoramaMd = "";',
  '  try { panoramaMd = await fs.readFile(panoramaPath, "utf8"); } catch {}',
  '',
  '  let referenciasMd = "";',
  '  try { referenciasMd = await fs.readFile(refsPath, "utf8"); } catch {}',
  '',
  '  const mapaRaw = await fs.readFile(mapaPath, "utf8");',
  '  const acervoRaw = await fs.readFile(acervoPath, "utf8");',
  '  const debateRaw = await fs.readFile(debatePath, "utf8");',
  '  let registroRaw = "{}";',
  '  try { registroRaw = await fs.readFile(registroPath, "utf8"); } catch {}',
  '',
  '  // aulas: aula-*.md',
  '  let aulas: { slug: string; num: number; markdown: string }[] = [];',
  '  try {',
  '    const files = await fs.readdir(dir);',
  '    const aulaFiles = files.filter(f => /^aula-\\d+\\.md$/.test(f));',
  '    const loaded = await Promise.all(aulaFiles.map(async f => {',
  '      const n = Number(f.replace("aula-","").replace(".md",""));',
  '      const md = await fs.readFile(path.join(dir, f), "utf8");',
  '      return { slug: f.replace(".md",""), num: n, markdown: md };',
  '    }));',
  '    aulas = loaded.sort((a,b) => a.num - b.num);',
  '  } catch {}',
  '',
  '  return normalizeCaderno({ slug, metaRaw, panoramaMd, referenciasMd, mapaRaw, acervoRaw, debateRaw, registroRaw, aulas });',
  '}'
)
WriteUtf8NoBom $loadPath ($loadLines -join "`n")
Write-Host "[OK] wrote: src/lib/v2/load.ts"

# -------------------------
# index.ts
# -------------------------
$indexPath = Join-Path $libV2Dir "index.ts"
$indexLines = @(
  'export * from "./types";',
  'export * from "./normalize";',
  'export * from "./load";'
)
WriteUtf8NoBom $indexPath ($indexLines -join "`n")
Write-Host "[OK] wrote: src/lib/v2/index.ts"

# -------------------------
# REPORT
# -------------------------
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$lines = @(
  ("# CV — Tijolo B (Data layer V2) — " + $now),
  "",
  "## O que foi criado (sem tocar UI)",
  "- src/lib/v2/types.ts",
  "- src/lib/v2/normalize.ts",
  "- src/lib/v2/load.ts (server-only)",
  "- src/lib/v2/index.ts",
  "",
  "## Garantias",
  "- Não mexe em rotas / componentes existentes.",
  "- Leitura tolerante: meta/registro podem faltar (defaults + issues).",
  "- Normalize superset: preserva chaves extras em meta/mapa/acervo.",
  "",
  "## Próximo",
  "- Tijolo C: criar /c/[slug]/v2 placeholder + Shell Concreto Zen, consumindo getCadernoV2(slug)."
)
$rp = NewReport "cv-v2-tijolo-b-data-layer-v0_1.md" $lines
Write-Host ("[OK] Report: " + $rp)

# -------------------------
# VERIFY
# -------------------------
if (-not $SkipVerify) {
  Write-Host "[VERIFY] npm run lint..."
  RunNative $repo $npmExe @("run","lint")
  Write-Host "[VERIFY] npm run build..."
  RunNative $repo $npmExe @("run","build")
} else {
  Write-Host "[VERIFY] pulado (-SkipVerify)."
}

Write-Host "[OK] Tijolo B aplicado."