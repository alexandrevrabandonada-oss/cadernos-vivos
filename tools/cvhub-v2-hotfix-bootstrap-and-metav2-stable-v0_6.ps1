# CV — V2 Hotfix — Bootstrap ResolveExe + MetaV2 estável (sem undefined) — v0_6
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
function FindFuncRange($raw, $needle) {
  $idx = $raw.IndexOf($needle, [System.StringComparison]::OrdinalIgnoreCase)
  if ($idx -lt 0) { return $null }

  $braceStart = $raw.IndexOf("{", $idx)
  if ($braceStart -lt 0) { return $null }

  $depth = 0
  for ($i = $braceStart; $i -lt $raw.Length; $i++) {
    $ch = $raw[$i]
    if ($ch -eq "{") { $depth++ }
    elseif ($ch -eq "}") {
      $depth--
      if ($depth -eq 0) { return @{ Start = $idx; End = ($i + 1) } }
    }
  }
  return $null
}
function RunCmd($exe, $args) {
  Write-Host ("[RUN] " + $exe + " " + ($args -join " "))
  & $exe @args
  if ($LASTEXITCODE -ne 0) { throw ("[STOP] comando falhou (exit " + $LASTEXITCODE + "): " + $exe) }
}

$repo = Get-Location
Write-Host ("[DIAG] Repo: " + $repo)

# --- Paths
$bootstrap = Join-Path $repo "tools\_bootstrap.ps1"
$types = Join-Path $repo "src\lib\v2\types.ts"

Write-Host ("[DIAG] bootstrap: " + $bootstrap)
Write-Host ("[DIAG] types: " + $types)

# --- Resolve npm.cmd (não depende do bootstrap)
$npmCmd = $null
$cmd = Get-Command "npm.cmd" -ErrorAction SilentlyContinue
if ($cmd) { $npmCmd = $cmd.Source } else { $npmCmd = "npm.cmd" }
Write-Host ("[DIAG] npm.cmd: " + $npmCmd)

# -------------------------
# PATCH 1: tools/_bootstrap.ps1 — ResolveExe deve retornar STRING única
# -------------------------
if (Test-Path -LiteralPath $bootstrap) {
  $bk = BackupFile $bootstrap
  $raw = Get-Content -LiteralPath $bootstrap -Raw

  $needle = "function ResolveExe"
  $range = FindFuncRange $raw $needle

  $replacement = @(
    "function ResolveExe {",
    "  param([string[]]`$Candidates)",
    "  if (-not `$Candidates -or `$Candidates.Count -eq 0) { return `$null }",
    "  foreach (`$c in `$Candidates) {",
    "    if (-not `$c) { continue }",
    "    `$cmd = Get-Command `$c -ErrorAction SilentlyContinue",
    "    if (`$cmd) { return @(`$cmd)[0].Source }",
    "  }",
    "  return `$Candidates[0]",
    "}"
  ) -join "`n"

  if ($range -ne $null) {
    $before = $raw.Substring(0, $range.Start)
    $after = $raw.Substring($range.End)
    $raw2 = $before + $replacement + $after
    WriteUtf8NoBom $bootstrap $raw2
    Write-Host "[OK] patched: tools/_bootstrap.ps1 (ResolveExe retorna string)"
    if ($bk) { Write-Host ("[BK] " + $bk) }
  } else {
    # Se não achar, anexa no final (não destrói nada)
    $raw2 = $raw + "`n`n" + $replacement + "`n"
    WriteUtf8NoBom $bootstrap $raw2
    Write-Host "[OK] appended: tools/_bootstrap.ps1 (ResolveExe criado)"
    if ($bk) { Write-Host ("[BK] " + $bk) }
  }
} else {
  Write-Host "[WARN] tools/_bootstrap.ps1 não encontrado. Pulei PATCH 1."
}

# -------------------------
# PATCH 2: src/lib/v2/types.ts — MetaV2 sem opcionais (sem undefined) + ui obrigatório
# -------------------------
EnsureDir (Split-Path -Parent $types)
$bk2 = BackupFile $types

$typesText = @(
  "// AUTO-GERADO pelo tijolo v0_6 — estável (JSON real: sem undefined).",
  "",
  "export type UiDefault = 'v1' | 'v2';",
  "",
  "export type JsonPrimitive = string | number | boolean | null;",
  "export type JsonValue = JsonPrimitive | JsonValue[] | { [k: string]: JsonValue };",
  "",
  "// Regra: nada opcional aqui (opcional => vira undefined). Campo ausente = null.",
  "export type MetaV2 = {",
  "  slug: string;",
  "  title: string;",
  "  subtitle: string | null;",
  "  mood: string;",
  "  accent: string | null;",
  "  ethos: string | null;",
  "  ui: { default: UiDefault };",
  "  [k: string]: JsonValue;",
  "};",
  "",
  "export type CadernoV2 = {",
  "  meta: MetaV2;",
  "  panorama: string;",
  "  referencias: string;",
  "  mapa: JsonValue;",
  "  acervo: JsonValue;",
  "  debate: JsonValue;",
  "  registro: JsonValue;",
  "};",
  ""
) -join "`n"

WriteUtf8NoBom $types $typesText
Write-Host "[OK] wrote: src/lib/v2/types.ts (MetaV2 estável: null > undefined; ui obrigatório)"
if ($bk2) { Write-Host ("[BK] " + $bk2) }

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
$reportPath = Join-Path $reports ("cv-v2-hotfix-bootstrap-and-metav2-stable-v0_6.md")

$report = @(
  "# CV — Hotfix v0_6 — Bootstrap + MetaV2 estável",
  "",
  "## O que estava errado (causa raiz)",
  "- MetaV2 tinha propriedades opcionais e index signature JsonValue; opcional vira T|undefined e JSON não aceita undefined.",
  "- tools/_bootstrap.ps1 estava resolvendo executável como array (ex.: npm.cmd npm.exe npm) e isso quebra o & $exe.",
  "",
  "## Fix",
  "- ResolveExe agora sempre retorna UMA string (primeiro executável encontrado).",
  "- MetaV2 refeito: nada opcional; ausências viram null; ui.default obrigatório.",
  "",
  "## Arquivos",
  "- tools/_bootstrap.ps1",
  "- src/lib/v2/types.ts",
  "",
  "## Verify",
  "- npm run lint",
  "- npm run build",
  ""
) -join "`n"

WriteUtf8NoBom $reportPath $report
Write-Host ("[OK] Report: " + $reportPath)
Write-Host "[OK] v0_6 aplicado."