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
  $p = $here
  for ($i=0; $i -lt 6; $i++) {
    $p2 = Split-Path -Parent $p
    if (-not $p2 -or $p2 -eq $p) { break }
    $p = $p2
    if (TestP (Join-Path $p "package.json")) { return $p }
  }
  throw ("[STOP] Rode na raiz do repo (onde tem package.json). Atual: " + $here)
}

function PatchMapPointTypeOrInterface([string]$filePath) {
  $lines = Get-Content -LiteralPath $filePath -Encoding UTF8
  if (-not $lines) { return $false }

  # acha início (type ou interface)
  $start = -1
  $mode = "" # "type" | "interface"
  for ($i=0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*export\s+type\s+MapPoint\s*=') { $start = $i; $mode="type"; break }
    if ($lines[$i] -match '^\s*export\s+interface\s+MapPoint\b') { $start = $i; $mode="interface"; break }
  }
  if ($start -lt 0) { return $false }

  # acha abertura "{"
  $open = -1
  for ($i=$start; $i -lt [Math]::Min($start+80, $lines.Count); $i++) {
    if ($lines[$i] -match '\{') { $open = $i; break }
  }
  if ($open -lt 0) { return $false }

  # acha fechamento do bloco
  $close = -1
  if ($mode -eq "type") {
    for ($i=$open; $i -lt [Math]::Min($open+260, $lines.Count); $i++) {
      if ($lines[$i] -match '^\s*\};\s*$') { $close = $i; break }
    }
  } else {
    for ($i=$open; $i -lt [Math]::Min($open+260, $lines.Count); $i++) {
      if ($lines[$i] -match '^\s*\}\s*$') { $close = $i; break }
    }
  }
  if ($close -lt 0) { return $false }

  $block = ($lines[$open..$close] -join "`n")
  $hasLabel = ($block -match '\blabel\??\s*:')
  $hasName  = ($block -match '\bname\??\s*:')

  if ($hasLabel -and $hasName) { return $false }

  # indent
  $indent = "  "
  for ($i=$open+1; $i -lt $close; $i++) {
    if ($lines[$i] -match '^\s+\w') { $indent = ($lines[$i] -replace '^(\s+).*$','$1'); break }
  }

  # inserir após title, senão após id, senão após "{"
  $insertAt = $open + 1
  for ($i=$open+1; $i -lt $close; $i++) {
    if ($lines[$i] -match '\btitle\??\s*:\s*string') { $insertAt = $i + 1; break }
  }
  if ($insertAt -eq $open + 1) {
    for ($i=$open+1; $i -lt $close; $i++) {
      if ($lines[$i] -match '\bid\??\s*:\s*string') { $insertAt = $i + 1; break }
    }
  }

  $toInsert = @()
  if (-not $hasLabel) { $toInsert += ($indent + "label?: string;") }
  if (-not $hasName)  { $toInsert += ($indent + "name?: string;") }

  if ($toInsert.Count -eq 0) { return $false }

  $newLines = New-Object System.Collections.Generic.List[string]
  for ($i=0; $i -lt $lines.Count; $i++) {
    [void]$newLines.Add($lines[$i])
    if ($i -eq ($insertAt-1)) {
      foreach ($l in $toInsert) { [void]$newLines.Add($l) }
    }
  }

  BackupFile $filePath
  WriteUtf8NoBom $filePath (($newLines.ToArray() -join "`n"))
  return $true
}

# -------------------------
# DIAG
# -------------------------
$repo = ResolveRepoHere
$npmExe = ResolveExe "npm.cmd"
$src = Join-Path $repo "src"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)

if (-not (TestP $src)) { throw ("[STOP] Não achei src/: " + $src) }

# força array SEMPRE
$all = @(Get-ChildItem -Path $src -Recurse -File | Where-Object { $_.Extension -in ".ts",".tsx" })
$hits = @($all | Where-Object {
  (Select-String -LiteralPath $_.FullName -Pattern "export type MapPoint" -Quiet) -or
  (Select-String -LiteralPath $_.FullName -Pattern "export interface MapPoint" -Quiet)
})

WL ("[DIAG] arquivos com MapPoint exportado: " + $hits.Count)

$patched = @()
foreach ($f in $hits) {
  if (PatchMapPointTypeOrInterface $f.FullName) { $patched += $f.FullName }
}

WL ("[OK] patched MapPoint em: " + $patched.Count)
foreach ($p in $patched) { WL ("  - " + $p) }

# -------------------------
# REPORT
# -------------------------
$repDir = Join-Path $repo "reports"
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repDir "cv-4e-hotfix-mappoint-label-name.md"
$report = @(
("# CV-4e — Hotfix MapPoint label/name — " + $now),
"",
"## Problema",
"- Build falhava: MutiraoRegistro usa p.label / p.name, mas MapPoint não declarava essas props.",
"",
"## Correção",
"- MapPoint agora aceita label?: string e name?: string (compatível com diferentes JSONs de mapa).",
"",
"## Verify",
"- npm run lint",
"- npm run build"
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
WL "[OK] Hotfix aplicado."