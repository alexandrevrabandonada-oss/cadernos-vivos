param(
  [switch]$Strict,
  [switch]$Fix
)

. "$PSScriptRoot\_bootstrap.ps1"

$repo = ResolveRepoHere
$contentDir = Join-Path $repo "content\cadernos"

WL ("[DIAG] repo: " + $repo)
WL ("[DIAG] content: " + $contentDir)

if (-not (TestP $contentDir)) { throw ("[STOP] Não achei content\cadernos em: " + $contentDir) }

function HasProp($obj, [string]$name) {
  if ($null -eq $obj) { return $false }
  $p = $obj.PSObject.Properties[$name]
  return ($null -ne $p)
}

function DefaultMoodFromSlug([string]$slug) {
  $s = $slug.ToLowerInvariant()
  if ($s.Contains("poluicao")) { return "smoke" }
  if ($s.Contains("trabalho")) { return "steel" }
  if ($s.Contains("memoria")) { return "archive" }
  if ($s.Contains("eco")) { return "green" }
  return "urban"
}

$metaFiles = Get-ChildItem -LiteralPath $contentDir -Recurse -Filter "meta.json" -File -ErrorAction SilentlyContinue
$count = 0
if ($metaFiles) { $count = @($metaFiles).Count }
WL ("[DIAG] meta.json: " + $count)

$errors = New-Object System.Collections.Generic.List[string]
$warns  = New-Object System.Collections.Generic.List[string]
$fixed  = 0

foreach ($mf in @($metaFiles)) {
  $dir = Split-Path -Parent $mf.FullName
  $slug = Split-Path -Leaf $dir

  $obj = $null
  try { $obj = ReadJson $mf.FullName } catch {
    $errors.Add(("meta.json inválido: " + $mf.FullName))
    continue
  }

  $did = $false

  foreach ($k in @("title","subtitle","ethos","mood","accent")) {
    $ok = $false
    if (HasProp $obj $k) {
      $v = [string]$obj.$k
      if (-not [string]::IsNullOrWhiteSpace($v)) { $ok = $true }
    }
    if (-not $ok) {
      if ($Fix) {
        if ($k -eq "mood") { $obj | Add-Member -NotePropertyName "mood" -NotePropertyValue (DefaultMoodFromSlug $slug) -Force; $did = $true }
        elseif ($k -eq "accent") { $obj | Add-Member -NotePropertyName "accent" -NotePropertyValue "#fbbf24" -Force; $did = $true }
        else { $warns.Add(("faltando " + $k + " (não auto-preenchi): " + $mf.FullName)) }
      } else {
        $errors.Add(("faltando " + $k + ": " + $mf.FullName))
      }
    }
  }

  # checa estrutura mínima (não é fatal por padrão)
  $mapa = Join-Path $dir "mapa.json"
  $deb  = Join-Path $dir "debate.json"
  $acv  = Join-Path $dir "acervo.json"
  $pr   = Join-Path $dir "pratica.md"
  $qz   = Join-Path $dir "quiz.json"
  $tr   = Join-Path $dir "trilha.json"
  $rg   = Join-Path $dir "registro.json"
  $aDir = Join-Path $dir "aulas"

  if (-not (TestP $aDir)) { $warns.Add(("sem pasta aulas/: " + $slug)) }
  else {
    $aulas = Get-ChildItem -LiteralPath $aDir -File -ErrorAction SilentlyContinue
    $aCount = 0
    if ($aulas) { $aCount = @($aulas).Count }
    if ($aCount -le 0) { $warns.Add(("pasta aulas vazia: " + $slug)) }
  }

  foreach ($opt in @($mapa,$deb,$acv,$pr,$qz,$tr,$rg)) {
    if (-not (TestP $opt)) { $warns.Add(("arquivo opcional faltando: " + (Split-Path -Leaf $opt) + " (" + $slug + ")")) }
  }

  if ($did) {
    WriteJson $mf.FullName $obj
    $fixed++
    WL ("[OK] fix meta: " + $slug)
  }
}

WL ("[DONE] fixed meta.json: " + $fixed)
WL ("[DONE] warnings: " + $warns.Count)
WL ("[DONE] errors: " + $errors.Count)

if ($warns.Count -gt 0) {
  WL ""
  WL "WARNINGS:"
  foreach ($w in $warns) { WL ("- " + $w) }
}

if ($errors.Count -gt 0) {
  WL ""
  WL "ERRORS:"
  foreach ($e in $errors) { WL ("- " + $e) }
  if ($Strict) { throw "[STOP] validação falhou (Strict)." }
}

WL "[OK] validação concluída."
