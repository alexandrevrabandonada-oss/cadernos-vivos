param(
  [Parameter(Mandatory=$true)][string]$Slug,
  [int]$Aula = 1,
  [string]$Titulo = "",
  [switch]$Force,
  [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function TestP([string]$p){ Test-Path -LiteralPath $p }

function ResolveRepoHere() {
  $here = (Get-Location).Path
  if (TestP (Join-Path $here "package.json")) { return $here }
  throw ("[STOP] Rode na raiz do repo (package.json). Atual: " + $here)
}

$repo = ResolveRepoHere
$boot = Join-Path $repo "tools\_bootstrap.ps1"

# ---- bootstrap (preferencial)
if (TestP $boot) {
  . $boot
}

# ---- fallbacks (caso bootstrap não tenha algo)
if (-not (Get-Command WL -ErrorAction SilentlyContinue)) {
  function WL([string]$s){ Write-Host $s }
}
if (-not (Get-Command EnsureDir -ErrorAction SilentlyContinue)) {
  function EnsureDir([string]$p){ if (-not (TestP $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
}
if (-not (Get-Command WriteUtf8NoBom -ErrorAction SilentlyContinue)) {
  function WriteUtf8NoBom([string]$p,[string]$content){
    $parent = Split-Path -Parent $p
    if ($parent) { EnsureDir $parent }
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($p, $content, $enc)
  }
}
if (-not (Get-Command BackupFile -ErrorAction SilentlyContinue)) {
  function BackupFile([string]$p){
    if (TestP $p) {
      $ts = (Get-Date -Format "yyyyMMdd_HHmmss")
      $bakDir = Join-Path (Get-Location) "tools\_patch_backup"
      EnsureDir $bakDir
      $leaf = Split-Path -Leaf $p
      Copy-Item -LiteralPath $p -Destination (Join-Path $bakDir ($leaf + "." + $ts + ".bak")) -Force
    }
  }
}
if (-not (Get-Command ResolveExe -ErrorAction SilentlyContinue)) {
  function ResolveExe([string]$name){
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { return $cmd.Source }
    return $name
  }
}
if (-not (Get-Command RunNative -ErrorAction SilentlyContinue)) {
  function RunNative([string]$cwd,[string]$exe,[string[]]$args){
    WL ("[RUN] " + $exe + " " + ($args -join " "))
    Push-Location $cwd
    & $exe @args
    $code = $LASTEXITCODE
    Pop-Location
    if ($code -ne 0) { throw ("[STOP] comando falhou (exit " + $code + ")") }
  }
}
if (-not (Get-Command NewReport -ErrorAction SilentlyContinue)) {
  function NewReport([string]$name,[string]$content){
    $repDir = Join-Path $repo "reports"
    EnsureDir $repDir
    $p = Join-Path $repDir $name
    WriteUtf8NoBom $p $content
    return $p
  }
}

$npmExe = ResolveExe "npm.cmd"

$contentRoot = Join-Path $repo "content\cadernos"
$cadernoDir  = Join-Path $contentRoot $Slug
$aulasDir    = Join-Path $cadernoDir "aulas"
$aulaFile    = Join-Path $aulasDir ($Aula.ToString() + ".md")

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] Caderno: " + $cadernoDir)
WL ("[DIAG] Aula file: " + $aulaFile)

if (-not (TestP $cadernoDir)) { throw ("[STOP] Não achei caderno: " + $cadernoDir) }
EnsureDir $aulasDir

if ((TestP $aulaFile) -and (-not $Force)) {
  throw ("[STOP] Aula já existe: " + $aulaFile + " — use -Force pra reescrever.")
}

if (-not $Titulo) { $Titulo = ("Aula " + $Aula.ToString() + " — Abertura") }

$mdLines = @()
$mdLines += ("# " + $Titulo)
$mdLines += ""
$mdLines += "> Este caderno é um **universo**: cada página é um ponto de vista."
$mdLines += "> #ÉLUTA — Escutar • Cuidar • Organizar"
$mdLines += ""
$mdLines += "## Objetivo da aula"
$mdLines += "- Definir o tema e o porquê (sem moralismo: diagnóstico estrutural)."
$mdLines += "- Criar um mapa mental mínimo: **causa → efeito → quem sofre → o que fazer**."
$mdLines += ""
$mdLines += "## Leitura guiada"
$mdLines += "Escreva aqui o texto principal. Dica: parágrafos curtos, com respiro."
$mdLines += ""
$mdLines += "### 1) O que está acontecendo?"
$mdLines += "- …"
$mdLines += ""
$mdLines += "### 2) Por que isso acontece (estrutura)?"
$mdLines += "- …"
$mdLines += ""
$mdLines += "### 3) Quem paga a conta (corpo, tempo, dinheiro, saúde)?"
$mdLines += "- …"
$mdLines += ""
$mdLines += "### 4) O que muda a lógica (poder popular / comum)?"
$mdLines += "- …"
$mdLines += ""
$mdLines += "## Perguntas (pra debate)"
$mdLines += "1. O que aqui é sintoma e o que é causa?"
$mdLines += "2. Qual é o ponto de alavanca mais simples pra começar?"
$mdLines += "3. O que a comunidade consegue fazer amanhã, sem pedir permissão?"
$mdLines += ""
$mdLines += "## Prática (15–30 min)"
$mdLines += "- Faça uma lista de 3 evidências do território (fatos observáveis)."
$mdLines += "- Escreva 1 proposta concreta (curta) e 1 convite (convocação)."
$mdLines += ""
$mdLines += "## Checklist"
$mdLines += "- [ ] Texto com parágrafos curtos"
$mdLines += "- [ ] Uma evidência concreta"
$mdLines += "- [ ] Uma proposta concreta"
$mdLines += "- [ ] Um chamado (convocação)"
$mdLines += ""
$mdLines += "## Notas do caderno"
$mdLines += "- (anotações livres)"

WriteUtf8NoBom $aulaFile ($mdLines -join "`n")
WL ("[OK] wrote: " + $aulaFile)

$repLines = @()
$repLines += ("# CV Engine-6B — Seed Aula v0.21b — " + (Get-Date -Format "yyyy-MM-dd HH:mm"))
$repLines += ""
$repLines += "## O que mudou"
$repLines += ("- Criou/atualizou aula: content/cadernos/" + $Slug + "/aulas/" + $Aula.ToString() + ".md")
$repLines += ""
$repLines += "## Teste rápido"
$repLines += ("- Abrir: /c/" + $Slug + "/a/" + $Aula.ToString())
$repLines += ""

$repPath = NewReport "cv-engine-6b-seed-aula-v0_21b.md" ($repLines -join "`n")
WL ("[OK] Report: " + $repPath)

WL "[VERIFY] npm run lint..."
RunNative $repo $npmExe @("run","lint")

if (-not $SkipBuild) {
  WL "[VERIFY] npm run build..."
  RunNative $repo $npmExe @("run","build")
} else {
  WL "[VERIFY] build pulado (-SkipBuild)."
}

WL ""
WL "[OK] Engine-6B aplicado."