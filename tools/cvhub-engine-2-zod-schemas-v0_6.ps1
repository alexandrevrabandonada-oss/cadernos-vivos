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

function AddImportAfterLastImport([string]$raw, [string]$importLine) {
  if ($raw -like ("*" + $importLine + "*")) { return $raw }

  $lines = $raw -split "`r?`n"
  $lastImport = -1
  for ($i=0; $i -lt $lines.Length; $i++) {
    $t = $lines[$i].TrimStart()
    if ($t.StartsWith("import ")) { $lastImport = $i }
  }

  $out = New-Object System.Collections.Generic.List[string]
  for ($i=0; $i -lt $lines.Length; $i++) {
    [void]$out.Add($lines[$i])
    if ($i -eq $lastImport) {
      [void]$out.Add($importLine)
    }
  }
  if ($lastImport -lt 0) {
    $out2 = New-Object System.Collections.Generic.List[string]
    [void]$out2.Add($importLine)
    [void]$out2.Add("")
    foreach ($ln in $lines) { [void]$out2.Add($ln) }
    return ($out2 -join "`n")
  }
  return ($out -join "`n")
}

function FindCadernosLib([string]$repo) {
  $src = Join-Path $repo "src"
  if (-not (TestP $src)) { return $null }

  $candidates = @(Get-ChildItem -LiteralPath $src -Recurse -File -Filter "cadernos.ts" -ErrorAction SilentlyContinue)
  if ($candidates.Count -gt 0) { return $candidates[0].FullName }

  $hits = @(Get-ChildItem -LiteralPath $src -Recurse -File -Filter "*.ts" -ErrorAction SilentlyContinue | Where-Object {
    (Select-String -LiteralPath $_.FullName -Pattern "export async function getCaderno" -SimpleMatch -Quiet)
  })
  if ($hits.Count -gt 0) { return $hits[0].FullName }

  return $null
}

function PatchCadernosParse([string]$p) {
  $raw = Get-Content -LiteralPath $p -Raw
  $raw2 = $raw

  # add import
  $raw2 = AddImportAfterLastImport $raw2 'import { parseCadernoJson, parseMapaJson, parseDebateJson, parseAcervoJson } from "@/lib/schemas";'

  # map: pathVar -> kind
  $pathVarKind = @{}
  $rawVarKind  = @{}

  $lines = $raw2 -split "`r?`n"

  # first pass: detect path vars (caderno.json/mapa.json/debate.json/acervo.json)
  for ($i=0; $i -lt $lines.Length; $i++) {
    $ln = $lines[$i]
    $m = [regex]::Match($ln, 'const\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*.*"([^"]+\.json)"')
    if ($m.Success) {
      $v = $m.Groups[1].Value
      $f = $m.Groups[2].Value.ToLower()
      if ($f.EndsWith("caderno.json")) { $pathVarKind[$v] = "caderno" }
      elseif ($f.EndsWith("mapa.json")) { $pathVarKind[$v] = "mapa" }
      elseif ($f.EndsWith("debate.json")) { $pathVarKind[$v] = "debate" }
      elseif ($f.EndsWith("acervo.json")) { $pathVarKind[$v] = "acervo" }
    }
  }

  # second pass: detect raw var readFile(pathVar)
  for ($i=0; $i -lt $lines.Length; $i++) {
    $ln = $lines[$i]
    $m = [regex]::Match($ln, 'const\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*await\s+.*readFile\(\s*([A-Za-z_][A-Za-z0-9_]*)')
    if ($m.Success) {
      $rawVar = $m.Groups[1].Value
      $pathVar = $m.Groups[2].Value
      if ($pathVarKind.ContainsKey($pathVar)) {
        $rawVarKind[$rawVar] = $pathVarKind[$pathVar]
      }
    }
  }

  # third pass: replace JSON.parse(rawVar) with parseXxxJson(rawVar) when we know kind
  for ($i=0; $i -lt $lines.Length; $i++) {
    $ln = $lines[$i]
    foreach ($kv in $rawVarKind.GetEnumerator()) {
      $rv = $kv.Key
      $k  = $kv.Value
      if ($ln -like ("*JSON.parse(" + $rv + ")*")) {
        if ($k -eq "caderno") { $lines[$i] = $ln.Replace(("JSON.parse(" + $rv + ")"), ("parseCadernoJson(" + $rv + ")")) }
        elseif ($k -eq "mapa") { $lines[$i] = $ln.Replace(("JSON.parse(" + $rv + ")"), ("parseMapaJson(" + $rv + ")")) }
        elseif ($k -eq "debate") { $lines[$i] = $ln.Replace(("JSON.parse(" + $rv + ")"), ("parseDebateJson(" + $rv + ")")) }
        elseif ($k -eq "acervo") { $lines[$i] = $ln.Replace(("JSON.parse(" + $rv + ")"), ("parseAcervoJson(" + $rv + ")")) }
      }

      # common pattern: JSON.parse(rawVar) as Something
      if ($ln -like ("*JSON.parse(" + $rv + ")* as *")) {
        if ($k -eq "caderno") { $lines[$i] = [regex]::Replace($lines[$i], 'JSON\.parse\(' + [regex]::Escape($rv) + '\)\s+as\s+[A-Za-z0-9_<>,\s]+', 'parseCadernoJson(' + $rv + ')') }
        elseif ($k -eq "mapa") { $lines[$i] = [regex]::Replace($lines[$i], 'JSON\.parse\(' + [regex]::Escape($rv) + '\)\s+as\s+[A-Za-z0-9_<>,\s]+', 'parseMapaJson(' + $rv + ')') }
        elseif ($k -eq "debate") { $lines[$i] = [regex]::Replace($lines[$i], 'JSON\.parse\(' + [regex]::Escape($rv) + '\)\s+as\s+[A-Za-z0-9_<>,\s]+', 'parseDebateJson(' + $rv + ')') }
        elseif ($k -eq "acervo") { $lines[$i] = [regex]::Replace($lines[$i], 'JSON\.parse\(' + [regex]::Escape($rv) + '\)\s+as\s+[A-Za-z0-9_<>,\s]+', 'parseAcervoJson(' + $rv + ')') }
      }
    }
  }

  $patched = ($lines -join "`n")
  return $patched
}

# -------------------------
# DIAG
# -------------------------
$repo = ResolveRepoHere
$npmExe = ResolveExe "npm.cmd"
WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)

# -------------------------
# PATCH A — schemas.ts
# -------------------------
$libDir = Join-Path $repo "src\lib"
EnsureDir $libDir
$schemasPath = Join-Path $libDir "schemas.ts"
BackupFile $schemasPath

$schemasLines = @(
'import { z } from "zod";',
'',
'// ---- base helpers ----',
'function parseJson<T>(raw: string, schema: z.ZodType<T>, label: string): T {',
'  let obj: unknown;',
'  try {',
'    obj = JSON.parse(raw);',
'  } catch {',
'    throw new Error("JSON invalido em " + label);',
'  }',
'  const r = schema.safeParse(obj);',
'  if (!r.success) {',
'    const msg = r.error.issues.map((i) => i.path.join(".") + ": " + i.message).join("; ");',
'    throw new Error("Schema invalido em " + label + ": " + msg);',
'  }',
'  return r.data;',
'}',
'',
'// ---- caderno.json ----',
'export const CadernoMetaSchema = z.object({',
'  title: z.string().min(1),',
'  subtitle: z.string().optional(),',
'  ethos: z.string().optional(),',
'  accent: z.string().optional(),',
'}).passthrough();',
'',
'export const CadernoSchema = z.object({',
'  meta: CadernoMetaSchema,',
'}).passthrough();',
'',
'export type CadernoData = z.infer<typeof CadernoSchema>;',
'',
'export function parseCadernoJson(raw: string): CadernoData {',
'  return parseJson(raw, CadernoSchema, "caderno.json");',
'}',
'',
'// ---- mapa.json ----',
'export const MapPointSchema = z.object({',
'  id: z.string().min(1),',
'  title: z.string().optional(),',
'  label: z.string().optional(),',
'  name: z.string().optional(),',
'  lat: z.number(),',
'  lng: z.number(),',
'  kind: z.string().optional(),',
'  notes: z.string().optional(),',
'  tags: z.array(z.string()).optional(),',
'}).passthrough();',
'',
'export const MapSchema = z.object({',
'  points: z.array(MapPointSchema).default([]),',
'}).passthrough();',
'',
'export type MapPoint = z.infer<typeof MapPointSchema>;',
'export type MapData = z.infer<typeof MapSchema>;',
'',
'export function parseMapaJson(raw: string): MapData {',
'  return parseJson(raw, MapSchema, "mapa.json");',
'}',
'',
'// ---- debate.json ----',
'export const DebatePromptSchema = z.object({',
'  id: z.string().min(1),',
'  title: z.string().min(1),',
'  prompt: z.string().min(1),',
'}).passthrough();',
'',
'export const DebateSchema = z.union([',
'  z.object({ prompts: z.array(DebatePromptSchema) }).passthrough(),',
'  z.array(DebatePromptSchema).transform((prompts) => ({ prompts })),',
']);',
'',
'export type DebateData = z.infer<typeof DebateSchema>;',
'export type DebatePrompt = z.infer<typeof DebatePromptSchema>;',
'',
'export function parseDebateJson(raw: string): { prompts: DebatePrompt[] } {',
'  const data = parseJson(raw, DebateSchema, "debate.json");',
'  // union garante objeto com prompts',
'  return (data as unknown) as { prompts: DebatePrompt[] };',
'}',
'',
'// ---- acervo.json ----',
'export const AcervoItemSchema = z.object({',
'  file: z.string().min(1),',
'  title: z.string().min(1),',
'  kind: z.string().min(1),',
'  tags: z.array(z.string()).default([]),',
'}).passthrough();',
'',
'export const AcervoSchema = z.array(AcervoItemSchema);',
'export type AcervoItem = z.infer<typeof AcervoItemSchema>;',
'export type AcervoData = z.infer<typeof AcervoSchema>;',
'',
'export function parseAcervoJson(raw: string): AcervoData {',
'  return parseJson(raw, AcervoSchema, "acervo.json");',
'}'
)

WriteUtf8NoBom $schemasPath ($schemasLines -join "`n")
WL ("[OK] wrote: " + $schemasPath)

# -------------------------
# PATCH B — cadernos.ts parse swap
# -------------------------
$cadernosPath = FindCadernosLib $repo
if (-not $cadernosPath) { throw "[STOP] Não achei src/lib/cadernos.ts (ou getCaderno)."} 

WL ("[DIAG] cadernos lib: " + $cadernosPath)
BackupFile $cadernosPath

$patched = PatchCadernosParse $cadernosPath
WriteUtf8NoBom $cadernosPath $patched
WL ("[OK] patched: " + $cadernosPath)

# -------------------------
# REPORT
# -------------------------
$repDir = Join-Path $repo "reports"
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repDir "cv-engine-2-zod-schemas-v0_6.md"

$reportLines = @(
("# CV-Engine-2 — Zod Schemas e Parse Central — " + $now),
"",
"## O que foi feito",
"- Criado src/lib/schemas.ts com schemas Zod para caderno.json, mapa.json, debate.json, acervo.json.",
"- MapPoint agora aceita title/label/name opcionais (evita regressao de type).",
"- Patch em src/lib/cadernos.ts: JSON.parse(raw) virou parseXxxJson(raw) quando o script reconhece o arquivo.",
"",
"## Resultado esperado",
"- Se JSON/schema estiver quebrado, erro fica legivel e localizado.",
"- Tipos unificados e menos quebra-cabeca no build.",
"",
"## Proximo tijolo sugerido",
"- CV-Engine-3: acessibilidade e interatividade (atalhos, foco, ARIA, modo leitura, TTS botao)."
)

WriteUtf8NoBom $reportPath ($reportLines -join "`n")
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
WL "[OK] Engine-2 concluido."