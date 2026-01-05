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

function BackupFile($path) {
  if (-not (Test-Path -LiteralPath $path)) { return $null }
  $bkRoot = Join-Path (Get-Location) 'tools\_patch_backup'
  EnsureDir $bkRoot
  $stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
  $name = (Split-Path -Leaf $path)
  if ($name -match '\.tsx?$') { $name = $name + '.bak' }
  $dest = Join-Path $bkRoot ($stamp + '-' + $name)
  Copy-Item -LiteralPath $path -Destination $dest -Force
  return $dest
}

function ResolveExe {
  param([string[]]$Candidates)
  if (-not $Candidates -or $Candidates.Count -eq 0) { return $null }
  foreach ($c in $Candidates) {
    if (-not $c) { continue }
    $cmd = Get-Command $c -ErrorAction SilentlyContinue
    if ($cmd) { return @($cmd)[0].Source }
  }
  return $Candidates[0]
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

function ReadJson([string]$p) {
  $raw = Get-Content -LiteralPath $p -Raw -ErrorAction Stop
  return ($raw | ConvertFrom-Json -ErrorAction Stop)
}

function WriteJson([string]$p, $obj) {
  $out = $obj | ConvertTo-Json -Depth 64
  WriteUtf8NoBom $p ($out + "`n")
}

# ---- CV: NewReport helper (auto-added) ----
function NewReport([string]$name, [string[]]$lines) {
  # Espera rodar a partir da raiz do repo
  $repDir = Join-Path (Get-Location) 'reports'
  EnsureDir $repDir
  $p = Join-Path $repDir $name
  WriteUtf8NoBom $p ($lines -join "
")
  return $p
}
# ---- /CV: NewReport helper ----


function RunCmd {
  param(
    [string]$Exe,
    [string[]]$CmdArgs
  )
  Write-Host ('[RUN] ' + $Exe + ' ' + ($CmdArgs -join ' '))
  & $Exe @CmdArgs
  if ($LASTEXITCODE -ne 0) {
    throw ('[STOP] comando falhou (exit ' + $LASTEXITCODE + '): ' + $Exe + ' ' + ($CmdArgs -join ' '))
  }
}
