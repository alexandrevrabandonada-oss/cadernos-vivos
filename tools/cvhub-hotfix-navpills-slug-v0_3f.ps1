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

function FixCadernoHeaderSlug([string]$raw) {
  # remove slug={...} do <CadernoHeader ...>
  return ([regex]::Replace($raw, '(<CadernoHeader[^>]*?)\s+slug=\{[^}]+\}([^>]*?>)', '$1$2'))
}

function FixNavPillsSlug([string]$raw) {
  # troca <NavPills /> e <NavPills/> por <NavPills slug={slug} />
  $out = $raw
  $out = [regex]::Replace($out, '<NavPills\s*/>', '<NavPills slug={slug} />')
  return $out
}

# -------------------------
# DIAG
# -------------------------
$repo = ResolveRepoHere
$npmExe = ResolveExe "npm.cmd"
$appDir = Join-Path $repo "src\app"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] AppDir: " + $appDir)

if (-not (TestP $appDir)) {
  throw ("[STOP] Não achei src\app em: " + $appDir)
}

$files = Get-ChildItem -Path $appDir -Recurse -File -Filter *.tsx

$needNavFix = @()
$needHeaderFix = @()

foreach ($f in $files) {
  $raw = [System.IO.File]::ReadAllText($f.FullName)

  if ($raw -match '<NavPills\s*/>' -and $raw -notmatch '<NavPills[^>]*slug\s*=') {
    $needNavFix += $f.FullName
  }

  if ($raw -match '<CadernoHeader[^>]*\s+slug=\{') {
    $needHeaderFix += $f.FullName
  }
}

WL ("[DIAG] NavPills sem slug: " + $needNavFix.Count)
foreach ($p in $needNavFix) { WL ("  - " + $p) }

WL ("[DIAG] CadernoHeader com slug=...: " + $needHeaderFix.Count)
foreach ($p in $needHeaderFix) { WL ("  - " + $p) }

# -------------------------
# PATCH
# -------------------------
$patched = @()

foreach ($f in $files) {
  $raw = [System.IO.File]::ReadAllText($f.FullName)
  $before = $raw

  # só adiciona slug no NavPills se existir "slug" no arquivo (pra não quebrar)
  if ($raw -match '<NavPills\s*/>' -and $raw -notmatch '<NavPills[^>]*slug\s*=' ) {
    if ($raw -match '\bslug\b') {
      $raw = FixNavPillsSlug $raw
    } else {
      WL ("[WARN] Achei <NavPills /> mas não encontrei variável 'slug' no arquivo (não mexi): " + $f.FullName)
    }
  }

  if ($raw -match '<CadernoHeader[^>]*\s+slug=\{') {
    $raw = FixCadernoHeaderSlug $raw
  }

  if ($raw -ne $before) {
    BackupFile $f.FullName
    WriteUtf8NoBom $f.FullName $raw
    $patched += $f.FullName
    WL ("[OK] patched: " + $f.FullName)
  }
}

# -------------------------
# REPORT
# -------------------------
$repDir = Join-Path $repo "reports"
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repDir "cv-3f-hotfix-navpills-slug.md"

$lines = @()
$lines += "# CV-3f — Hotfix NavPills slug + CadernoHeader slug — $now"
$lines += ""
$lines += "## O que foi corrigido"
$lines += "- Paginas com `<NavPills />` agora viram `<NavPills slug={slug} />` (quando a variavel `slug` existe no arquivo)"
$lines += "- Remocao de `slug={...}` em `<CadernoHeader ...>` (CadernoHeader nao aceita slug)"
$lines += ""
$lines += "## Arquivos patchados"
if ($patched.Count -eq 0) {
  $lines += "- (nenhum arquivo precisou de patch)"
} else {
  foreach ($p in $patched) { $lines += "- " + $p.Replace($repo + "\", "") }
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