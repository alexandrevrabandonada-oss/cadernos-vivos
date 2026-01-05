param(
  [string]$Slug = "poluicao-vr",
  [string]$ZipPath = "",
  [switch]$SkipLint,
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

function NormalizeSlug([string]$s) {
  $t = ($s ?? "").Trim().ToLower()
  $t = $t -replace "[^a-z0-9\-]+", "-"
  $t = $t -replace "-{2,}", "-"
  $t = $t.Trim("-")
  if (-not $t) { return "caderno" }
  return $t
}

function TitleFromFile([string]$name) {
  $base = [System.IO.Path]::GetFileNameWithoutExtension($name)
  $base = $base -replace "[_\-]+", " "
  $base = $base -replace "\s{2,}", " "
  $base = $base.Trim()
  if (-not $base) { return $name }
  try {
    $ti = [System.Globalization.CultureInfo]::GetCultureInfo("pt-BR").TextInfo
    return $ti.ToTitleCase($base.ToLower())
  } catch {
    return $base
  }
}

function KindFromExt([string]$ext) {
  $e = ($ext ?? "").Trim().TrimStart(".").ToLower()
  if ($e -eq "pdf") { return "pdf" }
  if ($e -eq "doc" -or $e -eq "docx") { return "doc" }
  if ($e -eq "ppt" -or $e -eq "pptx") { return "slides" }
  if ($e -eq "xls" -or $e -eq "xlsx" -or $e -eq "csv") { return "planilha" }
  if ($e -eq "png" -or $e -eq "jpg" -or $e -eq "jpeg" -or $e -eq "webp") { return "imagem" }
  if ($e -eq "txt" -or $e -eq "md") { return "texto" }
  return "file"
}

function FindZipAuto([string]$repo) {
  $parent = Split-Path -Parent $repo
  $cands = @()
  $a = @(Get-ChildItem -LiteralPath $repo -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -ieq ".zip" })
  $cands += $a
  if ($parent) {
    $b = @(Get-ChildItem -LiteralPath $parent -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -ieq ".zip" })
    $cands += $b
  }
  if ($cands.Count -eq 0) { return "" }

  $prio = @($cands | Where-Object { $_.Name.ToLower().Contains("acervo") -or $_.Name.ToLower().Contains("pacote") })
  if ($prio.Count -ge 1) { return $prio[0].FullName }

  if ($cands.Count -eq 1) { return $cands[0].FullName }

  $sorted = @($cands | Sort-Object LastWriteTime -Descending)
  return $sorted[0].FullName
}

# -------------------------
# DIAG
# -------------------------
$repo = ResolveRepoHere
$npmExe = ResolveExe "npm.cmd"

$Slug = NormalizeSlug $Slug

$publicAcervo = Join-Path $repo ("public\cadernos\" + $Slug + "\acervo")
$contentDir = Join-Path $repo ("content\cadernos\" + $Slug)
$acervoJsonPath = Join-Path $contentDir "acervo.json"
$tmp = Join-Path $repo "tools\_tmp_import"
$reportsDir = Join-Path $repo "reports"

EnsureDir $publicAcervo
EnsureDir $contentDir
EnsureDir $reportsDir

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] Slug: " + $Slug)
WL ("[DIAG] Dest public: " + $publicAcervo)
WL ("[DIAG] Dest json: " + $acervoJsonPath)

# -------------------------
# ZIP resolve
# -------------------------
$zip = ""
if ($ZipPath) {
  if (-not (TestP $ZipPath)) { throw ("[STOP] ZipPath não existe: " + $ZipPath) }
  $zip = (Resolve-Path -LiteralPath $ZipPath).Path
} else {
  $zip = FindZipAuto $repo
}

$imported = @()

if ($zip) {
  WL ("[STEP] Import: ZIP encontrado: " + $zip)
  if (TestP $tmp) { Remove-Item -Recurse -Force $tmp }
  EnsureDir $tmp
  Expand-Archive -LiteralPath $zip -DestinationPath $tmp -Force

  $files = @(Get-ChildItem -LiteralPath $tmp -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
    $ext = $_.Extension.ToLower()
    $ext -in @(".pdf",".doc",".docx",".ppt",".pptx",".xls",".xlsx",".csv",".png",".jpg",".jpeg",".webp",".txt",".md")
  })

  foreach ($f in $files) {
    $dest = Join-Path $publicAcervo $f.Name
    Copy-Item -Force $f.FullName $dest

    $k = KindFromExt $f.Extension
    $imported += [PSCustomObject]@{
      file   = $f.Name
      title  = (TitleFromFile $f.Name)
      kind   = $k
      tags   = @("pacote-inicial","importado")
      source = "zip"
    }
  }

  WL ("[OK] Importou " + $imported.Count + " arquivos para public/cadernos/" + $Slug + "/acervo")
} else {
  WL "[WARN] ZIP não encontrado automaticamente."
  WL "       Dica: passe -ZipPath C:\caminho\arquivo.zip  (ou coloque um ZIP na raiz do repo)."
  $imported = @()
}

# -------------------------
# MERGE acervo.json
# -------------------------
BackupFile $acervoJsonPath

$existing = @()
if (TestP $acervoJsonPath) {
  try {
    $raw = Get-Content -LiteralPath $acervoJsonPath -Raw
    $parsed = $null
    if ($raw) { $parsed = (ConvertFrom-Json -InputObject $raw -ErrorAction Stop) }
    if ($parsed) {
      if ($parsed -is [System.Array]) { $existing = @($parsed) }
      else { $existing = @($parsed) }
    }
  } catch {
    $existing = @()
  }
}

# index by file
$map = @{}
foreach ($it in $existing) {
  try {
    $fn = [string]$it.file
    if ($fn) { $map[$fn] = $it }
  } catch {}
}
foreach ($it in $imported) {
  $map[$it.file] = $it
}

$out = @()
foreach ($k in $map.Keys) { $out += $map[$k] }

# sort by title then file
$out = @($out | Sort-Object @{Expression={ [string]$_.title }}, @{Expression={ [string]$_.file }})

if ($out.Count -eq 0) {
  # placeholder mínimo pra não ficar vazio
  $out = @(
    [PSCustomObject]@{
      file  = "(sem import ainda)"
      title = "Coloque um ZIP ou arquivos em public/cadernos/" + $Slug + "/acervo"
      kind  = "info"
      tags  = @("setup")
      source = "manual"
    }
  )
}

$json = ($out | ConvertTo-Json -Depth 6)
WriteUtf8NoBom $acervoJsonPath $json
WL ("[OK] acervo.json atualizado: " + $acervoJsonPath)

# -------------------------
# REPORT
# -------------------------
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $reportsDir "cv-7-import-acervo-zip-v0_7.md"

$lines = @()
$lines += ("# CV-7 — Import Acervo via ZIP — " + $now)
$lines += ""
$lines += "## O que fez"
$lines += "- Procurou ZIP automaticamente (repo e pasta pai) ou usou -ZipPath"
$lines += "- Extraiu e copiou arquivos para public/cadernos/" + $Slug + "/acervo"
$lines += "- Gerou/atualizou content/cadernos/" + $Slug + "/acervo.json (merge por nome de arquivo)"
$lines += ""
$lines += "## Observação importante"
$lines += "- Cadernos Vivos: aqui é ACERVO e REGISTRO (memória). Não é Recibo ECO."
$lines += ""
$lines += "## Próximo"
$lines += "- CV-8: Tela de 'Registro/ATA' (mutirão) com export e checklist (terminologia 100% Cadernos Vivos)."

WriteUtf8NoBom $reportPath ($lines -join "`n")
WL ("[OK] Report: " + $reportPath)

# -------------------------
# VERIFY
# -------------------------
if (-not $SkipLint) {
  WL "[VERIFY] npm run lint..."
  RunNative $repo $npmExe @("run","lint")
} else {
  WL "[VERIFY] lint pulado (-SkipLint)."
}

if (-not $SkipBuild) {
  WL "[VERIFY] npm run build..."
  RunNative $repo $npmExe @("run","build")
} else {
  WL "[VERIFY] build pulado (-SkipBuild)."
}

WL ""
WL ("[OK] CV-7 pronto. Abra /c/" + $Slug + "/acervo")