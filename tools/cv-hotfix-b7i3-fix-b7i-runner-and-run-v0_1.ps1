# tools/cv-hotfix-b7i3-fix-b7i-runner-and-run-v0_1.ps1
# Fix B7I: npm runner (npm.ps1/cmd), $args reservado, e LiteralPath p/ paths com [slug]
# DIAG -> PATCH -> VERIFY -> REPORT

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

function PatchRunNpmBlock([string]$raw) {
  $idx = $raw.IndexOf("function RunNpm", [System.StringComparison]::OrdinalIgnoreCase)
  if ($idx -lt 0) { return @{ changed=$false; text=$raw; note="no RunNpm() found" } }

  $braceOpen = $raw.IndexOf("{", $idx)
  if ($braceOpen -lt 0) { return @{ changed=$false; text=$raw; note="RunNpm() sem {" } }

  $depth = 0
  $end = -1
  for ($i = $braceOpen; $i -lt $raw.Length; $i++) {
    $ch = $raw[$i]
    if ($ch -eq "{") { $depth++ }
    elseif ($ch -eq "}") { $depth--; if ($depth -eq 0) { $end = $i; break } }
  }
  if ($end -lt 0) { return @{ changed=$false; text=$raw; note="RunNpm() block nao fechou" } }

  $block = $raw.Substring($idx, ($end - $idx + 1))
  $newBlock = $block

  # 1) trocar param $args -> $npmArgs
  $newBlock = [regex]::Replace($newBlock, '\[string\[\]\]\s*\$args\b', '[string[]]$npmArgs')
  $newBlock = [regex]::Replace($newBlock, '\b\$args\b', '$npmArgs')
  $newBlock = [regex]::Replace($newBlock, '@npmArgs\b', '@npmArgs') # no-op, só pra manter claro

  # 2) se tinha "& $npm cmd ..." (erro npm.ps1), remover o "cmd"
  $newBlock = [regex]::Replace($newBlock, '(?m)&\s+\$npm\s+cmd(\s+)', '& $npm$1')

  if ($newBlock -eq $block) {
    return @{ changed=$false; text=$raw; note="RunNpm ok/no changes" }
  }

  $patched = $raw.Substring(0,$idx) + $newBlock + $raw.Substring($end+1)
  return @{ changed=$true; text=$patched; note="RunNpm patched" }
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

$reportPath = Join-Path $reportsDir ("{0}-cv-hotfix-b7i3-fix-b7i-runner-and-run.md" -f $stamp)
$r = New-Object System.Collections.Generic.List[string]

AddLine $r "# CV HOTFIX B7I3 — Fix runner do B7I + rerun"
AddLine $r ""
AddLine $r ("- Stamp: " + $stamp)
AddLine $r ("- Root: " + $root)
AddLine $r ""

# localizar B7I
$toolsDir = Join-Path $root "tools"
$b7iRel = "tools\cv-step-b7i-portals-curated-everywhere-v0_1.ps1"
$b7iAbs = Join-Path $root $b7iRel

if (-not (Test-Path -LiteralPath $b7iAbs)) {
  $cand = Get-ChildItem -LiteralPath $toolsDir -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "cv-step-b7i-portals-curated-everywhere*.ps1" } | Sort-Object Name -Descending | Select-Object -First 1
  if ($cand) {
    $b7iAbs = $cand.FullName
    $b7iRel = $cand.FullName.Substring($root.Length+1)
  }
}

AddLine $r "## DIAG"
AddLine $r ""
AddLine $r ("- npm resolved: " + (ResolveNpmCmd))
AddLine $r ("- b7i script: " + $b7iRel)
AddLine $r ""

if (-not (Test-Path -LiteralPath $b7iAbs)) {
  AddLine $r "[ERR] nao achei o script B7I."
  WriteUtf8NoBom $reportPath ($r -join "`n")
  throw "Missing B7I script."
}

# PATCH
AddLine $r "## PATCH"
AddLine $r ""

$raw = Get-Content -LiteralPath $b7iAbs -Raw
$patched = $raw

# A) evitar npm.ps1 / Get-Command npm.ps1
$patched = $patched.Replace("Get-Command npm.ps1", "Get-Command npm.cmd")

# B) se alguém fez "& $npm cmd ...", remove 'cmd'
$patched = [regex]::Replace($patched, '(?m)&\s+\$npm\s+cmd(\s+)', '& $npm$1')

# C) Test-Path com variável -> LiteralPath (pra não quebrar em [slug])
$patched = [regex]::Replace(
  $patched,
  '(?m)\bTest-Path\s+(?!-LiteralPath\b)(?!-Path\b)(\$[A-Za-z_][\w]*)',
  'Test-Path -LiteralPath $1'
)

# D) Get-Content -Raw $var => -LiteralPath $var -Raw
$patched = [regex]::Replace(
  $patched,
  '(?m)\bGet-Content\s+-Raw\s+(\$[A-Za-z_][\w]*)',
  'Get-Content -LiteralPath $1 -Raw'
)

# E) Patch específico do RunNpm ($args)
$res = PatchRunNpmBlock $patched
$patched = $res.text
AddLine $r ("- RunNpm patch: " + $res.note)

if ($patched -ne $raw) {
  $bk = BackupFile $b7iAbs $backupDir $stamp
  WriteUtf8NoBom $b7iAbs $patched
  AddLine $r ("[OK] patched: " + $b7iRel)
  AddLine $r ("- backup: " + $bk.Substring($root.Length+1))
} else {
  AddLine $r "[OK] sem mudanças (script já parecia corrigido)."
}

AddLine $r ""

# RUN B7I
AddLine $r "## RUN (B7I)"
AddLine $r ""

if ($SkipRun) {
  AddLine $r "[SKIP] -SkipRun informado."
} else {
  $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
  AddLine $r ("[RUN] " + $pwsh + " -NoProfile -ExecutionPolicy Bypass -File " + $b7iRel)
  $out = & $pwsh -NoProfile -ExecutionPolicy Bypass -File $b7iAbs 2>&1 | Out-String
  AddLine $r $out.TrimEnd()
  AddLine $r ""
}

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