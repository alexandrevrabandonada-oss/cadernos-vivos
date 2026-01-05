param(
  [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repo = (Get-Location).Path
$bootstrap = Join-Path $repo "tools\_bootstrap.ps1"

if (Test-Path -LiteralPath $bootstrap) {
  . $bootstrap
} else {
  function WL([string]$s) { Write-Host $s }
  function EnsureDir([string]$p) { if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
  function WriteUtf8NoBom([string]$p, [string]$content) {
    $parent = Split-Path -Parent $p
    if ($parent) { EnsureDir $parent }
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($p, $content, $enc)
  }
  function BackupFile([string]$p) {
    if (Test-Path -LiteralPath $p) {
      $ts = (Get-Date -Format "yyyyMMdd_HHmmss")
      $bakDir = Join-Path $repo "tools\_patch_backup"
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
  function NewReport([string]$name, [string[]]$lines) {
    $repDir = Join-Path $repo "reports"
    EnsureDir $repDir
    $p = Join-Path $repDir $name
    WriteUtf8NoBom $p ($lines -join "`n")
    return $p
  }
}

$npmExe = (ResolveExe "npm.cmd")
$norm = Join-Path $repo "src\lib\v2\normalize.ts"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] normalize: " + $norm)

if (-not (Test-Path -LiteralPath $norm)) { throw ("[STOP] Não achei normalize.ts em: " + $norm) }

BackupFile $norm
$raw = Get-Content -LiteralPath $norm -Raw

# Patch: garantir mood sempre string no MetaV2
# Troca "mood: mood," por "mood: (mood ?? "urban")," (robusto com regex)
$rx = New-Object System.Text.RegularExpressions.Regex("mood\s*:\s*mood\s*,")
$m = $rx.Match($raw)
if (-not $m.Success) {
  throw "[STOP] Não achei o trecho 'mood: mood,' em normalize.ts. Me mande as linhas do objeto meta."
}

$replacement = 'mood: (mood ?? "urban"),'
$raw2 = $raw.Substring(0, $m.Index) + $replacement + $raw.Substring($m.Index + $m.Length)

WriteUtf8NoBom $norm $raw2
WL "[OK] patched: normalize.ts (mood default -> urban)"

$now = (Get-Date -Format "yyyy-MM-dd HH:mm")
$lines = @(
  ("# CV V2 Hotfix — normalize mood default v0.4d — " + $now),
  "",
  "## Problema",
  "- MetaV2 exige mood string, mas normalize.ts gerava mood como string|undefined e atribuía direto.",
  "",
  "## Fix",
  "- No objeto meta, mood passou a ser (mood ?? ""urban"") para sempre sair string.",
  "",
  "## Arquivo alterado",
  "- src/lib/v2/normalize.ts",
  "",
  "## Verify",
  "- npm run lint",
  "- npm run build"
)

$repPath = NewReport "cv-v2-hotfix-normalize-mood-default-v0_4d.md" $lines
WL ("[OK] Report: " + $repPath)

WL "[VERIFY] npm run lint..."
RunNative $repo $npmExe @("run","lint")

if (-not $SkipBuild) {
  WL "[VERIFY] npm run build..."
  RunNative $repo $npmExe @("run","build")
} else {
  WL "[VERIFY] build pulado (-SkipBuild)."
}

WL "[OK] Hotfix aplicado (mood default no normalize)."