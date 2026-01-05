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

function DefaultMoodFromSlug([string]$slug) {
  $s = ($slug | ForEach-Object { $_.ToLowerInvariant() })
  if ($s.Contains("poluicao")) { return "smoke" }
  if ($s.Contains("trabalho")) { return "steel" }
  if ($s.Contains("memoria")) { return "archive" }
  if ($s.Contains("eco")) { return "green" }
  return "urban"
}

function HasProp($obj, [string]$name) {
  if ($null -eq $obj) { return $false }
  $p = $obj.PSObject.Properties[$name]
  return ($null -ne $p)
}

# -------------------------
# DIAG
# -------------------------
$repo = ResolveRepoHere
$npmExe = ResolveExe "npm.cmd"

$contentRoot = Join-Path $repo "content\cadernos"
$repDir = Join-Path $repo "reports"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] content: " + $contentRoot)

if (-not (TestP $contentRoot)) { throw ("[STOP] Não achei content\cadernos em: " + $contentRoot) }

$metaFiles = Get-ChildItem -LiteralPath $contentRoot -Recurse -Filter "meta.json" -File -ErrorAction SilentlyContinue
$metaCount = 0
if ($metaFiles) { $metaCount = @($metaFiles).Count }
WL ("[DIAG] meta.json encontrados: " + $metaCount)

# -------------------------
# PATCH
# -------------------------
$changed = 0
$warns = New-Object System.Collections.Generic.List[string]

foreach ($mf in @($metaFiles)) {
  $dir = Split-Path -Parent $mf.FullName
  $slug = Split-Path -Leaf $dir

  $raw = Get-Content -LiteralPath $mf.FullName -Raw -ErrorAction Stop
  if ([string]::IsNullOrWhiteSpace($raw)) {
    $warns.Add(("WARN meta.json vazio: " + $mf.FullName))
    continue
  }

  $obj = $null
  try {
    $obj = $raw | ConvertFrom-Json -ErrorAction Stop
  } catch {
    $warns.Add(("WARN meta.json inválido: " + $mf.FullName))
    continue
  }

  $did = $false

  # mood
  $needMood = $true
  if (HasProp $obj "mood") {
    $v = [string]$obj.mood
    if (-not [string]::IsNullOrWhiteSpace($v)) { $needMood = $false }
  }
  if ($needMood) {
    $m = DefaultMoodFromSlug $slug
    $obj | Add-Member -NotePropertyName "mood" -NotePropertyValue $m -Force
    $did = $true
  }

  # accent (só se faltar)
  $needAccent = $true
  if (HasProp $obj "accent") {
    $a = [string]$obj.accent
    if (-not [string]::IsNullOrWhiteSpace($a)) { $needAccent = $false }
  }
  if ($needAccent) {
    $obj | Add-Member -NotePropertyName "accent" -NotePropertyValue "#fbbf24" -Force
    $did = $true
  }

  # checagens leves (não autocorrige, só alerta)
  if (-not (HasProp $obj "title"))    { $warns.Add(("WARN sem title: " + $mf.FullName)) }
  if (-not (HasProp $obj "subtitle")) { $warns.Add(("WARN sem subtitle: " + $mf.FullName)) }
  if (-not (HasProp $obj "ethos"))    { $warns.Add(("WARN sem ethos: " + $mf.FullName)) }

  if ($did) {
    $out = $obj | ConvertTo-Json -Depth 64
    WriteUtf8NoBom $mf.FullName ($out + "`n")
    $changed++
    WL ("[OK] meta patch: " + $slug + "  (" + $mf.FullName + ")")
  }
}

WL ("[OK] meta.json atualizados: " + $changed)

# -------------------------
# REPORT
# -------------------------
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repDir "cv-engine-4a-content-meta-moods-v0_15.md"

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add(("# CV Engine-4A — Meta moods/accent — " + $now))
$lines.Add("")
$lines.Add("## O que fez")
$lines.Add("- Varreu content/cadernos/**/meta.json")
$lines.Add("- Garantiu campo mood (default por slug: smoke/steel/archive/green/urban)")
$lines.Add("- Garantiu campo accent somente se faltava (default #fbbf24)")
$lines.Add("")
$lines.Add("## Resultado")
$lines.Add(("- meta.json encontrados: " + $metaCount))
$lines.Add(("- meta.json alterados: " + $changed))
$lines.Add("")
if ($warns.Count -gt 0) {
  $lines.Add("## Avisos")
  foreach ($w in $warns) { $lines.Add(("- " + $w)) }
} else {
  $lines.Add("## Avisos")
  $lines.Add("- nenhum")
}
$lines.Add("")
$lines.Add("## Próximo")
$lines.Add("- Engine-4B: Validador mais rígido (schema) + scaffold para criar novo caderno pronto")

WriteUtf8NoBom $reportPath ($lines -join "`n")
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
WL "[OK] Engine-4A aplicado."