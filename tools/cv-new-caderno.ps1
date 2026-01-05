param(
  [Parameter(Mandatory=$true)][string]$Slug,
  [Parameter(Mandatory=$true)][string]$Title,
  [string]$Subtitle = "Caderno vivo",
  [string]$Ethos = "Escutar, cuidar, organizar",
  [string]$Mood = "",
  [string]$Accent = "#fbbf24",
  [switch]$Force
)

. "$PSScriptRoot\_bootstrap.ps1"

$repo = ResolveRepoHere
$root = Join-Path $repo "content\cadernos"
$dir  = Join-Path $root $Slug

function DefaultMoodFromSlug([string]$slug) {
  $s = $slug.ToLowerInvariant()
  if ($s.Contains("poluicao")) { return "smoke" }
  if ($s.Contains("trabalho")) { return "steel" }
  if ($s.Contains("memoria")) { return "archive" }
  if ($s.Contains("eco")) { return "green" }
  return "urban"
}

if ((TestP $dir) -and (-not $Force)) { throw ("[STOP] Já existe: " + $dir + " (use -Force se quiser sobrescrever arquivos placeholder)") }
EnsureDir $dir
EnsureDir (Join-Path $dir "aulas")

if ([string]::IsNullOrWhiteSpace($Mood)) { $Mood = DefaultMoodFromSlug $Slug }

$metaPath = Join-Path $dir "meta.json"
$meta = [ordered]@{
  title    = $Title
  subtitle = $Subtitle
  ethos    = $Ethos
  mood     = $Mood
  accent   = $Accent
  version  = "1.0.0"
  createdAt= (Get-Date).ToString("yyyy-MM-dd")
}
WriteJson $metaPath $meta
WL ("[OK] meta.json: " + $metaPath)

# placeholders (seguros: se o motor não usar algum, não quebra)
WriteUtf8NoBom (Join-Path $dir "mapa.json")     "{`n  `"points`": []`n}`n"
WriteUtf8NoBom (Join-Path $dir "debate.json")   "{`n  `"prompts`": [{`n    `"id`": `"p1`",`n    `"title`": `"Pergunta de debate`",`n    `"hint`": `"Escreva sua síntese e um pedido concreto.`"`n  }]`n}`n"
WriteUtf8NoBom (Join-Path $dir "acervo.json")   "{`n  `"items`": []`n}`n"
WriteUtf8NoBom (Join-Path $dir "quiz.json")     "{`n  `"questions`": []`n}`n"
WriteUtf8NoBom (Join-Path $dir "trilha.json")   "{`n  `"steps`": []`n}`n"
WriteUtf8NoBom (Join-Path $dir "registro.json") "{`n  `"fields`": []`n}`n"
WriteUtf8NoBom (Join-Path $dir "pratica.md")    ("# Prática`n`n- Descreva uma ação pequena, concreta e replicável.`n- Qual evidência você pode registrar?`n")
WriteUtf8NoBom (Join-Path $dir "aulas\1.md")    ("# Aula 1 — Começo`n`nEste é um placeholder. Edite o conteúdo em content/cadernos/" + $Slug + "/aulas/1.md`n")

WL ("[OK] Caderno criado em: " + $dir)
WL "Dica: rode a validação: pwsh -NoProfile -ExecutionPolicy Bypass -File tools\cv-validate-content.ps1 -Fix"
