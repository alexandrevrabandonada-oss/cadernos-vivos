param(
  [Parameter(Mandatory=$true)][string]$Slug,
  [string]$Title = "",
  [string]$Subtitle = "",
  [string]$Accent = "",
  [string]$Ethos = "",
  [string]$TemplateSlug = "poluicao-vr",
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

function BackupDir([string]$dir) {
  if (TestP $dir) {
    $ts = (Get-Date -Format "yyyyMMdd_HHmmss")
    $bakRoot = Join-Path (Get-Location) "tools\_patch_backup"
    EnsureDir $bakRoot
    $leaf = Split-Path -Leaf $dir
    $dest = Join-Path $bakRoot ($leaf + "." + $ts)
    Copy-Item -Recurse -Force -LiteralPath $dir -Destination $dest
    WL ("[OK] backup dir => " + $dest)
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

function NormalizeSlug([string]$s) {
  $x = $s.Trim().ToLowerInvariant()
  $x = $x.Replace(" ", "-").Replace("_","-")
  $chars = $x.ToCharArray()
  $out = New-Object System.Text.StringBuilder
  foreach ($ch in $chars) {
    if (($ch -ge 'a' -and $ch -le 'z') -or ($ch -ge '0' -and $ch -le '9') -or $ch -eq '-') {
      [void]$out.Append($ch)
    }
  }
  $y = $out.ToString()
  while ($y.Contains("--")) { $y = $y.Replace("--","-") }
  $y = $y.Trim('-')
  if ([string]::IsNullOrWhiteSpace($y)) { throw "[STOP] slug inválido (vazio após normalização)." }
  return $y
}

function DefaultTitleFromSlug([string]$s) {
  $t = $s.Replace("-"," ")
  return ($t.Substring(0,1).ToUpper() + $t.Substring(1))
}

# -------------------------
# DIAG
# -------------------------
$repo = ResolveRepoHere
$npmExe = ResolveExe "npm.cmd"

$slug0 = $Slug
$slug = NormalizeSlug $Slug
if ($slug -ne $slug0) { WL ("[WARN] slug normalizado: " + $slug0 + " => " + $slug) }

$contentRoot = Join-Path $repo "content\cadernos"
EnsureDir $contentRoot

$destDir = Join-Path $contentRoot $slug
$templateDir = Join-Path $contentRoot $TemplateSlug

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] ContentRoot: " + $contentRoot)
WL ("[DIAG] NewSlug: " + $slug)
WL ("[DIAG] Dest: " + $destDir)
WL ("[DIAG] TemplateSlug: " + $TemplateSlug)
WL ("[DIAG] TemplateDir: " + $templateDir)

if (TestP $destDir) {
  throw ("[STOP] Já existe content/cadernos/" + $slug + " (não vou sobrescrever).")
}

# -------------------------
# PATCH (criar caderno)
# -------------------------
if (TestP $templateDir) {
  WL "[STEP] Copiando template..."
  Copy-Item -Recurse -Force -LiteralPath $templateDir -Destination $destDir
} else {
  WL "[STEP] Template não encontrado; criando estrutura mínima..."
  EnsureDir $destDir
  EnsureDir (Join-Path $destDir "aulas")
  EnsureDir (Join-Path $destDir "acervo")
}

# garantir subpastas
EnsureDir (Join-Path $destDir "aulas")
EnsureDir (Join-Path $destDir "acervo")

# escrever/ajustar caderno.json
$metaPath = Join-Path $destDir "caderno.json"
$titleFinal = $Title
if ([string]::IsNullOrWhiteSpace($titleFinal)) { $titleFinal = DefaultTitleFromSlug $slug }

$meta = [ordered]@{
  title    = $titleFinal
  subtitle = $Subtitle
  accent   = $Accent
  ethos    = $Ethos
}
# limpar vazios
$clean = [ordered]@{}
foreach ($k in $meta.Keys) {
  $v = $meta[$k]
  if (-not [string]::IsNullOrWhiteSpace([string]$v)) { $clean[$k] = $v }
}
$json = ($clean | ConvertTo-Json -Depth 10)
WriteUtf8NoBom $metaPath $json
WL ("[OK] wrote: " + $metaPath)

# seeds (se não existirem)
function EnsureFile([string]$p, [string]$content) {
  if (-not (TestP $p)) {
    WriteUtf8NoBom $p $content
    WL ("[OK] seed: " + $p)
  } else {
    WL ("[OK] exists: " + $p)
  }
}

$panoramaPath = Join-Path $destDir "panorama.md"
$refsPath     = Join-Path $destDir "referencias.md"
$trilhaPath   = Join-Path $destDir "trilha.md"
$debatePath   = Join-Path $destDir "debate.json"
$mapaPath     = Join-Path $destDir "mapa.json"
$acervoJson   = Join-Path $destDir "acervo.json"
$registroJson = Join-Path $destDir "registro.json"

EnsureFile $panoramaPath @"
# Panorama — $titleFinal

Este caderno é um **caderno vivo**: leitura + prática + debate + registro.
Ele nasce do território e termina em ação concreta (pedido + ajuda mútua).

## Pergunta-guia
- O que está acontecendo de verdade (estrutura), e o que a comunidade pode fazer agora?

## Linha do tempo rápida
- (adicione fatos com data e fonte)

## Próximo passo
- Definir 1 ponto do território para mapear e 1 tarefa prática (2–10 min).
"@

EnsureFile $refsPath @"
# Referências — $titleFinal

Cole aqui links, PDFs e fontes (com resumo curto).
Organize por tema.

## Leituras base
- (link) — por que importa

## Dados e documentos
- (link) — o que prova

## Notícias e relatos
- (link) — o que aconteceu
"@

EnsureFile $trilhaPath @"
# Trilha de leitura — $titleFinal

Ordem sugerida para quem está chegando:

1) Panorama
2) Referências base (2 a 5 itens)
3) Aula 1 (conceitos)
4) Prática (flashcards)
5) Quiz (checagem)
6) Debate (síntese)
7) Registro (ação no mundo)
"@

# JSON seeds simples (sem inventar schema complexo)
EnsureFile $debatePath @"
{
  "prompts": [
    { "id": "D1", "title": "O que é estrutural aqui?", "prompt": "Descreva sem moralismo: quais mecanismos e interesses produzem o problema?" },
    { "id": "D2", "title": "Quem paga o preço?", "prompt": "Quais grupos sofrem mais e por quê? Cite evidências quando possível." },
    { "id": "D3", "title": "Qual pedido concreto?", "prompt": "Escreva um pedido específico, verificável, com prazo." }
  ]
}
"@

EnsureFile $mapaPath @"
{
  "points": [
    { "id": "P1", "title": "Ponto inicial (exemplo)", "lat": -22.52, "lng": -44.10, "kind": "marco", "notes": "Edite com coordenadas reais." }
  ]
}
"@

EnsureFile $acervoJson @"
[
  { "file": "(sem import ainda)", "title": "Coloque PDFs/DOCs em content/cadernos/$slug/acervo ou no public se você estiver usando essa estratégia", "kind": "info", "tags": ["setup"] }
]
"@

EnsureFile $registroJson @"
{
  "items": [
    { "id": "R1", "title": "Registro do território", "prompt": "Descreva uma ação concreta realizada (pequena e verificável), com data e evidência leve." }
  ]
}
"@

# aulas seed: garantir pelo menos 1 aula
$a1 = Join-Path $destDir "aulas\1.md"
EnsureFile $a1 @"
# Aula 1 — Fundamentos

## Ideia central
- Explicar em linguagem simples o básico do tema.

## Conceitos-chave
- Conceito 1
- Conceito 2

## Exercício rápido
- Resuma em 3 frases (sem moralismo; com causa e consequência).
"@

# -------------------------
# REPORT
# -------------------------
$repDir = Join-Path $repo "reports"
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repDir ("cv-10-create-caderno-" + $slug + "-v0_10.md")

$report = @(
  ("# CV-10 — Criar caderno por script — " + $now),
  "",
  ("## Novo caderno: " + $slug),
  ("- title: " + $titleFinal),
  ("- subtitle: " + $Subtitle),
  ("- accent: " + $Accent),
  "",
  "## O que foi criado",
  ("- content/cadernos/" + $slug + "/caderno.json"),
  ("- content/cadernos/" + $slug + "/panorama.md"),
  ("- content/cadernos/" + $slug + "/referencias.md"),
  ("- content/cadernos/" + $slug + "/trilha.md"),
  ("- content/cadernos/" + $slug + "/debate.json"),
  ("- content/cadernos/" + $slug + "/mapa.json"),
  ("- content/cadernos/" + $slug + "/registro.json"),
  ("- content/cadernos/" + $slug + "/acervo.json"),
  ("- content/cadernos/" + $slug + "/aulas/1.md"),
  "",
  "## Como ver",
  ("- /c/" + $slug),
  "- O índice (/ e /c) deve listar automaticamente"
) -join "`n"
WriteUtf8NoBom $reportPath $report
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
WL ("[OK] CV-10 pronto. Novo caderno: /c/" + $slug)