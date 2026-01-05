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

# -------------------------
# DIAG
# -------------------------
$repo = ResolveRepoHere
$npmExe = ResolveExe "npm.cmd"
$appDir = Join-Path $repo "src\app"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm:  " + $npmExe)
WL ("[DIAG] App:  " + $appDir)

if (-not (TestP $appDir)) { throw ("[STOP] Não achei src\app em: " + $appDir) }

# -------------------------
# PATCH
# -------------------------
$files = Get-ChildItem -Path $appDir -Recurse -File -Include *.ts,*.tsx
$patched = @()

foreach ($f in $files) {
  $raw = ""
  try { $raw = Get-Content -LiteralPath $f.FullName -Raw } catch { continue }
  if (-not $raw) { continue }

  # Só mexe quando o arquivo tiver CadernoHeader e estiver passando slug={...}
  if ($raw -match "CadernoHeader" -and $raw -match "slug=\{") {
    # remove somente a prop slug={...} (com espaços ao redor)
    $new = $raw -replace "\s*slug=\{[^}]+\}\s*", " "
    if ($new -ne $raw) {
      BackupFile $f.FullName
      WriteUtf8NoBom $f.FullName $new
      $patched += $f.FullName
      WL ("[OK] patched: " + $f.FullName)
    }
  }
}

if ($patched.Count -eq 0) {
  WL "[WARN] Nenhum arquivo precisou de patch (não achei CadernoHeader com slug=...)."
}

# -------------------------
# REPORT
# -------------------------
$repDir = Join-Path $repo "reports"
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$ts2 = Get-Date -Format "yyyyMMdd_HHmmss"
$reportPath = Join-Path $repDir ("cv-3e-hotfix-cadernoheader-remove-slug-prop-" + $ts2 + ".md")

$lines = @()
$lines += ("# CV-3e — Hotfix: remover prop slug do CadernoHeader — " + $now)
$lines += ""
$lines += "## Motivo"
$lines += "- O componente CadernoHeader (default) não aceita `slug` nas props; apenas `title/subtitle/ethos`."
$lines += ""
$lines += "## Arquivos alterados"
if ($patched.Count -eq 0) {
  $lines += "- (nenhum)"
} else {
  foreach ($p in $patched) { $lines += ("- " + $p.Replace($repo + "\", "")) }
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
WL "[OK] Hotfix aplicado. Agora: npm run dev e testa /c/poluicao-vr/mapa"