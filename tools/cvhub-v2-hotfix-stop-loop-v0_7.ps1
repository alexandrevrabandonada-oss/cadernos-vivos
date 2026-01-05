# CV — V2 Hotfix — parar loop de types/normalize (remove index-signature, unifica CadernoV2) — v0_7
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

function EnsureDir($p) {
  if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}
function WriteUtf8NoBom($path, $text) {
  EnsureDir (Split-Path -Parent $path)
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($path, $text, $enc)
}
function BackupFile($path) {
  if (-not (Test-Path -LiteralPath $path)) { return $null }
  $bkRoot = Join-Path (Get-Location) "tools\_patch_backup"
  EnsureDir $bkRoot
  $stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
  $name = (Split-Path -Leaf $path)
  $dest = Join-Path $bkRoot ($stamp + "-" + $name)
  Copy-Item -LiteralPath $path -Destination $dest -Force
  return $dest
}
function RunCmd([string]$exe, [string[]]$cmdArgs) {
  $argsText = ""
  if ($cmdArgs -and $cmdArgs.Count -gt 0) { $argsText = " " + ($cmdArgs -join " ") }
  Write-Host ("[RUN] " + $exe + $argsText)
  & $exe @cmdArgs
  if ($LASTEXITCODE -ne 0) { throw ("[STOP] comando falhou (exit " + $LASTEXITCODE + "): " + $exe) }
}

$repo = Get-Location
Write-Host ("[DIAG] Repo: " + $repo)

# Resolve npm.cmd (evita npm.ps1 pedir install do "run")
$npmCmd = "npm.cmd"
$cmd = Get-Command "npm.cmd" -ErrorAction SilentlyContinue
if ($cmd) { $npmCmd = $cmd.Source }
Write-Host ("[DIAG] npm.cmd: " + $npmCmd)

# Paths V2
$types = Join-Path $repo "src\lib\v2\types.ts"
$normalize = Join-Path $repo "src\lib\v2\normalize.ts"
$load = Join-Path $repo "src\lib\v2\load.ts"
$index = Join-Path $repo "src\lib\v2\index.ts"

Write-Host ("[DIAG] types: " + $types)
Write-Host ("[DIAG] normalize: " + $normalize)
Write-Host ("[DIAG] load: " + $load)
Write-Host ("[DIAG] index: " + $index)

# -------------------------
# PATCH: src/lib/v2/types.ts (remove index-signature; contrato coerente com normalize)
# -------------------------
$bk1 = BackupFile $types

$typesLines = @(
'// CV V2 — types estáveis (sem loop de JsonValue vs undefined).',
'// Estratégia: sem index-signature no MetaV2. Campos opcionais simplesmente podem não existir.',
'',
'export type UiDefault = "v1" | "v2";',
'',
'export type JsonPrimitive = string | number | boolean | null;',
'export type JsonValue = JsonPrimitive | JsonValue[] | { [k: string]: JsonValue };',
'',
'export type MetaV2 = {',
'  slug: string;',
'  title: string;',
'  subtitle?: string;',
'  mood: string;',
'  accent?: string;',
'  ethos?: string;',
'  ui?: { default?: UiDefault };',
'  extra?: Record<string, JsonValue>;',
'};',
'',
'// Aliases (facilitam imports sem quebrar build)',
'export type MapaV2 = JsonValue;',
'export type AcervoV2 = JsonValue;',
'export type DebateV2 = JsonValue;',
'export type RegistroV2 = JsonValue;',
'',
'export type AulaV2 = {',
'  id: string;',
'  title: string;',
'  slug: string;',
'  md?: string;',
'  refs?: JsonValue;',
'};',
'',
'// Contrato do loader/normalize V2 (superset; não interfere na V1)',
'export type CadernoV2 = {',
'  meta: MetaV2;',
'  panoramaMd: string;',
'  referenciasMd: string;',
'  mapa: MapaV2;',
'  acervo: AcervoV2;',
'  debate: DebateV2;',
'  registro: RegistroV2;',
'  aulas: AulaV2[];',
'};',
''
) -join "`n"

WriteUtf8NoBom $types $typesLines
Write-Host "[OK] wrote: src/lib/v2/types.ts (sem index-signature; aliases + contrato V2 coerente)"
if ($bk1) { Write-Host ("[BK] " + $bk1) }

# -------------------------
# PATCH: src/lib/v2/normalize.ts (imports consistentes + defaults claros)
# -------------------------
$bk2 = BackupFile $normalize

$normalizeLines = @(
'import type {',
'  AcervoV2, CadernoV2, DebateV2, JsonValue, MapaV2, MetaV2, RegistroV2, UiDefault',
'} from "./types";',
'',
'function asObj(v: unknown): Record<string, unknown> | null {',
'  if (!v || typeof v !== "object") return null;',
'  return v as Record<string, unknown>;',
'}',
'function asStr(v: unknown): string | undefined {',
'  return typeof v === "string" ? v : undefined;',
'}',
'function asJson(v: unknown): JsonValue {',
'  // best-effort: se não for JSON "valido", devolve null',
'  if (v === null) return null;',
'  const t = typeof v;',
'  if (t === "string" || t === "number" || t === "boolean") return v as JsonValue;',
'  if (Array.isArray(v)) return v.map(asJson) as JsonValue;',
'  if (t === "object") {',
'    const o = v as Record<string, unknown>;',
'    const out: Record<string, JsonValue> = {};',
'    for (const k of Object.keys(o)) out[k] = asJson(o[k]);',
'    return out;',
'  }',
'  return null;',
'}',
'',
'export function normalizeMetaV2(raw: unknown, fallbackSlug: string): MetaV2 {',
'  const o = asObj(raw) || {};',
'  const slug = asStr(o["slug"]) || fallbackSlug;',
'  const title = asStr(o["title"]) || slug;',
'  const subtitle = asStr(o["subtitle"]);',
'  const mood = asStr(o["mood"]) || "urban";',
'  const accent = asStr(o["accent"]);',
'  const ethos = asStr(o["ethos"]);',
'',
'  const uiObj = asObj(o["ui"]);',
'  const uiDefRaw = uiObj ? asStr(uiObj["default"]) : undefined;',
'  const uiDefault = (uiDefRaw as UiDefault | undefined) || "v1";',
'',
'  const meta: MetaV2 = { slug, title, mood, ui: { default: uiDefault } };',
'  if (subtitle) meta.subtitle = subtitle;',
'  if (accent) meta.accent = accent;',
'  if (ethos) meta.ethos = ethos;',
'',
'  // extra: guarda chaves desconhecidas sem index-signature',
'  const known = new Set(["slug","title","subtitle","mood","accent","ethos","ui"]);',
'  const extra: Record<string, JsonValue> = {};',
'  for (const k of Object.keys(o)) {',
'    if (!known.has(k)) extra[k] = asJson(o[k]);',
'  }',
'  if (Object.keys(extra).length > 0) meta.extra = extra;',
'',
'  return meta;',
'}',
'',
'export function normalizeCadernoV2(input: unknown, fallbackSlug: string): CadernoV2 {',
'  const o = asObj(input) || {};',
'  const meta = normalizeMetaV2(o["meta"], fallbackSlug);',
'',
'  const panoramaMd = asStr(o["panoramaMd"]) || "";',
'  const referenciasMd = asStr(o["referenciasMd"]) || "";',
'',
'  const mapa = asJson(o["mapa"]) as MapaV2;',
'  const acervo = asJson(o["acervo"]) as AcervoV2;',
'  const debate = asJson(o["debate"]) as DebateV2;',
'  const registro = asJson(o["registro"]) as RegistroV2;',
'',
'  const aulasRaw = Array.isArray(o["aulas"]) ? (o["aulas"] as unknown[]) : [];',
'  const aulas = aulasRaw.map((x, i) => {',
'    const ax = asObj(x) || {};',
'    const id = asStr(ax["id"]) || String(i + 1);',
'    const title = asStr(ax["title"]) || ("Aula " + (i + 1));',
'    const slug = asStr(ax["slug"]) || ("aula-" + (i + 1));',
'    const md = asStr(ax["md"]);',
'    const refs = ax["refs"] !== undefined ? asJson(ax["refs"]) : undefined;',
'    return refs !== undefined ? { id, title, slug, md, refs } : { id, title, slug, md };',
'  });',
'',
'  return { meta, panoramaMd, referenciasMd, mapa, acervo, debate, registro, aulas };',
'}',
''
) -join "`n"

WriteUtf8NoBom $normalize $normalizeLines
Write-Host "[OK] wrote: src/lib/v2/normalize.ts (imports coerentes + defaults + extra sem index-signature)"
if ($bk2) { Write-Host ("[BK] " + $bk2) }

# -------------------------
# PATCH: src/lib/v2/load.ts (loader simples e estável)
# -------------------------
$bk3 = BackupFile $load

$loadLines = @(
'import path from "node:path";',
'import fs from "node:fs/promises";',
'import type { JsonValue, CadernoV2 } from "./types";',
'import { normalizeCadernoV2 } from "./normalize";',
'',
'const CONTENT_ROOT = path.join(process.cwd(), "content", "cadernos");',
'',
'async function readText(p: string): Promise<string> {',
'  try { return await fs.readFile(p, "utf8"); } catch { return ""; }',
'}',
'async function readJson(p: string): Promise<JsonValue> {',
'  try {',
'    const s = await fs.readFile(p, "utf8");',
'    return JSON.parse(s) as JsonValue;',
'  } catch {',
'    return {} as JsonValue;',
'  }',
'}',
'',
'export async function loadCadernoV2(slug: string): Promise<CadernoV2> {',
'  const base = path.join(CONTENT_ROOT, slug);',
'  const meta = await readJson(path.join(base, "meta.json"));',
'  const panoramaMd = await readText(path.join(base, "panorama.md"));',
'  const referenciasMd = await readText(path.join(base, "referencias.md"));',
'  const mapa = await readJson(path.join(base, "mapa.json"));',
'  const acervo = await readJson(path.join(base, "acervo.json"));',
'  const debate = await readJson(path.join(base, "debate.json"));',
'  const registro = await readJson(path.join(base, "registro.json"));',
'',
'  // aulas V2: por enquanto vazio (não mexe no pipeline V1 existente)',
'  const input = { meta, panoramaMd, referenciasMd, mapa, acervo, debate, registro, aulas: [] as unknown[] };',
'  return normalizeCadernoV2(input, slug);',
'}',
''
) -join "`n"

WriteUtf8NoBom $load $loadLines
Write-Host "[OK] wrote: src/lib/v2/load.ts (loader estável + normalize)"
if ($bk3) { Write-Host ("[BK] " + $bk3) }

# -------------------------
# PATCH: src/lib/v2/index.ts (barrel)
# -------------------------
$bk4 = BackupFile $index
$indexLines = @(
'export * from "./types";',
'export * from "./normalize";',
'export * from "./load";',
''
) -join "`n"
WriteUtf8NoBom $index $indexLines
Write-Host "[OK] wrote: src/lib/v2/index.ts"
if ($bk4) { Write-Host ("[BK] " + $bk4) }

# -------------------------
# VERIFY
# -------------------------
RunCmd $npmCmd @("run","lint")
RunCmd $npmCmd @("run","build")

# -------------------------
# REPORT
# -------------------------
$reports = Join-Path $repo "reports"
EnsureDir $reports
$reportPath = Join-Path $reports "cv-v2-hotfix-stop-loop-v0_7.md"

$report = @(
'# CV — V2 Hotfix v0_7 — Stop loop de types/normalize',
'',
'## Causa raiz',
'- O MetaV2 tinha index signature [k: string]: JsonValue, então TODAS as propriedades precisam ser JsonValue.',
'- Campos opcionais viram T|undefined, e isso entra em conflito com JsonValue (JSON nao tem undefined).',
'- Isso gerou o loop null vs undefined e imports quebrados.',
'',
'## Nova estrategia',
'- Removido index signature do MetaV2.',
'- Campos opcionais sao simplesmente omitidos (JSON valido).',
'- extra desconhecido vai em meta.extra (Record<string, JsonValue>).',
'- CadernoV2 foi alinhado com normalize: panoramaMd, referenciasMd, aulas.',
'',
'## Arquivos',
'- src/lib/v2/types.ts (reescrito)',
'- src/lib/v2/normalize.ts (reescrito)',
'- src/lib/v2/load.ts (reescrito)',
'- src/lib/v2/index.ts (reescrito)',
'',
'## Verify',
'- npm run lint',
'- npm run build',
''
) -join "`n"

WriteUtf8NoBom $reportPath $report
Write-Host ("[OK] Report: " + $reportPath)
Write-Host "[OK] v0_7 aplicado."