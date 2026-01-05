param(
  [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function WL([string]$s){ Write-Host $s }
function TestP([string]$p){ Test-Path -LiteralPath $p }
function EnsureDir([string]$p){ if(-not (TestP $p)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function WriteUtf8NoBom([string]$p,[string]$content){
  $parent = Split-Path -Parent $p
  if($parent){ EnsureDir $parent }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($p,$content,$enc)
}
function BackupFile([string]$p){
  if(TestP $p){
    $ts = (Get-Date -Format "yyyyMMdd_HHmmss")
    $bakDir = Join-Path (Get-Location) "tools\_patch_backup"
    EnsureDir $bakDir
    $leaf = Split-Path -Leaf $p
    Copy-Item -LiteralPath $p -Destination (Join-Path $bakDir ($leaf + "." + $ts + ".bak")) -Force
  }
}
function ResolveRepoHere(){
  $here = (Get-Location).Path
  if(TestP (Join-Path $here "package.json")){ return $here }
  throw ("[STOP] Rode na raiz do repo (onde tem package.json). Atual: " + $here)
}
function ResolveNpmCmd(){
  $c = Get-Command "npm.cmd" -ErrorAction SilentlyContinue
  if($c -and $c.Source){ return $c.Source }
  $fallback = Join-Path ${env:ProgramFiles} "nodejs\npm.cmd"
  if(TestP $fallback){ return $fallback }
  return "npm.cmd"
}
function RunNative([string]$cwd,[string]$exe,[string[]]$cmdArgs){
  $pretty = ($cmdArgs -join " ")
  WL ("[RUN] " + $exe + " " + $pretty)
  Push-Location $cwd
  & $exe @cmdArgs
  $code = $LASTEXITCODE
  Pop-Location
  if($code -ne 0){ throw ("[STOP] comando falhou (exit " + $code + "): " + $exe + " " + $pretty) }
}

# -------------------------
# DIAG
# -------------------------
$repo = ResolveRepoHere
$bootstrap = Join-Path $repo "tools\_bootstrap.ps1"
if(-not (TestP $bootstrap)){ throw ("[STOP] Não achei tools/_bootstrap.ps1 em: " + $bootstrap) }

$npmCmd = ResolveNpmCmd
WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] bootstrap: " + $bootstrap)
WL ("[DIAG] npm.cmd: " + $npmCmd)

# -------------------------
# PATCH: ResolveExe em tools/_bootstrap.ps1
# -------------------------
BackupFile $bootstrap
$raw = Get-Content -LiteralPath $bootstrap -Raw
if(-not $raw){ throw "[STOP] tools/_bootstrap.ps1 veio vazio." }

$needle = "function ResolveExe"
$idx = $raw.IndexOf($needle, [System.StringComparison]::Ordinal)
if($idx -lt 0){ throw "[STOP] Não achei function ResolveExe no tools/_bootstrap.ps1" }

# acha o '{' da função
$openIdx = $raw.IndexOf("{", $idx)
if($openIdx -lt 0){ throw "[STOP] Não achei '{' depois do function ResolveExe" }

# brace matching até fechar a função
$depth = 0
$endIdx = -1
for($i=$openIdx; $i -lt $raw.Length; $i++){
  $ch = $raw[$i]
  if($ch -eq "{"){ $depth++ }
  elseif($ch -eq "}"){ 
    $depth--
    if($depth -eq 0){ $endIdx = $i; break }
  }
}
if($endIdx -lt 0){ throw "[STOP] Não consegui fechar o brace-matching do ResolveExe" }

$newFnLines = @(
'function ResolveExe([string]$name) {',
'  # Preferir wrappers .cmd (evita npm.ps1 interativo no Windows)',
'  if ($name -eq "npm" -or $name -eq "npm.ps1" -or $name -eq "npm.cmd") {',
'    $c = Get-Command "npm.cmd" -ErrorAction SilentlyContinue',
'    if ($c -and $c.Source) { return $c.Source }',
'    $fallback = Join-Path ${env:ProgramFiles} "nodejs\npm.cmd"',
'    if (Test-Path -LiteralPath $fallback) { return $fallback }',
'    return "npm.cmd"',
'  }',
'  $cmd = Get-Command $name -ErrorAction SilentlyContinue',
'  if ($cmd -and $cmd.Source) { return $cmd.Source }',
'  return $name',
'}'
) -join "`n"

$before = $raw.Substring(0, $idx)
$after  = $raw.Substring($endIdx + 1)
$patched = $before + $newFnLines + $after

WriteUtf8NoBom $bootstrap $patched
WL "[OK] patched: tools/_bootstrap.ps1 (ResolveExe prefere npm.cmd)"

# -------------------------
# REPORT
# -------------------------
$repDir = Join-Path $repo "reports"
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$repPath = Join-Path $repDir "cv-hotfix-bootstrap-prefer-npmcmd-v0_1.md"
$rep = @(
  ("# CV Hotfix — bootstrap preferir npm.cmd — " + $now),
  "",
  "## Problema",
  "- RunNative estava resolvendo npm para npm.ps1, disparando prompt interativo (instalação).",
  "",
  "## Fix",
  "- tools/_bootstrap.ps1: ResolveExe agora força npm.cmd no Windows (com fallback para Program Files).",
  "",
  "## Verify",
  "- npm run lint",
  "- npm run build"
) -join "`n"
WriteUtf8NoBom $repPath $rep
WL ("[OK] Report: " + $repPath)

# -------------------------
# VERIFY
# -------------------------
$npm = ResolveNpmCmd
WL "[VERIFY] npm run lint..."
RunNative $repo $npm @("run","lint")

if(-not $SkipBuild){
  WL "[VERIFY] npm run build..."
  RunNative $repo $npm @("run","build")
} else {
  WL "[VERIFY] build pulado (-SkipBuild)."
}

WL "[OK] Hotfix aplicado: npm.cmd fixo no bootstrap."