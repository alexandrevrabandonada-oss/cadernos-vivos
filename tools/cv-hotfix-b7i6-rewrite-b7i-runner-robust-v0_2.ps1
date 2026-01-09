# tools/cv-hotfix-b7i6-rewrite-b7i-runner-robust-v0_2.ps1
# Hotfix: reescreve RunCmd/RunNpm do B7I para:
# - sempre usar npm.cmd (evita npm.ps1 + "cmd")
# - nunca chamar npm sem args (evita "Usage")
# - aceitar qualquer ordem de params (args + cwd)
# DIAG -> PATCH -> RUN -> VERIFY -> REPORT

param(
  [switch]$SkipRun,
  [switch]$SkipVerify
)

$ErrorActionPreference = "Stop"

function NewUtf8NoBomEncoding() { New-Object System.Text.UTF8Encoding($false) }
function EnsureDir([string]$p){ if(-not (Test-Path -LiteralPath $p)){ [IO.Directory]::CreateDirectory($p) | Out-Null } }
function WriteUtf8NoBom([string]$path,[string]$content){ [IO.File]::WriteAllText($path,$content,(NewUtf8NoBomEncoding)) }

function BackupFile([string]$abs,[string]$bkRoot,[string]$stamp){
  EnsureDir $bkRoot
  $dir = Join-Path $bkRoot $stamp
  EnsureDir $dir
  $name = Split-Path -Leaf $abs
  $dst = Join-Path $dir ($name + "." + $stamp + ".bak")
  Copy-Item -LiteralPath $abs -Destination $dst -Force
  return $dst
}

function AddLine([System.Collections.Generic.List[string]]$r,[string]$s=""){ $r.Add($s) | Out-Null }

function ExtractBraceBlock([string]$text, [int]$startIdx) {
  $open = $text.IndexOf("{", $startIdx)
  if ($open -lt 0) { return $null }
  $depth = 0
  for ($i=$open; $i -lt $text.Length; $i++) {
    $ch = $text[$i]
    if ($ch -eq "{") { $depth++ }
    elseif ($ch -eq "}") {
      $depth--
      if ($depth -eq 0) {
        return [pscustomobject]@{ Open=$open; Close=$i; Block=$text.Substring($open, ($i-$open+1)) }
      }
    }
  }
  return $null
}

function ReplaceFunctionBlock([string]$text, [string]$funcName, [string]$newFuncText) {
  $m = [regex]::Match($text, "(?ms)^\s*function\s+$funcName\b")
  if (-not $m.Success) { return [pscustomobject]@{ Text=$text; Replaced=$false; Why="not-found" } }
  $start = $m.Index
  $blk = ExtractBraceBlock $text $start
  if (-not $blk) { return [pscustomobject]@{ Text=$text; Replaced=$false; Why="no-brace-block" } }
  $end = $blk.Close
  $newText = $text.Substring(0, $start) + $newFuncText + $text.Substring($end+1)
  return [pscustomobject]@{ Text=$newText; Replaced=$true; Why="ok" }
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$root  = (Resolve-Path ".").Path

if (-not (Test-Path -LiteralPath (Join-Path $root "package.json"))) {
  throw "Rode na raiz do repo (package.json). Root atual: $root"
}

$reportsDir = Join-Path $root "reports"
$backupDir  = Join-Path $root "tools\_patch_backup"
EnsureDir $reportsDir
EnsureDir $backupDir

$reportPath = Join-Path $reportsDir ("{0}-cv-hotfix-b7i6-rewrite-b7i-runner-robust-v0_2.md" -f $stamp)
$r = New-Object System.Collections.Generic.List[string]

AddLine $r "# CV HOTFIX B7I6 v0_2 — Runner robusto no B7I (RunCmd/RunNpm)"
AddLine $r ""
AddLine $r ("- Stamp: " + $stamp)
AddLine $r ("- Root: " + $root)
AddLine $r ""

$b7iRel = "tools\cv-step-b7i-portals-curated-everywhere-v0_1.ps1"
$b7iAbs = Join-Path $root $b7iRel
if (-not (Test-Path -LiteralPath $b7iAbs)) { throw "Missing: $b7iRel" }

AddLine $r "## DIAG"
AddLine $r ""
AddLine $r ("- Target: " + $b7iRel)
AddLine $r ""

$raw = Get-Content -LiteralPath $b7iAbs -Raw

# --- NOVO RunCmd ---
$newRunCmd = @(
'function RunCmd {',
'  param(',
'    [Parameter(ValueFromRemainingArguments=$true)]',
'    [object[]]$all',
'  )',
'  if (-not $all -or $all.Count -lt 1) { throw "RunCmd: missing cmd" }',
'',
'  $cmd = [string]$all[0]',
'  $rest = @()',
'  if ($all.Count -gt 1) { $rest = $all[1..($all.Count-1)] }',
'',
'  $cwd = $null',
'  $argsList = New-Object System.Collections.Generic.List[string]',
'',
'  foreach ($x in $rest) {',
'    # detecta cwd: um diretório que contém package.json',
'    if (-not $cwd -and $x -is [string]) {',
'      $s = [string]$x',
'      if (Test-Path -LiteralPath $s -PathType Container) {',
'        $pj = Join-Path $s "package.json"',
'        if (Test-Path -LiteralPath $pj) { $cwd = $s; continue }',
'      }',
'    }',
'',
'    # achata arrays/enumeráveis para args',
'    if ($x -is [string[]]) {',
'      foreach ($y in $x) { if ($y -ne $null -and [string]$y -ne "") { $argsList.Add([string]$y) | Out-Null } }',
'    } elseif ($x -is [System.Collections.IEnumerable] -and -not ($x -is [string])) {',
'      foreach ($y in $x) { if ($y -ne $null -and [string]$y -ne "") { $argsList.Add([string]$y) | Out-Null } }',
'    } else {',
'      if ($x -ne $null -and [string]$x -ne "") { $argsList.Add([string]$x) | Out-Null }',
'    }',
'  }',
'',
'  if (-not $cwd) { $cwd = (Resolve-Path ".").Path }',
'  $cmdArgs = @($argsList.ToArray())',
'',
'  $old = Get-Location',
'  try {',
'    Set-Location $cwd',
'    $pretty = $cmd + ($(if($cmdArgs.Count -gt 0){ " " + ($cmdArgs -join " ") } else { "" }))',
'    Write-Host ("[RUN] " + $pretty)',
'    $out = & $cmd @cmdArgs 2>&1 | Out-String',
'    if ($LASTEXITCODE -ne 0) { throw ("Command failed: " + $pretty + "`n" + $out) }',
'    return $out.TrimEnd()',
'  } finally {',
'    Set-Location $old',
'  }',
'}'
) -join "`n"

# --- NOVO RunNpm (força npm.cmd) ---
$newRunNpm = @(
'function RunNpm {',
'  param(',
'    [Parameter(ValueFromRemainingArguments=$true)]',
'    [object[]]$all',
'  )',
'  $npm = $null',
'',
'  $c1 = Get-Command npm.cmd -ErrorAction SilentlyContinue',
'  if ($c1 -and (Test-Path -LiteralPath $c1.Source)) { $npm = $c1.Source }',
'',
'  if (-not $npm) {',
'    $c2 = Get-Command npm -ErrorAction SilentlyContinue',
'    if ($c2 -and (Test-Path -LiteralPath $c2.Source)) {',
'      # se vier npm.ps1, tenta trocar por npm.cmd',
'      if ($c2.Source.ToLower().EndsWith(".ps1")) {',
'        $try = [IO.Path]::ChangeExtension($c2.Source, ".cmd")',
'        if (Test-Path -LiteralPath $try) { $npm = $try } else { $npm = $c2.Source }',
'      } else {',
'        $npm = $c2.Source',
'      }',
'    }',
'  }',
'',
'  if (-not $npm) {',
'    $fallback = Join-Path ${env:ProgramFiles} "nodejs\npm.cmd"',
'    if (Test-Path -LiteralPath $fallback) { $npm = $fallback }',
'  }',
'',
'  if (-not $npm) { throw "Nao consegui localizar npm.cmd" }',
'',
'  $pass = @($npm) + $all',
'  return (RunCmd @pass)',
'}'
) -join "`n"

AddLine $r "## PATCH"
AddLine $r ""

$patched = $raw

$rr1 = ReplaceFunctionBlock $patched "RunCmd" $newRunCmd
$patched = $rr1.Text
AddLine $r ("- RunCmd: " + ($(if($rr1.Replaced){"OK"}else{"SKIP ("+$rr1.Why+")"})))

$rr2 = ReplaceFunctionBlock $patched "RunNpm" $newRunNpm
$patched = $rr2.Text
AddLine $r ("- RunNpm: " + ($(if($rr2.Replaced){"OK"}else{"SKIP ("+$rr2.Why+")"})))

if ($patched -ne $raw) {
  $bk = BackupFile $b7iAbs $backupDir $stamp
  WriteUtf8NoBom $b7iAbs $patched
  AddLine $r ""
  AddLine $r ("[OK] patched: " + $b7iRel)
  AddLine $r ("- backup: " + $bk.Substring($root.Length+1))
} else {
  AddLine $r ""
  AddLine $r "[WARN] Nenhuma mudanca aplicada (funcoes nao encontradas ou iguais)."
}

AddLine $r ""
AddLine $r "## RUN (B7I)"
AddLine $r ""

if ($SkipRun) {
  AddLine $r "[SKIP] -SkipRun informado."
} else {
  try {
    $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
    AddLine $r ("[RUN] " + $pwsh + " -NoProfile -ExecutionPolicy Bypass -File " + $b7iRel)
    $out = & $pwsh -NoProfile -ExecutionPolicy Bypass -File $b7iAbs 2>&1 | Out-String
    AddLine $r "```"
    AddLine $r ($out.TrimEnd())
    AddLine $r "```"
  } catch {
    AddLine $r ("[ERR] B7I falhou: " + $_.Exception.Message)
    AddLine $r "```"
    AddLine $r (($_ | Out-String).TrimEnd())
    AddLine $r "```"
  }
}

AddLine $r ""
AddLine $r "## VERIFY (lint/build)"
AddLine $r ""

if ($SkipVerify) {
  AddLine $r "[SKIP] -SkipVerify informado."
} else {
  # roda via npm.cmd direto (sem chance de "cmd" extra)
  $npmCmd = (Get-Command npm.cmd -ErrorAction SilentlyContinue).Source
  if (-not $npmCmd) { $npmCmd = Join-Path ${env:ProgramFiles} "nodejs\npm.cmd" }
  if (-not (Test-Path -LiteralPath $npmCmd)) { throw "Nao achei npm.cmd em: $npmCmd" }

  $old = Get-Location
  try {
    Set-Location $root

    AddLine $r "[RUN] npm run lint"
    $o1 = & $npmCmd "run" "lint" 2>&1 | Out-String
    AddLine $r "```"
    AddLine $r ($o1.TrimEnd())
    AddLine $r "```"
    if ($LASTEXITCODE -ne 0) { throw "lint falhou" }

    AddLine $r ""
    AddLine $r "[RUN] npm run build"
    $o2 = & $npmCmd "run" "build" 2>&1 | Out-String
    AddLine $r "```"
    AddLine $r ($o2.TrimEnd())
    AddLine $r "```"
    if ($LASTEXITCODE -ne 0) { throw "build falhou" }

    AddLine $r ""
    AddLine $r "[OK] lint/build ok"
  } finally {
    Set-Location $old
  }
}

WriteUtf8NoBom $reportPath ($r -join "`n")
Write-Host ("OK: report -> " + $reportPath)
Write-Host "DONE."