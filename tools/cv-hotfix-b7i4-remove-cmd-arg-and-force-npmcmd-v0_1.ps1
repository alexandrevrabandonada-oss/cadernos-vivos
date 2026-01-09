# tools/cv-hotfix-b7i4-remove-cmd-arg-and-force-npmcmd-v0_1.ps1
# Fix B7I: remove "cmd" argumento do npm e troca resolver para npm.cmd; também LiteralPath em Test-Path.
# DIAG -> PATCH -> RUN -> VERIFY -> REPORT

param(
  [switch]$SkipRun,
  [switch]$SkipVerify
)

$ErrorActionPreference = "Stop"

function NewUtf8NoBomEncoding() { New-Object System.Text.UTF8Encoding($false) }

function EnsureDir([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) { [IO.Directory]::CreateDirectory($p) | Out-Null }
}

function WriteUtf8NoBom([string]$path, [string]$content) {
  $enc = NewUtf8NoBomEncoding
  [IO.File]::WriteAllText($path, $content, $enc)
}

function BackupFile([string]$absPath, [string]$backupRoot, [string]$stamp) {
  EnsureDir $backupRoot
  $dstDir = Join-Path $backupRoot $stamp
  EnsureDir $dstDir
  $name = Split-Path -Leaf $absPath
  $dst = Join-Path $dstDir ($name + "." + $stamp + ".bak")
  Copy-Item -LiteralPath $absPath -Destination $dst -Force
  return $dst
}

function AddLine([System.Collections.Generic.List[string]]$r, [string]$s="") {
  $r.Add($s) | Out-Null
}

function ResolveNpmCmd() {
  $c1 = Get-Command npm.cmd -ErrorAction SilentlyContinue
  if ($c1 -and (Test-Path -LiteralPath $c1.Source)) { return $c1.Source }

  $c2 = Get-Command npm -ErrorAction SilentlyContinue
  if ($c2 -and (Test-Path -LiteralPath $c2.Source)) {
    # se vier npm.ps1, tenta o irmão .cmd
    if ($c2.Source.ToLower().EndsWith(".ps1")) {
      $try = [IO.Path]::ChangeExtension($c2.Source, ".cmd")
      if (Test-Path -LiteralPath $try) { return $try }
    }
    return $c2.Source
  }

  $fallback = Join-Path ${env:ProgramFiles} "nodejs\npm.cmd"
  if (Test-Path -LiteralPath $fallback) { return $fallback }

  throw "Nao consegui localizar npm(.cmd)."
}

function RunNpm([string[]]$npmArgs, [string]$cwd) {
  if (-not $npmArgs -or $npmArgs.Count -eq 0) { throw "RunNpm recebeu args vazios." }
  $npm = ResolveNpmCmd
  $old = Get-Location
  try {
    Set-Location $cwd
    $out = & $npm @npmArgs 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
      throw ("Command failed: npm " + ($npmArgs -join " ") + "`n" + $out)
    }
    return $out.TrimEnd()
  } finally {
    Set-Location $old
  }
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$root = (Resolve-Path ".").Path

if (-not (Test-Path -LiteralPath (Join-Path $root "package.json"))) {
  throw "Rode na raiz do repo (onde tem package.json)."
}

$reportsDir = Join-Path $root "reports"
$backupDir  = Join-Path $root "tools\_patch_backup"
EnsureDir $reportsDir
EnsureDir $backupDir

$reportPath = Join-Path $reportsDir ("{0}-cv-hotfix-b7i4-remove-cmd-arg-and-force-npmcmd.md" -f $stamp)
$r = New-Object System.Collections.Generic.List[string]

AddLine $r "# CV HOTFIX B7I4 — Remover 'cmd' do npm no B7I + forcar npm.cmd"
AddLine $r ""
AddLine $r ("- Stamp: " + $stamp)
AddLine $r ("- Root: " + $root)
AddLine $r ""

# localizar B7I
$toolsDir = Join-Path $root "tools"
$b7iRel = "tools\cv-step-b7i-portals-curated-everywhere-v0_1.ps1"
$b7iAbs = Join-Path $root $b7iRel

if (-not (Test-Path -LiteralPath $b7iAbs)) {
  $cand = Get-ChildItem -LiteralPath $toolsDir -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "cv-step-b7i-portals-curated-everywhere*.ps1" } |
    Sort-Object Name -Descending |
    Select-Object -First 1
  if ($cand) {
    $b7iAbs = $cand.FullName
    $b7iRel = $cand.FullName.Substring($root.Length+1)
  }
}

AddLine $r "## DIAG"
AddLine $r ""
AddLine $r ("- npm(cmd) resolved: " + (ResolveNpmCmd))
AddLine $r ("- b7i script: " + $b7iRel)
AddLine $r ""

if (-not (Test-Path -LiteralPath $b7iAbs)) {
  AddLine $r "[ERR] nao achei o script B7I."
  WriteUtf8NoBom $reportPath ($r -join "`n")
  throw "Missing B7I script."
}

$raw = Get-Content -LiteralPath $b7iAbs -Raw
$patched = $raw

# 1) garantir que Get-Command use npm.cmd (não npm / npm.ps1 / npm.ps1 hard)
$patched = [regex]::Replace($patched, '(?m)\bGet-Command\s+npm\.ps1\b', 'Get-Command npm.cmd')
$patched = [regex]::Replace($patched, '(?m)\bGet-Command\s+npm\b(?!\.cmd)', 'Get-Command npm.cmd')

# 2) remover "cmd" como primeiro argumento de arrays @("cmd", ...)
#    cobre aspas simples e duplas
$patched = [regex]::Replace($patched, '@\(\s*["'']cmd["'']\s*,\s*', '@(')

# 3) remover "cmd" passado direto depois de & $algumaCoisa cmd ...
$patched = [regex]::Replace($patched, '(?m)(&\s+\$[A-Za-z_]\w*\s+)cmd(\s+)', '$1')
$patched = [regex]::Replace($patched, '(?m)(&\s+\$[A-Za-z_]\w*\s+)["'']cmd["''](\s+)', '$1')

# 4) paths com [slug] => Test-Path -LiteralPath $var (evita wildcard)
$patched = [regex]::Replace(
  $patched,
  '(?m)\bTest-Path\s+(?!-LiteralPath\b)(?!-Path\b)(\$[A-Za-z_][\w]*)',
  'Test-Path -LiteralPath $1'
)

AddLine $r "## PATCH"
AddLine $r ""

if ($patched -ne $raw) {
  $bk = BackupFile $b7iAbs $backupDir $stamp
  WriteUtf8NoBom $b7iAbs $patched
  AddLine $r ("[OK] patched: " + $b7iRel)
  AddLine $r ("- backup: " + $bk.Substring($root.Length+1))
} else {
  AddLine $r "[OK] sem mudanças (pattern não encontrou nada novo)."
}
AddLine $r ""

# RUN B7I
AddLine $r "## RUN (B7I)"
AddLine $r ""

if ($SkipRun) {
  AddLine $r "[SKIP] -SkipRun informado."
} else {
  try {
    $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
    AddLine $r ("[RUN] " + $pwsh + " -NoProfile -ExecutionPolicy Bypass -File " + $b7iRel)
    $out = & $pwsh -NoProfile -ExecutionPolicy Bypass -File $b7iAbs 2>&1 | Out-String
    AddLine $r $out.TrimEnd()
  } catch {
    AddLine $r ("[ERR] B7I falhou: " + $_.Exception.Message)
    AddLine $r (($_ | Out-String).TrimEnd())
    AddLine $r ""
  }
}
AddLine $r ""

# VERIFY
AddLine $r "## VERIFY (lint/build)"
AddLine $r ""

if ($SkipVerify) {
  AddLine $r "[SKIP] -SkipVerify informado."
} else {
  AddLine $r "[RUN] npm run lint"
  AddLine $r (RunNpm @("run","lint") $root)
  AddLine $r ""
  AddLine $r "[RUN] npm run build"
  AddLine $r (RunNpm @("run","build") $root)
  AddLine $r ""
  AddLine $r "[OK] lint/build ok"
}

WriteUtf8NoBom $reportPath ($r -join "`n")
Write-Host ("OK: report -> " + $reportPath)
Write-Host "DONE."