param(
  [string]$Slug = "",
  [string]$Title = "",
  [string]$Subtitle = "",
  [string]$Accent = "#facc15",
  [switch]$Force,
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

function Slugify([string]$s) {
  if ($null -eq $s) { return "" }
  $t = $s.Trim().ToLower()
  $chars = $t.ToCharArray()
  $out = New-Object System.Collections.Generic.List[char]
  $dash = $false
  foreach ($c in $chars) {
    $isAz = ($c -ge [char]'a' -and $c -le [char]'z')
    $is09 = ($c -ge [char]'0' -and $c -le [char]'9')
    if ($isAz -or $is09) {
      $out.Add($c) | Out-Null
      $dash = $false
    } else {
      if (-not $dash) {
        $out.Add([char]'-') | Out-Null
        $dash = $true
      }
    }
  }
  $res = (-join $out).Trim('-')
  while ($res.Contains("--")) { $res = $res.Replace("--","-") }
  return $res
}

# -------------------------
# DIAG
# -------------------------
$repo = ResolveRepoHere
$npmExe = ResolveExe "npm.cmd"

$contentRoot = Join-Path $repo "content\cadernos"
$publicRoot  = Join-Path $repo "public\cadernos"
$reportsDir  = Join-Path $repo "reports"
EnsureDir $contentRoot
EnsureDir $publicRoot
EnsureDir $reportsDir

if ([string]::IsNullOrWhiteSpace($Slug)) {
  $Slug = "caderno-" + (Get-Date -Format "yyyyMMdd")
}
$slug2 = Slugify $Slug
if ([string]::IsNullOrWhiteSpace($slug2)) { throw "[STOP] slug inválido." }
$Slug = $slug2

if ([string]::IsNullOrWhiteSpace($Title)) {
  $Title = "Caderno " + $Slug
}
if ([string]::IsNullOrWhiteSpace($Subtitle)) {
  $Subtitle = "Panorama • Aulas • Prática • Quiz • Debate • Mapa • Registro"
}

$cDir = Join-Path $contentRoot $Slug
$pDir = Join-Path $publicRoot  $Slug
$acervoPublic = Join-Path $pDir "acervo"
$aulasDir = Join-Path $cDir "aulas"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] Slug: " + $Slug)
WL ("[DIAG] Title: " + $Title)

if ((TestP $cDir) -and (-not $Force)) { throw ("[STOP] Já existe: " + $cDir + " (use -Force se quiser sobrescrever seeds).") }
if (-not (TestP $cDir)) { EnsureDir $cDir }
EnsureDir $aulasDir
EnsureDir $acervoPublic

# -------------------------
# PATCH (SEEDS)
# -------------------------
# caderno.json
$meta = [ordered]@{
  slug     = $Slug
  title    = $Title
  subtitle = $Subtitle
  accent   = $Accent
  ethos    = "comum • autogestão • ajuda mútua"
}
$metaPath = Join-Path $cDir "caderno.json"
WriteUtf8NoBom $metaPath (($meta | ConvertTo-Json -Depth 5))

# panorama.md
$panPath = Join-Path $cDir "panorama.md"
$pan = @(
  "# Panorama — " + $Title,
  "",
  "## O que está acontecendo",
  "- (Escreva em linguagem concreta, sem moralismo.)",
  "",
  "## Quem é afetado",
  "- (Quais bairros / trabalhadores / escolas / serviços.)",
  "",
  "## Provas e indícios",
  "- (Links, documentos, fotos, relatos.)",
  "",
  "## Pedido concreto",
  "- (O que precisa acontecer, com prazo e responsável.)",
  "",
  "## Ação simples de ajuda mútua (2–10 min)",
  "- (O que a base pode fazer agora.)"
) -join "`n"
WriteUtf8NoBom $panPath $pan

# referencias.md
$refPath = Join-Path $cDir "referencias.md"
$refs = @(
  "# Referências — " + $Title,
  "",
  "## Leitura rápida (comece aqui)",
  "- (1) ...",
  "- (2) ...",
  "",
  "## Documentos / processos / relatórios",
  "- ...",
  "",
  "## Matérias / imprensa",
  "- ...",
  "",
  "## Acadêmico / técnico",
  "- ..."
) -join "`n"
WriteUtf8NoBom $refPath $refs

# trilha.md
$triPath = Join-Path $cDir "trilha.md"
$trilha = @(
  "# Trilha de leitura — " + $Title,
  "",
  "## Etapa 1 — Entender o problema (15–30 min)",
  "- Leia o Panorama",
  "- Veja 2 documentos do Acervo",
  "",
  "## Etapa 2 — Organizar provas (30–60 min)",
  "- Liste 5 fatos verificáveis",
  "- Separe por tema (saúde, trabalho, território, orçamento...)",
  "",
  "## Etapa 3 — Saída prática",
  "- Defina pedido concreto",
  "- Faça 1 registro (ata) de ação coletiva"
) -join "`n"
WriteUtf8NoBom $triPath $trilha

# debate.json
$debPath = Join-Path $cDir "debate.json"
$debObj = [ordered]@{
  prompts = @(
    @{ id="d1"; title="Diagnóstico estrutural"; prompt="O que na estrutura produz isso? (evitar moralismo e personagens mágicos)" },
    @{ id="d2"; title="Quem lucra / quem paga"; prompt="Quem ganha e quem paga a conta? (tempo, saúde, dinheiro, território)" },
    @{ id="d3"; title="Pedido concreto"; prompt="Qual pedido verificável, com prazo e responsável?" }
  )
}
WriteUtf8NoBom $debPath (($debObj | ConvertTo-Json -Depth 10))

# mapa.json (placeholder)
$mapPath = Join-Path $cDir "mapa.json"
$mapObj = [ordered]@{
  points = @(
    @{ id="p1"; title="Ponto 1 (edite)"; kind="referencia"; lat=-22.52; lng=-44.10; notes="Descreva o porquê do ponto." }
  )
}
WriteUtf8NoBom $mapPath (($mapObj | ConvertTo-Json -Depth 10))

# acervo.json (curadoria inicial vazia + dica)
$acervoJsonPath = Join-Path $cDir "acervo.json"
$acervoArr = @(
  @{ file="(coloque arquivos em public/cadernos/" + $Slug + "/acervo)"; title="Dica"; kind="info"; tags=@("setup") }
)
WriteUtf8NoBom $acervoJsonPath (($acervoArr | ConvertTo-Json -Depth 10))

# aulas seed (8 aulas vazias)
for ($n=1; $n -le 8; $n++) {
  $aPath = Join-Path $aulasDir ("aula-" + $n + ".md")
  if ((-not (TestP $aPath)) -or $Force) {
    $a = @(
      "# Aula " + $n,
      "",
      "## Ideia central",
      "- ...",
      "",
      "## 3 pontos",
      "1) ...",
      "2) ...",
      "3) ...",
      "",
      "## Prova / evidência",
      "- ...",
      "",
      "## Pergunta pra prática",
      "- ..."
    ) -join "`n"
    WriteUtf8NoBom $aPath $a
  }
}

WL ("[OK] Seeds criados em: " + $cDir)
WL ("[OK] Pasta de acervo (arquivos brutos): " + $acervoPublic)

# -------------------------
# REPORT
# -------------------------
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $reportsDir ("cv-5-scaffold-" + $Slug + ".md")
$rep = @(
  ("# CV-5 — Scaffold de Caderno — " + $now),
  "",
  ("## Slug: " + $Slug),
  ("## Title: " + $Title),
  "",
  "## Criado",
  "- content/cadernos/<slug>/caderno.json",
  "- panorama.md, referencias.md, trilha.md",
  "- debate.json, mapa.json, acervo.json",
  "- aulas/aula-1..8.md",
  "- public/cadernos/<slug>/acervo/ (pasta de arquivos brutos)",
  "",
  "## Próximo passo",
  "- Rode `npm run dev` e abra /c/<slug>",
  "- Depois: CV-6 (curadoria do acervo: tags, busca, trilha por tema)"
) -join "`n"
WriteUtf8NoBom $reportPath $rep
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
WL ("[OK] CV-5 pronto. Abra /c/" + $Slug)