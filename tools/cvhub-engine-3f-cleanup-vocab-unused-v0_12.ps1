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

function PatchRemoveReadingControls([string]$file) {
  $raw = Get-Content -LiteralPath $file -Raw
  if ($null -eq $raw) { return $false }

  $lines = $raw -split "(`r`n|`n)"
  $out = New-Object System.Collections.Generic.List[string]

  $changed = $false
  foreach ($ln in $lines) {
    $t = $ln.Trim()

    # remove import ReadingControls...
    if ($t.StartsWith("import ReadingControls") -and $t.Contains("ReadingControls")) {
      $changed = $true
      continue
    }

    # remove JSX line with <ReadingControls ... />
    if ($ln.Contains("<ReadingControls")) {
      $changed = $true
      continue
    }

    $out.Add($ln) | Out-Null
  }

  if ($changed) {
    BackupFile $file
    WriteUtf8NoBom $file (($out.ToArray()) -join "`n")
  }

  return $changed
}

# -------------------------
# DIAG
# -------------------------
$repo = ResolveRepoHere
$npmExe = ResolveExe "npm.cmd"

$appScope = Join-Path $repo "src\app\c\[slug]"
$libPath  = Join-Path $repo "src\lib\cadernos.ts"
$mutPath  = Join-Path $repo "src\components\MutiraoRegistro.tsx"
$repDir   = Join-Path $repo "reports"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] Scope: " + $appScope)
WL ("[DIAG] cadernos.ts: " + $libPath)
WL ("[DIAG] MutiraoRegistro.tsx: " + $mutPath)

# -------------------------
# PATCH 1: remover ReadingControls das pages (agora vem do layout)
# -------------------------
$changedPages = 0
if (TestP $appScope) {
  $files = Get-ChildItem -LiteralPath $appScope -Recurse -File -Include *.ts,*.tsx
  foreach ($f in $files) {
    $did = PatchRemoveReadingControls $f.FullName
    if ($did) { $changedPages++ }
  }
}
WL ("[OK] pages cleaned (ReadingControls removido): " + [string]$changedPages)

# -------------------------
# PATCH 2: cadernos.ts — exportar parsers para não ficarem "unused"
# -------------------------
if (TestP $libPath) {
  $raw = Get-Content -LiteralPath $libPath -Raw
  if ($null -eq $raw) { throw "[STOP] cadernos.ts veio nulo" }

  $new = $raw

  if ($new -like "*function parseMapaJson*" -and $new -notlike "*export function parseMapaJson*") {
    $new = $new.Replace("function parseMapaJson", "export function parseMapaJson")
  }
  if ($new -like "*function parseDebateJson*" -and $new -notlike "*export function parseDebateJson*") {
    $new = $new.Replace("function parseDebateJson", "export function parseDebateJson")
  }
  if ($new -like "*function parseAcervoJson*" -and $new -notlike "*export function parseAcervoJson*") {
    $new = $new.Replace("function parseAcervoJson", "export function parseAcervoJson")
  }

  if ($new -ne $raw) {
    BackupFile $libPath
    WriteUtf8NoBom $libPath $new
    WL "[OK] patched: cadernos.ts (parsers exportados)"
  } else {
    WL "[OK] cadernos.ts sem mudanca (ja exportado ou nao encontrado)"
  }
}

# -------------------------
# PATCH 3: vocabulário CV (texto visível)
# -------------------------
if (TestP $mutPath) {
  $raw2 = Get-Content -LiteralPath $mutPath -Raw
  if ($null -eq $raw2) { throw "[STOP] MutiraoRegistro.tsx veio nulo" }

  $new2 = $raw2
  # só troca palavras com maiúscula/acentos (bem conservador)
  $new2 = $new2.Replace("Mutirão", "Ação coletiva")
  $new2 = $new2.Replace("Recibo", "Registro")
  $new2 = $new2.Replace("mutirão", "ação coletiva")

  if ($new2 -ne $raw2) {
    BackupFile $mutPath
    WriteUtf8NoBom $mutPath $new2
    WL "[OK] patched: MutiraoRegistro.tsx (vocabulário CV)"
  } else {
    WL "[OK] MutiraoRegistro.tsx sem mudanca (palavras não encontradas)"
  }
} else {
  WL "[WARN] MutiraoRegistro.tsx não encontrado — pulei vocabulário nele."
}

# -------------------------
# REPORT
# -------------------------
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repDir "cv-engine-3f-cleanup-vocab-unused-v0_12.md"
$report = @(
  ("# CV Engine-3F — Cleanup + Vocabulário v0.12 — " + $now),
  "",
  "## Feito",
  ("- Removido ReadingControls das páginas (agora vem do layout): " + [string]$changedPages),
  "- cadernos.ts: parsers exportados (evita unused-vars)",
  "- Vocabulário: Mutirão/Recibo -> Ação coletiva/Registro (texto visível)",
  "",
  "## Próximo",
  "- Renomear o componente MutiraoRegistro (nome interno) para algo tipo AcaoColetivaRegistro (sem pressa)",
  "- Padronizar labels/headers em todas as páginas (um 'universo' consistente por seção)",
  ""
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
WL "[OK] Engine-3F aplicado."