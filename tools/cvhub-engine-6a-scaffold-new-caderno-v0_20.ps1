param(
  [Parameter(Mandatory=$true)][string]$Slug,
  [string]$Title = "",
  [string]$Mood = "urban",
  [switch]$Force,
  [switch]$SkipBuild
)

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
function NewReport([string]$name, [string[]]$lines, [string]$repo) {
  $repDir = Join-Path $repo "reports"
  EnsureDir $repDir
  $p = Join-Path $repDir $name
  WriteUtf8NoBom $p ($lines -join "`n")
  return $p
}

# --------------------------------
# Helpers
# --------------------------------
function NormalizeSlug([string]$s) {
  $t = ($s.Trim().ToLowerInvariant())
  # troca espaços/underscores por hífen
  $t = $t -replace '[\s_]+','-'
  # remove tudo que não seja a-z 0-9 hífen
  $t = $t -replace '[^a-z0-9\-]',''
  # colapsa hífens
  $t = $t -replace '\-+','-'
  $t = $t.Trim('-')
  if (-not $t) { throw "[STOP] slug inválido (ficou vazio após normalização)." }
  return $t
}

# --------------------------------
# DIAG
# --------------------------------
$repo = ResolveRepoHere
$npmExe = ResolveExe "npm.cmd"

$contentRoot = Join-Path $repo "content\cadernos"
if (-not (TestP $contentRoot)) { throw ("[STOP] Não achei content\cadernos em: " + $contentRoot) }

$slugN = NormalizeSlug $Slug
if (-not $Title) { $Title = $slugN }

$targetDir = Join-Path $contentRoot $slugN

Write-Host ("[DIAG] Repo: " + $repo)
Write-Host ("[DIAG] npm: " + $npmExe)
Write-Host ("[DIAG] content root: " + $contentRoot)
Write-Host ("[DIAG] slug: " + $slugN)
Write-Host ("[DIAG] title: " + $Title)
Write-Host ("[DIAG] mood: " + $Mood)
Write-Host ("[DIAG] target: " + $targetDir)

if ((TestP $targetDir) -and (-not $Force)) {
  throw "[STOP] Pasta do caderno já existe. Use -Force para sobrescrever arquivos faltantes (não apaga nada)."
}

# escolhe um caderno-modelo existente (primeiro)
$modelDir = Get-ChildItem -LiteralPath $contentRoot -Directory | Select-Object -First 1
if (-not $modelDir) { throw "[STOP] Não existe nenhum caderno em content\cadernos para usar como modelo." }
$modelPath = $modelDir.FullName

Write-Host ("[DIAG] modelo: " + $modelPath)

# lista de arquivos "core" que vamos tentar replicar (se existirem no modelo)
$coreNames = @(
  "meta.json",
  "panorama.md",
  "referencias.md",
  "refs.md",
  "acervo.json",
  "debate.json",
  "mapa.json",
  "trilha.json",
  "quiz.json",
  "pratica.json",
  "registro.json"
)

$toCreate = @()
foreach ($n in $coreNames) {
  $mp = Join-Path $modelPath $n
  if (TestP $mp) { $toCreate += $n }
}

# se nada encontrado, ainda assim cria o mínimo
if ($toCreate.Count -eq 0) {
  $toCreate = @("meta.json","panorama.md","acervo.json","debate.json","mapa.json","trilha.json","quiz.json","registro.json")
  Write-Host "[WARN] modelo não tinha arquivos core detectáveis; vou criar mínimo padrão."
}

Write-Host ("[DIAG] arquivos base a criar: " + ($toCreate -join ", "))

# --------------------------------
# PATCH
# --------------------------------
EnsureDir $targetDir

# meta.json (sempre reescreve — é o “contrato”)
$metaObj = [ordered]@{
  slug  = $slugN
  title = $Title
  mood  = $Mood
  updatedAt = (Get-Date).ToString("yyyy-MM-dd")
}
$metaJson = ($metaObj | ConvertTo-Json -Depth 10)
WriteUtf8NoBom (Join-Path $targetDir "meta.json") $metaJson
Write-Host "[OK] wrote: meta.json"

foreach ($rel in $toCreate) {
  if ($rel -eq "meta.json") { continue }

  $dst = Join-Path $targetDir $rel
  if (TestP $dst) {
    Write-Host ("[OK] exists: " + $rel)
    continue
  }

  $src = Join-Path $modelPath $rel
  if (TestP $src) {
    Copy-Item -LiteralPath $src -Destination $dst -Force
    Write-Host ("[OK] copied: " + $rel)
    continue
  }

  # fallback content se não existir no modelo
  if ($rel.EndsWith(".md")) {
    $md = @(
      ("# " + $Title),
      "",
      "Texto inicial deste caderno.",
      "",
      "Sugestão: descreva o contexto, o problema e a proposta em linguagem simples."
    ) -join "`n"
    WriteUtf8NoBom $dst $md
    Write-Host ("[OK] wrote: " + $rel)
  } elseif ($rel.EndsWith(".json")) {
    $json = "{}"
    WriteUtf8NoBom $dst $json
    Write-Host ("[OK] wrote: " + $rel)
  }
}

# --------------------------------
# REPORT
# --------------------------------
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$lines = @(
  ("# CV Engine-6A — Scaffold de Novo Caderno v0.20 — " + $now),
  "",
  "## Criado",
  ("- Slug: " + $slugN),
  ("- Pasta: content/cadernos/" + $slugN),
  ("- Arquivos: " + ($toCreate -join ", ")),
  "",
  "## Notas",
  "- meta.json inclui slug/title/mood e updatedAt.",
  "- O layout/universe do motor já cuida do universo por slug + mood.",
  "",
  "## Próximo",
  "- Padronizar meta do caderno (campos opcionais): subtitle, cover, accent, tags.",
  "- Tijolo Engine-6B: gerador de aula inicial (aula-1) no formato esperado pelo motor."
)
$repPath = NewReport ("cv-engine-6a-scaffold-new-caderno-v0_20.md") $lines $repo
Write-Host ("[OK] Report: " + $repPath)

# --------------------------------
# VERIFY
# --------------------------------
Write-Host "[VERIFY] npm run lint..."
RunNative $repo $npmExe @("run","lint")

if (-not $SkipBuild) {
  Write-Host "[VERIFY] npm run build..."
  RunNative $repo $npmExe @("run","build")
} else {
  Write-Host "[VERIFY] build pulado (-SkipBuild)."
}

Write-Host ""
Write-Host "[OK] Engine-6A aplicado."