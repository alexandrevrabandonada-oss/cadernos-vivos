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

function HasAulaProgressWithoutSlug([string]$raw) {
  $m = [regex]::Matches($raw, '<AulaProgress[^>]*>', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  foreach ($x in $m) {
    $tag = $x.Value
    if ($tag -notmatch '\bslug\s*=') { return $true }
  }
  return $false
}

function PatchAulaProgressAddSlug([string]$raw) {
  $out = $raw
  $matches = [regex]::Matches($out, '<AulaProgress[^>]*>', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if ($matches.Count -eq 0) { return $out }

  for ($i = $matches.Count - 1; $i -ge 0; $i--) {
    $x = $matches[$i]
    $tag = $x.Value
    if ($tag -match '\bslug\s*=') { continue }

    $patchedTag = $tag -replace '<AulaProgress\b', '<AulaProgress slug={slug}'
    $out = $out.Substring(0, $x.Index) + $patchedTag + $out.Substring($x.Index + $x.Length)
  }
  return $out
}

# -------------------------
# DIAG
# -------------------------
$repo = ResolveRepoHere
$npmExe = ResolveExe "npm.cmd"
$appScope = Join-Path $repo "src\app\c\[slug]"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] Scope (Literal): " + $appScope)

if (-not (TestP $appScope)) {
  throw ("[STOP] Não achei: " + $appScope)
}

# IMPORTANTE: usar -LiteralPath por causa de pastas com [ ] (wildcards)
$files = Get-ChildItem -LiteralPath $appScope -Recurse -File -Filter *.tsx

$hits = @()
foreach ($f in $files) {
  $raw = [System.IO.File]::ReadAllText($f.FullName)
  if ($raw -match '<AulaProgress' -and (HasAulaProgressWithoutSlug $raw)) {
    $hits += $f.FullName
  }
}

WL ("[DIAG] Arquivos com <AulaProgress ...> sem slug=: " + $hits.Count)
foreach ($p in $hits) { WL ("  - " + $p) }

# -------------------------
# PATCH
# -------------------------
$patched = @()

foreach ($p in $hits) {
  $raw = [System.IO.File]::ReadAllText($p)
  $before = $raw

  # segurança: só injeta slug={slug} se o arquivo tiver o identificador slug em algum lugar
  if ($raw -notmatch '\bslug\b') {
    WL ("[WARN] Sem identificador 'slug' no arquivo; pulei: " + $p)
    continue
  }

  $raw = PatchAulaProgressAddSlug $raw

  if ($raw -ne $before) {
    BackupFile $p
    WriteUtf8NoBom $p $raw
    $patched += $p
    WL ("[OK] patched: " + $p)
  }
}

# -------------------------
# REPORT
# -------------------------
$repDir = Join-Path $repo "reports"
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repDir "cv-3h-hotfix-aulaprogress-slug.md"

$lines = @()
$lines += ("# CV-3h — Hotfix AulaProgress slug — " + $now)
$lines += ""
$lines += "## Problema"
$lines += "TypeScript build: AulaProgress exige prop slug e havia chamada sem slug."
$lines += ""
$lines += "## Correcao"
$lines += "Dentro de src/app/c/[slug], adiciona slug={slug} em <AulaProgress ...> quando nao existir slug=."
$lines += ""
$lines += "## Arquivos patchados"
if ($patched.Count -eq 0) {
  $lines += "(nenhum arquivo precisou de patch — se o build ainda falhar, o arquivo pode estar fora do escopo esperado)"
} else {
  foreach ($pp in $patched) { $lines += ("- " + $pp.Replace($repo + "\", "")) }
}
$lines += ""
$lines += "## Verify"
$lines += "- npm run lint"
$lines += "- npm run build"

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
WL "[OK] Hotfix aplicado."