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

function PatchFile([string]$file, [scriptblock]$fn) {
  if (-not (TestP $file)) { return $false }
  $raw = Get-Content -LiteralPath $file -Raw
  if ($null -eq $raw) { return $false }
  $next = & $fn $raw
  if ($null -eq $next) { return $false }
  if ($next -ne $raw) {
    BackupFile $file
    WriteUtf8NoBom $file $next
    return $true
  }
  return $false
}

# -------------------------
# DIAG
# -------------------------
$repo = ResolveRepoHere
$npmExe = ResolveExe "npm.cmd"

$srcDir = Join-Path $repo "src"
$contentDir = Join-Path $repo "content"
$componentsDir = Join-Path $srcDir "components"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] src: " + $srcDir)
WL ("[DIAG] content: " + $contentDir)
WL ("[DIAG] components: " + $componentsDir)

# -------------------------
# PATCH 1 — Terminologia (recibo -> registro/ata)
# -------------------------
$repls = @(
  @{ from = "Recibo do mutirão"; to = "ATA do mutirão" },
  @{ from = "recibo do mutirão"; to = "ata do mutirão" },
  @{ from = "Recibo de mutirão"; to = "ATA do mutirão" },
  @{ from = "recibo de mutirão"; to = "ata do mutirão" },
  @{ from = "Recibo ECO"; to = "Registro" },
  @{ from = "recibo ECO"; to = "registro" },
  @{ from = "Recibo"; to = "Registro" },
  @{ from = "recibo"; to = "registro" }
)

function ApplyRepls([string]$text) {
  $t = $text
  foreach ($r in $repls) {
    $t = $t.Replace($r.from, $r.to)
  }
  return $t
}

$targets = @()
if (TestP $srcDir) { $targets += $srcDir }
if (TestP $contentDir) { $targets += $contentDir }

[int]$changedTerminology = 0
foreach ($root in $targets) {
  [array]$files = @(Get-ChildItem -Path $root -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
    $_.Extension -in @(".ts",".tsx",".md",".json")
  })
  foreach ($f in $files) {
    $ok = PatchFile $f.FullName {
      param($raw)
      return (ApplyRepls $raw)
    }
    if ($ok) { $changedTerminology++ }
  }
}
WL ("[OK] Terminologia: arquivos alterados = " + $changedTerminology)

# -------------------------
# PATCH 2 — Renomear MutiraoRegistro -> AtaMutirao (arquivo + símbolo + imports)
# -------------------------
$oldComp = Join-Path $componentsDir "MutiraoRegistro.tsx"
$newComp = Join-Path $componentsDir "AtaMutirao.tsx"

$didRename = $false
if (TestP $oldComp -and -not (TestP $newComp)) {
  BackupFile $oldComp
  Rename-Item -LiteralPath $oldComp -NewName "AtaMutirao.tsx" -Force
  $didRename = $true
  WL "[OK] Renomeado: src/components/MutiraoRegistro.tsx -> src/components/AtaMutirao.tsx"
} elseif (TestP $newComp) {
  WL "[DIAG] AtaMutirao.tsx já existe (ok)."
} else {
  WL "[DIAG] MutiraoRegistro.tsx não encontrado (ok)."
}

if (TestP $newComp) {
  $ok = PatchFile $newComp {
    param($raw)
    $t = $raw
    $t = $t.Replace("export default function MutiraoRegistro", "export default function AtaMutirao")
    $t = $t.Replace("function MutiraoRegistro", "function AtaMutirao")
    $t = $t.Replace("export default MutiraoRegistro", "export default AtaMutirao")
    $t = $t.Replace("MutiraoRegistro", "AtaMutirao")
    $t = $t.Replace("Mutirão registro", "ATA do mutirão")
    $t = $t.Replace("Mutirão Registro", "ATA do mutirão")
    return $t
  }
  if ($ok) { WL "[OK] patched: AtaMutirao.tsx (nome do componente/strings)" }
}

# Atualiza imports/referências no src
if (TestP $srcDir) {
  [array]$srcFiles = @(Get-ChildItem -Path $srcDir -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
    $_.Extension -in @(".ts",".tsx")
  })

  [int]$changedImports = 0
  foreach ($f in $srcFiles) {
    $ok = PatchFile $f.FullName {
      param($raw)
      $t = $raw
      $t = $t.Replace("@/components/MutiraoRegistro", "@/components/AtaMutirao")
      $t = $t.Replace("../components/MutiraoRegistro", "../components/AtaMutirao")
      $t = $t.Replace("./MutiraoRegistro", "./AtaMutirao")
      $t = $t.Replace("MutiraoRegistro", "AtaMutirao")
      return $t
    }
    if ($ok) { $changedImports++ }
  }
  WL ("[OK] Imports: arquivos alterados = " + $changedImports)
}

# -------------------------
# REPORT
# -------------------------
$repDir = Join-Path $repo "reports"
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repDir "cv-8-terminologia-ata-v0_8.md"

$reportLines = @(
  ("# CV-8 — Terminologia: Registro (ATA) — " + $now),
  "",
  "## Objetivo",
  "- Parar a mistura de vocabulário entre projetos: aqui é Cadernos Vivos.",
  "- Trocar 'recibo' por 'registro' e usar 'ATA do mutirão' quando for evento/ação coletiva.",
  "",
  "## Mudanças",
  ("- Arquivos ajustados por terminologia (src/content): " + $changedTerminology),
  "- Renomeio de componente (quando existia): MutiraoRegistro -> AtaMutirao",
  "",
  "## Conceito (padrão do projeto)",
  "- Mutirão: evento/ação.",
  "- ATA do mutirão: registro do que foi feito, decisões, pendências e evidências.",
  "- Registro (ATA): memória local do caderno (salva no aparelho por enquanto).",
  "",
  "## Verify",
  "- npm run lint",
  "- npm run build"
)

WriteUtf8NoBom $reportPath ($reportLines -join "`n")
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
WL "[OK] CV-8 aplicado. Terminologia estabilizada: Registro/ATA."