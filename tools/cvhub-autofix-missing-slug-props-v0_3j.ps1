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

function ResolveRepo() {
  $here = (Get-Location).Path
  if (TestP (Join-Path $here "package.json")) { return $here }

  $child = Join-Path $here "cadernos-vivos"
  if (TestP (Join-Path $child "package.json")) { return $child }

  throw ("[STOP] Rode na raiz do repo (onde tem package.json). Atual: " + $here)
}

function PatchMissingSlug([string]$raw, [string]$componentName) {
  # Injeta slug={slug} em tags JSX do tipo <Component ...> quando não existe slug=
  $pattern = '(?s)<' + [regex]::Escape($componentName) + '(?![^>]*\bslug=)'
  $repl = '<' + $componentName + ' slug={slug}'
  $out = [regex]::Replace($raw, $pattern, $repl)
  return $out
}

# -------------------------
# DIAG
# -------------------------
$repo = ResolveRepo
$npmExe = ResolveExe "npm.cmd"

$scopeDir = Join-Path $repo 'src\app\c\[slug]'
if (-not (TestP $scopeDir)) {
  throw ("[STOP] Não achei o escopo: " + $scopeDir)
}

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] Scope: " + $scopeDir)

$targets = @("NavPills","AulaProgress","DebateBoard","TerritoryMap")

$files = Get-ChildItem -LiteralPath $scopeDir -Recurse -File -Filter *.tsx
WL ("[DIAG] Arquivos TSX no escopo: " + $files.Count)

# -------------------------
# PATCH
# -------------------------
$patched = @()

foreach ($f in $files) {
  $raw = Get-Content -LiteralPath $f.FullName -Raw
  $orig = $raw

  foreach ($t in $targets) {
    $raw = PatchMissingSlug $raw $t
  }

  if ($raw -ne $orig) {
    BackupFile $f.FullName
    WriteUtf8NoBom $f.FullName $raw
    $patched += $f.FullName
    WL ("[OK] patched: " + $f.FullName)
  }
}

if ($patched.Count -eq 0) {
  WL "[OK] Nenhum patch necessário (não achei tags faltando slug)."
} else {
  WL ("[OK] Total patched: " + $patched.Count)
}

# -------------------------
# REPORT
# -------------------------
$repDir = Join-Path $repo "reports"
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repDir "cv-3j-autofix-missing-slug-props.md"

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# CV-3j — Autofix missing slug props — " + $now)
$lines.Add("")
$lines.Add("## Estratégia")
$lines.Add("- Varre `src/app/c/[slug]/` e injeta `slug={slug}` automaticamente em tags JSX que usam componentes que exigem `slug`.")
$lines.Add("- Alvos: " + ($targets -join ", "))
$lines.Add("")
$lines.Add("## Arquivos alterados")
if ($patched.Count -eq 0) {
  $lines.Add("- (nenhum)")
} else {
  foreach ($p in $patched) { $lines.Add("- " + $p) }
}
$lines.Add("")
$lines.Add("## Verify")
$lines.Add("- npm run lint")
$lines.Add("- npm run build")

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

WL "[OK] Autofix concluído."