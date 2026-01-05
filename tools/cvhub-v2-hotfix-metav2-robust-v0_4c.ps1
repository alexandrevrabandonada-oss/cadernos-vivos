param(
  [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repo = (Get-Location).Path
$bootstrap = Join-Path $repo "tools\_bootstrap.ps1"
if (-not (Test-Path -LiteralPath $bootstrap)) { throw "[STOP] tools/_bootstrap.ps1 não encontrado." }
. $bootstrap

function ResolveRepoHere() {
  $here = (Get-Location).Path
  if (Test-Path -LiteralPath (Join-Path $here "package.json")) { return $here }
  throw ("[STOP] Rode na raiz do repo (onde tem package.json). Atual: " + $here)
}

function FindMetaV2Start([string]$raw) {
  $patterns = @(
    '(?m)^\s*export\s+interface\s+MetaV2\b',
    '(?m)^\s*interface\s+MetaV2\b',
    '(?m)^\s*export\s+type\s+MetaV2\b',
    '(?m)^\s*type\s+MetaV2\b'
  )
  foreach ($p in $patterns) {
    $m = [regex]::Match($raw, $p)
    if ($m.Success) { return $m.Index }
  }
  return -1
}

function BraceMatchEnd([string]$raw, [int]$braceStart) {
  $depth = 0
  for ($i = $braceStart; $i -lt $raw.Length; $i++) {
    $ch = $raw[$i]
    if ($ch -eq "{") { $depth++ }
    elseif ($ch -eq "}") {
      $depth--
      if ($depth -eq 0) { return $i }
    }
  }
  return -1
}

function PatchMetaSegment([string]$seg) {
  $lines = $seg -split "`n"

  for ($i=0; $i -lt $lines.Length; $i++) {
    $line = $lines[$i]

    if ($line -match '^\s*subtitle\??\s*:\s*') {
      $indent = ($line -replace '^(\s*).*$','$1')
      $lines[$i] = ($indent + "subtitle: string | null;")
      continue
    }
    if ($line -match '^\s*accent\??\s*:\s*') {
      $indent = ($line -replace '^(\s*).*$','$1')
      $lines[$i] = ($indent + "accent: string | null;")
      continue
    }
    if ($line -match '^\s*ethos\??\s*:\s*') {
      $indent = ($line -replace '^(\s*).*$','$1')
      $lines[$i] = ($indent + "ethos: string | null;")
      continue
    }
    if ($line -match '^\s*mood\??\s*:\s*') {
      # garante mood não-optional
      $indent = ($line -replace '^(\s*).*$','$1')
      $lines[$i] = ($indent + "mood: string;")
      continue
    }
  }

  return ($lines -join "`n")
}

$repo = ResolveRepoHere
$npmExe = ResolveExe "npm"
$typesPath = Join-Path $repo "src\lib\v2\types.ts"
$repDir = Join-Path $repo "reports"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] types: " + $typesPath)

if (-not (Test-Path -LiteralPath $typesPath)) { throw ("[STOP] Não achei: " + $typesPath) }

BackupFile $typesPath
$raw = Get-Content -LiteralPath $typesPath -Raw

$start = FindMetaV2Start $raw
if ($start -lt 0) {
  WL "[WARN] Não encontrei MetaV2 em types.ts. Vou gerar um DIAG útil no report."

  EnsureDir $repDir
  $now = Get-Date -Format "yyyy-MM-dd HH:mm"

  $exports = [regex]::Matches($raw, '(?m)^\s*export\s+(interface|type)\s+([A-Za-z0-9_]+)\b') |
    ForEach-Object { $_.Value.Trim() }

  $hits = [regex]::Matches($raw, '(?m)^\s*(export\s+)?(interface|type)\s+([A-Za-z0-9_]+)\b') |
    ForEach-Object { $_.Value.Trim() } | Select-Object -First 40

  $rep = @()
  $rep += ("# CV V2 Hotfix — MetaV2 robust v0.4c — " + $now)
  $rep += ""
  $rep += "## Resultado"
  $rep += "- MetaV2 não foi encontrado por padrões comuns."
  $rep += ""
  $rep += "## Exports (top)"
  if ($exports -and $exports.Count -gt 0) { $rep += ($exports | Select-Object -First 40) } else { $rep += "- (nenhum export interface/type encontrado)" }
  $rep += ""
  $rep += "## Primeiros matches interface/type (top)"
  if ($hits -and $hits.Count -gt 0) { $rep += ($hits) } else { $rep += "- (nenhum match)" }

  $repPath = Join-Path $repDir "cv-v2-hotfix-metav2-robust-v0_4c_DIAG.md"
  WriteUtf8NoBom $repPath ($rep -join "`n")
  WL ("[OK] Report: " + $repPath)

  throw "[STOP] MetaV2 não encontrado. Me manda o trecho do report gerado (exports) e eu ajusto o patch com precisão."
}

$braceStart = $raw.IndexOf("{", $start)
if ($braceStart -lt 0) { throw "[STOP] Achei o começo de MetaV2 mas não achei '{'." }

$braceEnd = BraceMatchEnd $raw $braceStart
if ($braceEnd -lt 0) { throw "[STOP] Não consegui brace-match do bloco MetaV2." }

# Segmento que contém a declaração até o fechamento do primeiro bloco {...}
$segStart = $start
$segEnd = $braceEnd + 1
$seg = $raw.Substring($segStart, $segEnd - $segStart)

$seg2 = PatchMetaSegment $seg

$newRaw = $raw.Substring(0, $segStart) + $seg2 + $raw.Substring($segEnd)

WriteUtf8NoBom $typesPath $newRaw
WL "[OK] patched: types.ts (MetaV2: subtitle/accent/ethos -> string|null; mood obrigatório)"

# REPORT
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$repLines = @(
  ("# CV V2 Hotfix — MetaV2 robust v0.4c — " + $now),
  "",
  "## Problema",
  "- MetaV2 tinha campos opcionais (string|undefined) e index signature JsonValue (sem undefined).",
  "- normalize.ts usa null para evitar undefined em JsonValue.",
  "",
  "## Fix",
  "- MetaV2 agora aceita null para subtitle/accent/ethos e mood fica obrigatório.",
  "- Patch robusto: funciona com interface ou type."
) -join "`n"

$repPath = Join-Path $repDir "cv-v2-hotfix-metav2-robust-v0_4c.md"
WriteUtf8NoBom $repPath $repLines
WL ("[OK] Report: " + $repPath)

# VERIFY
WL "[VERIFY] npm run lint..."
RunNative $repo $npmExe @("run","lint")

if (-not $SkipBuild) {
  WL "[VERIFY] npm run build..."
  RunNative $repo $npmExe @("run","build")
} else {
  WL "[VERIFY] build pulado (-SkipBuild)."
}

WL "[OK] Hotfix aplicado: MetaV2 alinhado com JsonValue e normalize."