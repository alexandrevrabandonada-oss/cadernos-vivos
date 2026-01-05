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

function ReplaceInterfaceBlockByBrace([string]$raw, [string]$needle, [string]$replacement) {
  $idx = $raw.IndexOf($needle, [System.StringComparison]::Ordinal)
  if ($idx -lt 0) { throw ("[STOP] Não achei: " + $needle) }

  $braceStart = $raw.IndexOf("{", $idx)
  if ($braceStart -lt 0) { throw "[STOP] Não achei '{' após o início do bloco." }

  $depth = 0
  $end = -1
  for ($i = $braceStart; $i -lt $raw.Length; $i++) {
    $ch = $raw[$i]
    if ($ch -eq "{") { $depth++ }
    elseif ($ch -eq "}") {
      $depth--
      if ($depth -eq 0) { $end = $i; break }
    }
  }
  if ($end -lt 0) { throw "[STOP] Não consegui fechar o brace-match do bloco." }

  $before = $raw.Substring(0, $idx)
  $after  = $raw.Substring($end + 1)

  return ($before + $replacement + $after)
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

# Novo MetaV2: campos que podem faltar viram null (não undefined),
# porque JsonValue não aceita undefined.
$metaBlockLines = @(
'export interface MetaV2 {',
'  slug: string;',
'  title: string;',
'  subtitle: string | null;',
'  mood: string;',
'  accent: string | null;',
'  ethos: string | null;',
'  ui: {',
'    default: UiDefault;',
'  };',
'  [k: string]: JsonValue;',
'}'
)
$metaBlock = ($metaBlockLines -join "`n")

# Substitui o bloco inteiro do MetaV2
$raw2 = ReplaceInterfaceBlockByBrace $raw "export interface MetaV2" $metaBlock

WriteUtf8NoBom $typesPath $raw2
WL "[OK] patched: types.ts (MetaV2 nullable: subtitle/accent/ethos)"

# REPORT
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$rep = @(
  ("# CV V2 Hotfix — MetaV2 nullable v0.4 — " + $now),
  "",
  "## Problema",
  "- normalize.ts usa null para evitar undefined em JsonValue.",
  "- MetaV2 ainda tipava campos como string|undefined, causando erro no build.",
  "",
  "## Fix",
  "- MetaV2 agora usa null (subtitle/accent/ethos) e mood obrigatório.",
  "",
  "## Observação",
  "- Não altera V1; só ajusta o contrato da camada V2."
) -join "`n"

$repPath = Join-Path $repDir "cv-v2-hotfix-types-metav2-nullable-v0_4.md"
WriteUtf8NoBom $repPath $rep
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

WL "[OK] Hotfix aplicado: types+normalize alinhados."