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

if (TestP $boot) {
  . $boot
} else {
  function WL([string]$s){ Write-Host $s }
  function EnsureDir([string]$p){ if (-not (TestP $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
  function WriteUtf8NoBom([string]$p,[string]$content){
    $parent = Split-Path -Parent $p
    if ($parent) { EnsureDir $parent }
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($p, $content, $enc)
  }
  function BackupFile([string]$p){
    if (TestP $p) {
      $ts = (Get-Date -Format "yyyyMMdd_HHmmss")
      $bakDir = Join-Path (Get-Location) "tools\_patch_backup"
      EnsureDir $bakDir
      $leaf = Split-Path -Leaf $p
      Copy-Item -LiteralPath $p -Destination (Join-Path $bakDir ($leaf + "." + $ts + ".bak")) -Force
    }
  }
  function ResolveExe([string]$name){
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { return $cmd.Source }
    return $name
  }
  function RunNative([string]$cwd,[string]$exe,[string[]]$args){
    WL ("[RUN] " + $exe + " " + ($args -join " "))
    Push-Location $cwd
    & $exe @args
    $code = $LASTEXITCODE
    Pop-Location
    if ($code -ne 0) { throw ("[STOP] comando falhou (exit " + $code + ")") }
  }
  function NewReport([string]$name,[string]$content){
    $repDir = Join-Path $repo "reports"
    EnsureDir $repDir
    $p = Join-Path $repDir $name
    WriteUtf8NoBom $p $content
    return $p
  }
  function WL([string]$s){ Write-Host $s }
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

$md = @(
  ("# " + $Titulo),
  "",
  "> Este caderno é um **universo**: cada página é um ponto de vista.",
  "> #ÉLUTA — Escutar • Cuidar • Organizar",
  "",
  "## Objetivo da aula",
  "- Definir o tema e o *porquê* (sem moralismo: diagnóstico estrutural).",
  "- Criar um mapa mental mínimo: **causa → efeito → quem sofre → o que fazer**.",
  "",
  "## Leitura guiada",
  "Escreva aqui o texto principal. Dica: parágrafos curtos, com respiro.",
  "",
  "### 1) O que está acontecendo?",
  "- …",
  "",
  "### 2) Por que isso acontece (estrutura)?",
  "- …",
  "",
  "### 3) Quem paga a conta (corpo, tempo, dinheiro, saúde)?",
  "- …",
  "",
  "### 4) O que muda a lógica (poder popular / comum)?",
  "- …",
  "",
  "## Perguntas (pra debate)",
  "1. O que aqui é sintoma e o que é causa?",
  "2. Qual é o ‘ponto de alavanca’ mais simples pra começar?",
  "3. O que a comunidade consegue fazer amanhã, sem pedir permissão?",
  "",
  "## Prática (15–30 min)",
  "- Faça uma lista de 3 evidências do território (fatos observáveis).",
  "- Escreva 1 proposta concreta (curta) e 1 convite (convocação).",
  "",
  "## Checklist",
  "- [ ] Texto com parágrafos curtos",
  "- [ ] Uma evidência concreta",
  "- [ ] Uma proposta concreta",
  "- [ ] Um chamado (convocação)",
  "",
  "## Notas do caderno",
  "- (anotações livres)"
) -join "`n"

WriteUtf8NoBom $aulaFile $md
WL ("[OK] wrote: " + $aulaFile)

$rep = @(
  ("# CV Engine-6B — Seed Aula v0.21 — " + (Get-Date -Format "yyyy-MM-dd HH:mm")),
  "",
  "## O que mudou",
  ("- Criou/atualizou aula: `"content/cadernos/" + $Slug + "/aulas/" + $Aula.ToString() + ".md`" ),
  "",
  "## Teste rápido",
  ("- Abrir: /c/" + $Slug + "/a/" + $Aula.ToString() ),
  ""
) -join "`n"

$repPath = NewReport "cv-engine-6b-seed-aula-v0_21.md" $rep
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