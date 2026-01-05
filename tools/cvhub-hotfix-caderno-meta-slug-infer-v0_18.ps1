param(
  [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function WL([string]$s) { Write-Host $s }
function EnsureDir([string]$p) { if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }

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

function FindRepoRoot() {
  $here = (Get-Location).Path
  $p = $here
  for ($i=0; $i -lt 10; $i++) {
    if (Test-Path -LiteralPath (Join-Path $p "package.json")) { return $p }
    $parent = Split-Path -Parent $p
    if (-not $parent -or $parent -eq $p) { break }
    $p = $parent
  }
  throw ("[STOP] Rode na raiz do repo (onde tem package.json). Atual: " + $here)
}

function NewReportLocal([string]$repo, [string]$name, [string[]]$lines) {
  $rep = Join-Path $repo "reports"
  EnsureDir $rep
  $p = Join-Path $rep $name
  WriteUtf8NoBom $p ($lines -join "`n")
  return $p
}

# -------------------------
# DIAG
# -------------------------
$repo = FindRepoRoot
$npmExe = ResolveExe "npm.cmd"
$cadernosPath = Join-Path $repo "src\lib\cadernos.ts"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] cadernos.ts: " + $cadernosPath)

if (-not (Test-Path -LiteralPath $cadernosPath)) {
  throw ("[STOP] Não achei: " + $cadernosPath)
}

$raw = Get-Content -LiteralPath $cadernosPath -Raw
if (-not $raw) { throw "[STOP] cadernos.ts vazio/null." }

BackupFile $cadernosPath

# -------------------------
# PATCH 1: meta.slug opcional no schema
# -------------------------
$lines = $raw -split "`n"
$changedSchema = $false
for ($i=0; $i -lt $lines.Length; $i++) {
  $ln = $lines[$i]

  # troca somente se for slug: z.string() (e ainda não tiver optional)
  if ($ln -match '^\s*slug\s*:\s*z\.string\(\)\s*,?\s*$' -and ($ln -notmatch 'optional')) {
    $indent = ($ln -replace '(slug.*)$','')
    $lines[$i] = ($indent + 'slug: z.string().optional(),')
    $changedSchema = $true
  }

  # cobre casos tipo: slug: z.string().min(1),
  if ($ln -match '^\s*slug\s*:\s*z\.string\(\)\.min\(' -and ($ln -notmatch 'optional')) {
    # mantém o .min(...) e adiciona .optional() no fim (Zod: optional() após min não rola direto; então fazemos slug opcional sem min)
    # melhor: troca por z.string().optional()
    $indent2 = ($ln -replace '(slug.*)$','')
    $lines[$i] = ($indent2 + 'slug: z.string().optional(),')
    $changedSchema = $true
  }
}

# -------------------------
# PATCH 2: inferir slug após parse do meta
# -------------------------
$changedParse = $false
for ($i=0; $i -lt $lines.Length; $i++) {
  $ln = $lines[$i]

  # alvo típico:
  # const meta = CadernoMeta.parse(JSON.parse(await fs.readFile(metaPath, "utf8")));
  if ($ln -match 'const\s+meta\s*=\s*CadernoMeta\.parse\(') {
    # só mexe se ainda estiver no formato antigo com JSON.parse/fs.readFile na mesma linha
    if ($ln -match 'JSON\.parse\(await\s+fs\.readFile' -or $ln -match 'JSON\.parse\(await\s+fs\.readFile') {
      $indent = ($ln -replace '(const.*)$','')
      $newBlock = @(
        ($indent + 'const metaRaw = JSON.parse(await fs.readFile(metaPath, "utf8")) as unknown;'),
        ($indent + 'const metaParsed = CadernoMeta.parse(metaRaw);'),
        ($indent + 'const meta = { ...metaParsed, slug: metaParsed.slug ?? slug };')
      )
      # substitui a linha por 3 linhas
      $before = @()
      if ($i -gt 0) { $before = $lines[0..($i-1)] }
      $after = @()
      if ($i -lt ($lines.Length-1)) { $after = $lines[($i+1)..($lines.Length-1)] }
      $lines = @($before + $newBlock + $after)
      $changedParse = $true
      break
    }
  }
}

$patched = ($lines -join "`n")
if (-not $patched) { throw "[STOP] patch result vazio." }

WriteUtf8NoBom $cadernosPath $patched

WL ("[OK] patched: cadernos.ts (slug opcional + inferência)")
WL ("[OK] schema slug changed? " + $changedSchema)
WL ("[OK] meta parse changed? " + $changedParse)

# -------------------------
# REPORT
# -------------------------
$repLines = @(
("# Hotfix — Meta.slug opcional + inferir do folder v0.18 — " + (Get-Date -Format "yyyy-MM-dd HH:mm")),
"",
"## Problema",
"- Zod falhou: meta.json sem campo slug (cadernos novos).",
"",
"## Mudança",
"- CadernoMeta.slug agora é opcional.",
"- getCaderno(): após parse, força meta.slug = metaParsed.slug ?? slug.",
"",
"## Resultado esperado",
"- /c/meu-novo-caderno funciona mesmo se meta.json não tiver slug."
)

$repPath = NewReportLocal $repo "cv-hotfix-meta-slug-infer-v0_18.md" $repLines
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
WL "[OK] Hotfix v0.18 aplicado."