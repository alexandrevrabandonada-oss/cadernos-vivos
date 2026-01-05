param([switch]$SkipBuild)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function TestP([string]$p) { Test-Path -LiteralPath $p }
function EnsureDir([string]$p) { if (-not (TestP $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
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
  Write-Host ("[RUN] " + $exe + " " + $pretty)
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
function NewReport([string]$name, [string]$content, [string]$repo) {
  $repDir = Join-Path $repo "reports"
  EnsureDir $repDir
  $p = Join-Path $repDir $name
  WriteUtf8NoBom $p $content
  return $p
}

# tenta aproveitar bootstrap se existir (sem depender dele)
$repo = ResolveRepoHere
$boot = Join-Path $repo "tools\_bootstrap.ps1"
if (TestP $boot) {
  try { . $boot } catch {}
}

$npmExe = ResolveExe "npm.cmd"

$libPath  = Join-Path $repo "src\lib\cadernos.ts"
$pagePath = Join-Path $repo "src\app\c\[slug]\page.tsx"

Write-Host ("[DIAG] Repo: " + $repo)
Write-Host ("[DIAG] npm: " + $npmExe)
Write-Host ("[DIAG] cadernos.ts: " + $libPath)
Write-Host ("[DIAG] /c/[slug]/page.tsx: " + $pagePath)

if (-not (TestP $libPath)) { throw ("[STOP] Não achei: " + $libPath) }

# -------------------------
# PATCH 1: manter meta com campos extras (mood/theme etc)
# -------------------------
BackupFile $libPath
$raw0 = Get-Content -LiteralPath $libPath -Raw
$raw1 = $raw0

if ($raw1.Contains("CadernoMeta.parse(")) {
  $raw1 = $raw1.Replace("CadernoMeta.parse(", "CadernoMeta.passthrough().parse(")
} else {
  # fallback por regex (tolerando espaços)
  $raw1 = [regex]::Replace($raw1, 'CadernoMeta\s*\.\s*parse\(', 'CadernoMeta.passthrough().parse(')
}

if ($raw1 -ne $raw0) {
  WriteUtf8NoBom $libPath $raw1
  Write-Host "[OK] patched: cadernos.ts (CadernoMeta.passthrough().parse)"
} else {
  Write-Host "[WARN] cadernos.ts: não encontrei CadernoMeta.parse() para trocar."
}

# -------------------------
# PATCH 2: corrigir /c/[slug]/page.tsx se slug estiver vindo undefined
# (caso esteja usando params.slug sem await params)
# -------------------------
if (TestP $pagePath) {
  BackupFile $pagePath
  $p0 = Get-Content -LiteralPath $pagePath -Raw
  $p1 = $p0

  $hasPromiseParams = ($p1 -match 'params\s*:\s*Promise\s*<')
  $usesParamsSlug   = ($p1 -match 'params\.slug')
  $hasAwaitParams   = ($p1 -match 'await\s+params')
  $alreadyDestruct  = ($p1 -match 'const\s*\{\s*slug\s*\}\s*=\s*await\s+params')

  if ($hasPromiseParams -and $usesParamsSlug -and (-not $hasAwaitParams) -and (-not $alreadyDestruct)) {
    $m = [regex]::Match($p1, 'export\s+default\s+async\s+function\s+Page[^{]*\{')
    if ($m.Success) {
      $insertAt = $m.Index + $m.Length
      $ins = "`n  const { slug } = await params;`n"
      $p1 = $p1.Insert($insertAt, $ins)
      $p1 = $p1.Replace("params.slug", "slug")
      WriteUtf8NoBom $pagePath $p1
      Write-Host "[OK] patched: /c/[slug]/page.tsx (await params + slug fix)"
    } else {
      Write-Host "[WARN] /c/[slug]/page.tsx: não consegui achar assinatura do Page() para inserir await params."
    }
  } else {
    Write-Host "[OK] /c/[slug]/page.tsx: nada a corrigir (já parece correto)."
  }
} else {
  Write-Host "[WARN] Não achei /c/[slug]/page.tsx — pulei patch 2."
}

# -------------------------
# REPORT
# -------------------------
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$rep = @(
  ("# CV Hotfix — meta passthrough + slug guard v0.19 — " + $now),
  "",
  "## Mudanças",
  "- cadernos.ts: CadernoMeta.passthrough().parse() para não perder campos extras do meta (mood/theme/universe etc).",
  "- /c/[slug]/page.tsx: se estava usando params.slug sem await params, corrigido para evitar slug undefined.",
  "",
  "## Próximo",
  "- Engine: scaffold de novo caderno (criar pasta + meta + arquivos mínimos por slug)."
) -join "`n"

$repPath = NewReport "cv-hotfix-meta-passthrough-slug-guard-v0_19.md" $rep $repo
Write-Host ("[OK] Report: " + $repPath)

# -------------------------
# VERIFY
# -------------------------
Write-Host "[VERIFY] npm run lint..."
RunNative $repo $npmExe @("run","lint")

if (-not $SkipBuild) {
  Write-Host "[VERIFY] npm run build..."
  RunNative $repo $npmExe @("run","build")
} else {
  Write-Host "[VERIFY] build pulado (-SkipBuild)."
}

Write-Host ""
Write-Host "[OK] Hotfix aplicado."