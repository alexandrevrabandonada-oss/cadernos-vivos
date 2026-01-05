param(
  [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function WL([string]$s) { Write-Host $s }

function EnsureDir([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

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

$repo = FindRepoRoot
$npmExe = ResolveExe "npm.cmd"

$boot = Join-Path $repo "tools\_bootstrap.ps1"
$contentRoot = Join-Path $repo "content\cadernos"
$repDir = Join-Path $repo "reports"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] bootstrap: " + $boot)

if (Test-Path -LiteralPath $boot) {
  . $boot
}

# Se o bootstrap não tiver NewReport, cria local e (opcional) injeta no bootstrap com backup
$hasNewReport = Get-Command NewReport -ErrorAction SilentlyContinue
if (-not $hasNewReport) {
  WL "[WARN] NewReport não existe. Vou definir e também corrigir o tools/_bootstrap.ps1 (com backup)."

  function NewReport([string]$name, [string[]]$lines) {
    $repoHere = FindRepoRoot
    $rep = Join-Path $repoHere "reports"
    EnsureDir $rep
    $p = Join-Path $rep $name
    WriteUtf8NoBom $p ($lines -join "`n")
    return $p
  }

  if (Test-Path -LiteralPath $boot) {
    $raw = Get-Content -LiteralPath $boot -Raw
    if ($raw -notlike "*function NewReport*") {
      BackupFile $boot
      $append = @(
        "",
        "# ---- CV: NewReport helper (auto-added) ----",
        "function NewReport([string]`$name, [string[]]`$lines) {",
        "  # Espera rodar a partir da raiz do repo",
        "  `$repDir = Join-Path (Get-Location) 'reports'",
        "  EnsureDir `$repDir",
        "  `$p = Join-Path `$repDir `$name",
        "  WriteUtf8NoBom `$p (`$lines -join `"`n`")",
        "  return `$p",
        "}",
        "# ---- /CV: NewReport helper ----",
        ""
      ) -join "`n"

      WriteUtf8NoBom $boot ($raw + $append)
      WL "[OK] patched: tools/_bootstrap.ps1 (NewReport adicionado)"
    } else {
      WL "[OK] tools/_bootstrap.ps1 já tinha NewReport (texto encontrado)."
    }
  }
} else {
  WL "[OK] NewReport já existe (vindo do bootstrap)."
}

# Recriar o report do Engine-4C (scan de content/cadernos)
EnsureDir $repDir
$lines = @()
$lines += ("# CV Engine-4C — Status Page + Content Scan — " + (Get-Date -Format "yyyy-MM-dd HH:mm"))
$lines += ""
$lines += "## Correção aplicada"
$lines += "- NewReport agora existe (local e/ou bootstrap)."
$lines += "- Report 4C gerado com scan de content/cadernos."
$lines += ""
$lines += "## Como usar"
$lines += "- Abra: /c/SEU-SLUG/status (ex.: /c/poluicao-vr/status)"
$lines += ""

if (Test-Path -LiteralPath $contentRoot) {
  $dirs = Get-ChildItem -LiteralPath $contentRoot -Directory -ErrorAction SilentlyContinue
  $count = ($dirs | Measure-Object).Count
  $lines += ("## Cadernos encontrados: " + $count)
  $lines += ""

  foreach ($d in $dirs) {
    $slug = $d.Name
    $base = $d.FullName

    $metaOk = Test-Path -LiteralPath (Join-Path $base "meta.json")
    $aulasOk = Test-Path -LiteralPath (Join-Path $base "aulas")
    $mapaOk = Test-Path -LiteralPath (Join-Path $base "mapa.json")
    $debateOk = Test-Path -LiteralPath (Join-Path $base "debate.json")

    $trilhaOk = (Test-Path -LiteralPath (Join-Path $base "trilha.json")) -or (Test-Path -LiteralPath (Join-Path $base "trilha.md")) -or (Test-Path -LiteralPath (Join-Path $base "trilha.mdx"))
    $quizOk   = (Test-Path -LiteralPath (Join-Path $base "quiz.json"))   -or (Test-Path -LiteralPath (Join-Path $base "quiz.md"))   -or (Test-Path -LiteralPath (Join-Path $base "quiz.mdx"))
    $acervoOk = (Test-Path -LiteralPath (Join-Path $base "acervo.json")) -or (Test-Path -LiteralPath (Join-Path $base "acervo.md")) -or (Test-Path -LiteralPath (Join-Path $base "acervo.mdx"))
    $praticaOk = (Test-Path -LiteralPath (Join-Path $base "pratica.json")) -or (Test-Path -LiteralPath (Join-Path $base "pratica.md")) -or (Test-Path -LiteralPath (Join-Path $base "pratica.mdx"))
    $registroOk = (Test-Path -LiteralPath (Join-Path $base "registro.json")) -or (Test-Path -LiteralPath (Join-Path $base "registro.md")) -or (Test-Path -LiteralPath (Join-Path $base "registro.mdx"))

    $ok = 0
    if ($metaOk) { $ok++ }
    if ($aulasOk) { $ok++ }
    if ($trilhaOk) { $ok++ }
    if ($praticaOk) { $ok++ }
    if ($quizOk) { $ok++ }
    if ($acervoOk) { $ok++ }
    if ($mapaOk) { $ok++ }
    if ($debateOk) { $ok++ }
    if ($registroOk) { $ok++ }

    $lines += ("- " + $slug + " — " + $ok + "/9 — /c/" + $slug + "/status")
  }
} else {
  $lines += "## Aviso"
  $lines += "- Não achei content/cadernos (sem scan)."
}

$repPath = NewReport "cv-engine-4c-status-page-v0_17.md" $lines
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
WL "[OK] Hotfix aplicado: Engine-4C finalizado."