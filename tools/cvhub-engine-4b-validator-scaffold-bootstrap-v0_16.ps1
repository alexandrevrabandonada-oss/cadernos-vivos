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

$toolsDir   = Join-Path $repo "tools"
$repDir     = Join-Path $repo "reports"
$contentDir = Join-Path $repo "content\cadernos"

$bootstrapPath = Join-Path $toolsDir "_bootstrap.ps1"
$validatePath  = Join-Path $toolsDir "cv-validate-content.ps1"
$newPath       = Join-Path $toolsDir "cv-new-caderno.ps1"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] content: " + $contentDir)
WL ("[DIAG] tools: " + $toolsDir)

if (-not (TestP $toolsDir)) { EnsureDir $toolsDir }
if (-not (TestP $repDir)) { EnsureDir $repDir }
if (-not (TestP $contentDir)) { throw ("[STOP] Não achei content\cadernos em: " + $contentDir) }

# -------------------------
# WRITE: tools/_bootstrap.ps1
# -------------------------
BackupFile $bootstrapPath

$bootstrapLines = @(
'Set-StrictMode -Version Latest',
'$ErrorActionPreference = "Stop"',
'',
'function WL([string]$s) { Write-Host $s }',
'function TestP([string]$p) { return (Test-Path -LiteralPath $p) }',
'',
'function EnsureDir([string]$p) {',
'  if (-not (TestP $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }',
'}',
'',
'function WriteUtf8NoBom([string]$p, [string]$content) {',
'  $parent = Split-Path -Parent $p',
'  if ($parent) { EnsureDir $parent }',
'  $enc = New-Object System.Text.UTF8Encoding($false)',
'  [System.IO.File]::WriteAllText($p, $content, $enc)',
'}',
'',
'function BackupFile([string]$p) {',
'  if (TestP $p) {',
'    $ts = (Get-Date -Format "yyyyMMdd_HHmmss")',
'    $bakDir = Join-Path (Get-Location) "tools\_patch_backup"',
'    EnsureDir $bakDir',
'    $leaf = Split-Path -Leaf $p',
'    Copy-Item -LiteralPath $p -Destination (Join-Path $bakDir ($leaf + "." + $ts + ".bak")) -Force',
'  }',
'}',
'',
'function ResolveExe([string]$name) {',
'  $cmd = Get-Command $name -ErrorAction SilentlyContinue',
'  if ($cmd -and $cmd.Source) { return $cmd.Source }',
'  return $name',
'}',
'',
'function RunNative([string]$cwd, [string]$exe, [string[]]$cmdArgs) {',
'  $pretty = ($cmdArgs -join " ")',
'  WL ("[RUN] " + $exe + " " + $pretty)',
'  Push-Location $cwd',
'  & $exe @cmdArgs',
'  $code = $LASTEXITCODE',
'  Pop-Location',
'  if ($code -ne 0) { throw ("[STOP] comando falhou (exit " + $code + "): " + $exe + " " + $pretty) }',
'}',
'',
'function ResolveRepoHere() {',
'  $here = (Get-Location).Path',
'  if (TestP (Join-Path $here "package.json")) { return $here }',
'  throw ("[STOP] Rode na raiz do repo (onde tem package.json). Atual: " + $here)',
'}',
'',
'function ReadJson([string]$p) {',
'  $raw = Get-Content -LiteralPath $p -Raw -ErrorAction Stop',
'  return ($raw | ConvertFrom-Json -ErrorAction Stop)',
'}',
'',
'function WriteJson([string]$p, $obj) {',
'  $out = $obj | ConvertTo-Json -Depth 64',
'  WriteUtf8NoBom $p ($out + "`n")',
'}'
)

WriteUtf8NoBom $bootstrapPath (($bootstrapLines -join "`n") + "`n")
WL ("[OK] wrote: " + $bootstrapPath)

# -------------------------
# WRITE: tools/cv-validate-content.ps1
# -------------------------
BackupFile $validatePath

$validateLines = @(
'param(',
'  [switch]$Strict,',
'  [switch]$Fix',
')',
'',
'. "$PSScriptRoot\_bootstrap.ps1"',
'',
'$repo = ResolveRepoHere',
'$contentDir = Join-Path $repo "content\cadernos"',
'',
'WL ("[DIAG] repo: " + $repo)',
'WL ("[DIAG] content: " + $contentDir)',
'',
'if (-not (TestP $contentDir)) { throw ("[STOP] Não achei content\cadernos em: " + $contentDir) }',
'',
'function HasProp($obj, [string]$name) {',
'  if ($null -eq $obj) { return $false }',
'  $p = $obj.PSObject.Properties[$name]',
'  return ($null -ne $p)',
'}',
'',
'function DefaultMoodFromSlug([string]$slug) {',
'  $s = $slug.ToLowerInvariant()',
'  if ($s.Contains("poluicao")) { return "smoke" }',
'  if ($s.Contains("trabalho")) { return "steel" }',
'  if ($s.Contains("memoria")) { return "archive" }',
'  if ($s.Contains("eco")) { return "green" }',
'  return "urban"',
'}',
'',
'$metaFiles = Get-ChildItem -LiteralPath $contentDir -Recurse -Filter "meta.json" -File -ErrorAction SilentlyContinue',
'$count = 0',
'if ($metaFiles) { $count = @($metaFiles).Count }',
'WL ("[DIAG] meta.json: " + $count)',
'',
'$errors = New-Object System.Collections.Generic.List[string]',
'$warns  = New-Object System.Collections.Generic.List[string]',
'$fixed  = 0',
'',
'foreach ($mf in @($metaFiles)) {',
'  $dir = Split-Path -Parent $mf.FullName',
'  $slug = Split-Path -Leaf $dir',
'',
'  $obj = $null',
'  try { $obj = ReadJson $mf.FullName } catch {',
'    $errors.Add(("meta.json inválido: " + $mf.FullName))',
'    continue',
'  }',
'',
'  $did = $false',
'',
'  foreach ($k in @("title","subtitle","ethos","mood","accent")) {',
'    $ok = $false',
'    if (HasProp $obj $k) {',
'      $v = [string]$obj.$k',
'      if (-not [string]::IsNullOrWhiteSpace($v)) { $ok = $true }',
'    }',
'    if (-not $ok) {',
'      if ($Fix) {',
'        if ($k -eq "mood") { $obj | Add-Member -NotePropertyName "mood" -NotePropertyValue (DefaultMoodFromSlug $slug) -Force; $did = $true }',
'        elseif ($k -eq "accent") { $obj | Add-Member -NotePropertyName "accent" -NotePropertyValue "#fbbf24" -Force; $did = $true }',
'        else { $warns.Add(("faltando " + $k + " (não auto-preenchi): " + $mf.FullName)) }',
'      } else {',
'        $errors.Add(("faltando " + $k + ": " + $mf.FullName))',
'      }',
'    }',
'  }',
'',
'  # checa estrutura mínima (não é fatal por padrão)',
'  $mapa = Join-Path $dir "mapa.json"',
'  $deb  = Join-Path $dir "debate.json"',
'  $acv  = Join-Path $dir "acervo.json"',
'  $pr   = Join-Path $dir "pratica.md"',
'  $qz   = Join-Path $dir "quiz.json"',
'  $tr   = Join-Path $dir "trilha.json"',
'  $rg   = Join-Path $dir "registro.json"',
'  $aDir = Join-Path $dir "aulas"',
'',
'  if (-not (TestP $aDir)) { $warns.Add(("sem pasta aulas/: " + $slug)) }',
'  else {',
'    $aulas = Get-ChildItem -LiteralPath $aDir -File -ErrorAction SilentlyContinue',
'    $aCount = 0',
'    if ($aulas) { $aCount = @($aulas).Count }',
'    if ($aCount -le 0) { $warns.Add(("pasta aulas vazia: " + $slug)) }',
'  }',
'',
'  foreach ($opt in @($mapa,$deb,$acv,$pr,$qz,$tr,$rg)) {',
'    if (-not (TestP $opt)) { $warns.Add(("arquivo opcional faltando: " + (Split-Path -Leaf $opt) + " (" + $slug + ")")) }',
'  }',
'',
'  if ($did) {',
'    WriteJson $mf.FullName $obj',
'    $fixed++',
'    WL ("[OK] fix meta: " + $slug)',
'  }',
'}',
'',
'WL ("[DONE] fixed meta.json: " + $fixed)',
'WL ("[DONE] warnings: " + $warns.Count)',
'WL ("[DONE] errors: " + $errors.Count)',
'',
'if ($warns.Count -gt 0) {',
'  WL ""',
'  WL "WARNINGS:"',
'  foreach ($w in $warns) { WL ("- " + $w) }',
'}',
'',
'if ($errors.Count -gt 0) {',
'  WL ""',
'  WL "ERRORS:"',
'  foreach ($e in $errors) { WL ("- " + $e) }',
'  if ($Strict) { throw "[STOP] validação falhou (Strict)." }',
'}',
'',
'WL "[OK] validação concluída."'
)

WriteUtf8NoBom $validatePath (($validateLines -join "`n") + "`n")
WL ("[OK] wrote: " + $validatePath)

# -------------------------
# WRITE: tools/cv-new-caderno.ps1
# -------------------------
BackupFile $newPath

$newLines = @(
'param(',
'  [Parameter(Mandatory=$true)][string]$Slug,',
'  [Parameter(Mandatory=$true)][string]$Title,',
'  [string]$Subtitle = "Caderno vivo",',
'  [string]$Ethos = "Escutar, cuidar, organizar",',
'  [string]$Mood = "",',
'  [string]$Accent = "#fbbf24",',
'  [switch]$Force',
')',
'',
'. "$PSScriptRoot\_bootstrap.ps1"',
'',
'$repo = ResolveRepoHere',
'$root = Join-Path $repo "content\cadernos"',
'$dir  = Join-Path $root $Slug',
'',
'function DefaultMoodFromSlug([string]$slug) {',
'  $s = $slug.ToLowerInvariant()',
'  if ($s.Contains("poluicao")) { return "smoke" }',
'  if ($s.Contains("trabalho")) { return "steel" }',
'  if ($s.Contains("memoria")) { return "archive" }',
'  if ($s.Contains("eco")) { return "green" }',
'  return "urban"',
'}',
'',
'if ((TestP $dir) -and (-not $Force)) { throw ("[STOP] Já existe: " + $dir + " (use -Force se quiser sobrescrever arquivos placeholder)") }',
'EnsureDir $dir',
'EnsureDir (Join-Path $dir "aulas")',
'',
'if ([string]::IsNullOrWhiteSpace($Mood)) { $Mood = DefaultMoodFromSlug $Slug }',
'',
'$metaPath = Join-Path $dir "meta.json"',
'$meta = [ordered]@{',
'  title    = $Title',
'  subtitle = $Subtitle',
'  ethos    = $Ethos',
'  mood     = $Mood',
'  accent   = $Accent',
'  version  = "1.0.0"',
'  createdAt= (Get-Date).ToString("yyyy-MM-dd")',
'}',
'WriteJson $metaPath $meta',
'WL ("[OK] meta.json: " + $metaPath)',
'',
'# placeholders (seguros: se o motor não usar algum, não quebra)',
'WriteUtf8NoBom (Join-Path $dir "mapa.json")     "{`n  `"points`": []`n}`n"',
'WriteUtf8NoBom (Join-Path $dir "debate.json")   "{`n  `"prompts`": [{`n    `"id`": `"p1`",`n    `"title`": `"Pergunta de debate`",`n    `"hint`": `"Escreva sua síntese e um pedido concreto.`"`n  }]`n}`n"',
'WriteUtf8NoBom (Join-Path $dir "acervo.json")   "{`n  `"items`": []`n}`n"',
'WriteUtf8NoBom (Join-Path $dir "quiz.json")     "{`n  `"questions`": []`n}`n"',
'WriteUtf8NoBom (Join-Path $dir "trilha.json")   "{`n  `"steps`": []`n}`n"',
'WriteUtf8NoBom (Join-Path $dir "registro.json") "{`n  `"fields`": []`n}`n"',
'WriteUtf8NoBom (Join-Path $dir "pratica.md")    ("# Prática`n`n- Descreva uma ação pequena, concreta e replicável.`n- Qual evidência você pode registrar?`n")',
'WriteUtf8NoBom (Join-Path $dir "aulas\1.md")    ("# Aula 1 — Começo`n`nEste é um placeholder. Edite o conteúdo em content/cadernos/" + $Slug + "/aulas/1.md`n")',
'',
'WL ("[OK] Caderno criado em: " + $dir)',
'WL "Dica: rode a validação: pwsh -NoProfile -ExecutionPolicy Bypass -File tools\cv-validate-content.ps1 -Fix"'
)

WriteUtf8NoBom $newPath (($newLines -join "`n") + "`n")
WL ("[OK] wrote: " + $newPath)

# -------------------------
# RUN VALIDATOR (Fix leve)
# -------------------------
WL "[VERIFY] content validation (-Fix)..."
RunNative $repo (ResolveExe "pwsh.exe") @("-NoProfile","-ExecutionPolicy","Bypass","-File",$validatePath,"-Fix")

# -------------------------
# REPORT
# -------------------------
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repDir "cv-engine-4b-validator-scaffold-bootstrap-v0_16.md"

$report = @(
("# CV Engine-4B — Validator + Scaffold + Bootstrap — " + $now),
"",
"## O que foi criado",
"- tools/_bootstrap.ps1 (funções padrão)",
"- tools/cv-validate-content.ps1 (valida content/cadernos)",
"- tools/cv-new-caderno.ps1 (cria um caderno novo completo)",
"",
"## Como usar (exemplo)",
"pwsh -NoProfile -ExecutionPolicy Bypass -File tools/cv-new-caderno.ps1 -Slug exemplo -Title ""Exemplo de Caderno""",
"pwsh -NoProfile -ExecutionPolicy Bypass -File tools/cv-validate-content.ps1 -Fix",
"",
"## Próximo",
"- Engine-4C: gerador de checklist por caderno (o que falta preencher) + painel /c/[slug]/status"
) -join "`n"

WriteUtf8NoBom $reportPath ($report + "`n")
WL ("[OK] Report: " + $reportPath)

# -------------------------
# VERIFY (lint/build)
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
WL "[OK] Engine-4B aplicado."