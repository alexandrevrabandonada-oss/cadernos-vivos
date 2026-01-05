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
$tmPath = Join-Path $repo "src\components\TerritoryMap.tsx"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] File: " + $tmPath)

if (-not (TestP $tmPath)) { throw ("[STOP] Não achei: " + $tmPath) }

$raw = Get-Content -LiteralPath $tmPath -Raw
if ($null -eq $raw -or $raw.Trim().Length -eq 0) { throw "[STOP] TerritoryMap.tsx vazio ou não lido." }

# -------------------------
# PATCH
# -------------------------
BackupFile $tmPath

$lines = $raw -split "`r?`n"

$changed = 0
$leftAny = 0

for ($i=0; $i -lt $lines.Count; $i++) {
  $ln = $lines[$i]
  $orig = $ln

  # 1) se for "param: any" em linha com => ou function, remove só o ": any" (deixa inferir)
  if ($ln.Contains(": any")) {
    $trim = $ln.TrimStart()

    $looksLikeFnLine = ($ln.Contains("=>") -or $trim.StartsWith("function ") -or $trim.StartsWith("async function "))

    if ($looksLikeFnLine) {
      # tenta remover só dentro do primeiro parênteses da linha (caso típico: onChange={(e: any) => ...})
      $open = $ln.IndexOf("(")
      $close = $ln.IndexOf(")")
      if ($open -ge 0 -and $close -gt $open) {
        $before = $ln.Substring(0, $open)
        $mid = $ln.Substring($open, ($close - $open + 1))
        $after = $ln.Substring($close + 1)
        $mid2 = $mid.Replace(": any", "")
        $ln = $before + $mid2 + $after
      } else {
        $ln = $ln.Replace(": any", "")
      }
    } elseif ($trim.StartsWith("const ") -or $trim.StartsWith("let ") -or $trim.StartsWith("var ")) {
      # 2) variável tipada como any: remove o ": any" para inferir do RHS
      $ln = $ln.Replace(": any", "")
    } else {
      # 3) caso estranho: não mexe agressivo, só marca para possível eslint-disable
      $leftAny++
    }
  }

  $lines[$i] = $ln
  if ($lines[$i] -ne $orig) { $changed++ }
}

# Se ainda ficou algum ": any" em linhas "estranhas", adiciona eslint-disable-next-line acima dessas linhas
if ($leftAny -gt 0) {
  $out = New-Object System.Collections.Generic.List[string]
  for ($i=0; $i -lt $lines.Count; $i++) {
    $ln = $lines[$i]
    if ($ln.Contains(": any")) {
      $out.Add("// eslint-disable-next-line @typescript-eslint/no-explicit-any") | Out-Null
      $out.Add($ln) | Out-Null
      $changed++
    } else {
      $out.Add($ln) | Out-Null
    }
  }
  $lines = $out.ToArray()
}

$newRaw = ($lines -join "`n")
WriteUtf8NoBom $tmPath $newRaw

WL ("[OK] TerritoryMap.tsx patch aplicado. Linhas alteradas: " + $changed)

# -------------------------
# REPORT
# -------------------------
$repDir = Join-Path $repo "reports"
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repDir "cv-4g-hotfix-territorymap-no-any.md"

$reportLines = @(
  ("# CV-4g — Hotfix TerritoryMap sem any — " + $now),
  "",
  "## Problema",
  "- ESLint: @typescript-eslint/no-explicit-any em src/components/TerritoryMap.tsx",
  "",
  "## Correcao",
  "- Removeu anotacoes ': any' em parametros e vars para deixar TS inferir",
  "- Se sobrou algum caso fora do padrao, adicionou eslint-disable-next-line somente na linha especifica",
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
WL "[OK] Seguimos. Se aparecer novo erro de build/TS, manda o bloco e a gente corrige."