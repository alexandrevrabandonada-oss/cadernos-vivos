param(
  [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function WL([string]$s) { Write-Host $s }

function EnsureDir([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

function WriteUtf8NoBom([string]$p, [string]$content) {
  $parent = Split-Path -Parent $p
  if ($parent) { EnsureDir $parent }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($p, $content, $enc)
}

function BackupFile([string]$p) {
  if (Test-Path -LiteralPath $p) {
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
  if (Test-Path -LiteralPath (Join-Path $here "package.json")) { return $here }
  $p1 = Split-Path -Parent $here
  if ($p1 -and (Test-Path -LiteralPath (Join-Path $p1 "package.json"))) { return $p1 }
  throw ("[STOP] Rode na raiz do repo (onde tem package.json). Atual: " + $here)
}

function EnsureSlugPropInTag([string]$raw, [string]$tagName) {
  # Insere slug={slug} se dentro da tag ainda não existir "slug="
  # Ex: <NavPills ...> => <NavPills slug={slug} ...>
  $rx = [regex]::new("<" + $tagName + "(\s+)(?![^>]*\bslug=)", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  return $rx.Replace($raw, "<" + $tagName + "`$1slug={slug} ", 999)
}

# -------------------------
# DIAG
# -------------------------
$repo = ResolveRepoHere
$npmExe = ResolveExe "npm.cmd"
$appRoot = Join-Path $repo "src\app"
$scope = Join-Path $appRoot "c\[slug]"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] Scope: " + $scope)

if (-not (Test-Path -LiteralPath $scope)) {
  throw ("[STOP] Não achei o diretório esperado: " + $scope)
}

# -------------------------
# PATCH
# -------------------------
$pages = Get-ChildItem -LiteralPath $scope -Recurse -File -Filter "page.tsx"

if (-not $pages -or $pages.Count -eq 0) {
  throw "[STOP] Não encontrei page.tsx dentro de src/app/c/[slug]."
}

$changed = @()
foreach ($f in $pages) {
  $p = $f.FullName
  $raw = [System.IO.File]::ReadAllText($p)

  $before = $raw
  if ($raw -match "<NavPills\b")      { $raw = EnsureSlugPropInTag $raw "NavPills" }
  if ($raw -match "<AulaProgress\b")  { $raw = EnsureSlugPropInTag $raw "AulaProgress" }
  if ($raw -match "<DebateBoard\b")   { $raw = EnsureSlugPropInTag $raw "DebateBoard" }
  if ($raw -match "<TerritoryMap\b")  { $raw = EnsureSlugPropInTag $raw "TerritoryMap" }

  if ($raw -ne $before) {
    BackupFile $p
    WriteUtf8NoBom $p $raw
    $changed += $p
    WL ("[OK] patched: " + $p)
  }
}

WL ("[DIAG] pages patched: " + $changed.Count)

# -------------------------
# REPORT
# -------------------------
$repDir = Join-Path $repo "reports"
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repDir "cv-3m-hotfix-pass-slug.md"

$lines = @()
$lines += "# CV-3m — Hotfix: sempre passar slug — " + $now
$lines += ""
$lines += "## O que foi feito"
$lines += "- Varreu src/app/c/[slug]/**/page.tsx e garantiu slug={slug} nos componentes:"
$lines += "  - NavPills"
$lines += "  - AulaProgress"
$lines += "  - DebateBoard"
$lines += "  - TerritoryMap"
$lines += ""
$lines += "## Arquivos alterados"
if ($changed.Count -gt 0) {
  foreach ($c in $changed) { $lines += "- " + $c.Replace($repo + "\", "") }
} else {
  $lines += "- (nenhum; já estava ok)"
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
WL "[OK] Hotfix concluído. Se build passou, abre /c/poluicao-vr e testa abas (trilha, debate, mapa etc)."