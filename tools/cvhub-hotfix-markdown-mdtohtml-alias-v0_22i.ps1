param(
  [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- bootstrap (preferencial)
$bootstrap = Join-Path $PSScriptRoot "_bootstrap.ps1"
if (Test-Path -LiteralPath $bootstrap) { . $bootstrap }

# --- fallbacks mínimos (se algo faltar no bootstrap)
if (-not (Get-Command WL -ErrorAction SilentlyContinue)) { function WL([string]$s){ Write-Host $s } }
if (-not (Get-Command EnsureDir -ErrorAction SilentlyContinue)) {
  function EnsureDir([string]$p) { if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
}
if (-not (Get-Command WriteUtf8NoBom -ErrorAction SilentlyContinue)) {
  function WriteUtf8NoBom([string]$p, [string]$content) {
    $parent = Split-Path -Parent $p
    if ($parent) { EnsureDir $parent }
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($p, $content, $enc)
  }
}
if (-not (Get-Command BackupFile -ErrorAction SilentlyContinue)) {
  function BackupFile([string]$p) {
    if (Test-Path -LiteralPath $p) {
      $ts = (Get-Date -Format "yyyyMMdd_HHmmss")
      $bakDir = Join-Path (Get-Location) "tools\_patch_backup"
      EnsureDir $bakDir
      $leaf = Split-Path -Leaf $p
      Copy-Item -LiteralPath $p -Destination (Join-Path $bakDir ($leaf + "." + $ts + ".bak")) -Force
    }
  }
}
if (-not (Get-Command ResolveExe -ErrorAction SilentlyContinue)) {
  function ResolveExe([string]$name) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { return $cmd.Source }
    return $name
  }
}
if (-not (Get-Command RunNative -ErrorAction SilentlyContinue)) {
  function RunNative([string]$cwd, [string]$exe, [string[]]$cmdArgs) {
    $pretty = ($cmdArgs -join " ")
    WL ("[RUN] " + $exe + " " + $pretty)
    Push-Location $cwd
    & $exe @cmdArgs
    $code = $LASTEXITCODE
    Pop-Location
    if ($code -ne 0) { throw ("[STOP] comando falhou (exit " + $code + "): " + $exe + " " + $pretty) }
  }
}
if (-not (Get-Command ResolveRepoHere -ErrorAction SilentlyContinue)) {
  function ResolveRepoHere() {
    $here = (Get-Location).Path
    if (Test-Path -LiteralPath (Join-Path $here "package.json")) { return $here }
    throw ("[STOP] Rode na raiz do repo (onde tem package.json). Atual: " + $here)
  }
}
if (-not (Get-Command NewReport -ErrorAction SilentlyContinue)) {
  function NewReport([string]$fileName, [string]$content) {
    $repo = ResolveRepoHere
    $repDir = Join-Path $repo "reports"
    EnsureDir $repDir
    $p = Join-Path $repDir $fileName
    WriteUtf8NoBom $p $content
    return $p
  }
}

# -------------------------
# DIAG
# -------------------------
$repo = ResolveRepoHere
$npmExe = ResolveExe "npm.cmd"
$mdPath = Join-Path $repo "src\lib\markdown.ts"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] markdown: " + $mdPath)

if (-not (Test-Path -LiteralPath $mdPath)) {
  throw ("[STOP] Não achei markdown.ts em: " + $mdPath)
}

# -------------------------
# PATCH
# -------------------------
BackupFile $mdPath
$raw = Get-Content -LiteralPath $mdPath -Raw
if (-not $raw) { throw "[STOP] markdown.ts veio vazio (Get-Content -Raw)."; }

if ($raw -match "export\s+(async\s+function|const)\s+mdToHtml") {
  WL "[OK] mdToHtml já existe em markdown.ts — nada a fazer."
} else {
  $append = @(
    "",
    "// compat: componentes antigos importam mdToHtml",
    "export async function mdToHtml(md: string, opts: MarkdownRenderOptions = {}): Promise<string> {",
    "  return markdownToHtml(md, opts);",
    "}",
    ""
  ) -join "`n"

  $raw2 = $raw.TrimEnd() + $append
  WriteUtf8NoBom $mdPath $raw2
  WL "[OK] patched: src/lib/markdown.ts (alias mdToHtml async -> markdownToHtml)"
}

# -------------------------
# REPORT
# -------------------------
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$rep = @(
("# CV Hotfix — mdToHtml alias v0_22i — " + $now),
"",
"## O que foi feito",
"- Adicionou export async function mdToHtml(...) em src/lib/markdown.ts como alias para markdownToHtml.",
"- Corrige build que falhava em src/components/Markdown.tsx (import mdToHtml).",
"",
"## Verify",
"- npm run lint",
"- npm run build"
) -join "`n"

$repPath = NewReport "cv-hotfix-mdtohtml-alias-v0_22i.md" $rep
WL ("[OK] Report: " + $repPath)

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
WL "[OK] Hotfix mdToHtml aplicado (v0_22i)."