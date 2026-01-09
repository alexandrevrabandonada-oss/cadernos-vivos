# tools/cv-hotfix-b7x1-runner-and-sanitize-unify-v0_1.ps1
# Fixes:
# 1) sanitize script: .Replace(char,"") -> .Replace([string]char,"")
# 2) runner: RunCmd/RunNpm robustos (sem param $args), sempre com npm.cmd
# DIAG -> PATCH -> VERIFY -> REPORT

param(
  [switch]$SkipVerify
)

$ErrorActionPreference = "Stop"

function NewUtf8NoBomEncoding() { New-Object System.Text.UTF8Encoding($false) }

function EnsureDir([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) { [IO.Directory]::CreateDirectory($p) | Out-Null }
}

function WriteUtf8NoBom([string]$path, [string]$content) {
  [IO.File]::WriteAllText($path, $content, (NewUtf8NoBomEncoding))
}

function BackupFile([string]$absPath, [string]$backupRoot, [string]$stamp) {
  $dir = Join-Path $backupRoot $stamp
  EnsureDir $dir
  $name = Split-Path -Leaf $absPath
  $dst  = Join-Path $dir ($name + "." + $stamp + ".bak")
  Copy-Item -LiteralPath $absPath -Destination $dst -Force
  return $dst
}

function AddLine([System.Collections.Generic.List[string]]$r, [string]$s="") { $r.Add($s) | Out-Null }

function ResolveNpmCmd() {
  $c1 = Get-Command npm.cmd -ErrorAction SilentlyContinue
  if ($c1 -and (Test-Path -LiteralPath $c1.Source)) { return $c1.Source }

  $c2 = Get-Command npm -ErrorAction SilentlyContinue
  if ($c2 -and (Test-Path -LiteralPath $c2.Source)) {
    $src = [string]$c2.Source
    if ($src.ToLower().EndsWith(".ps1")) {
      $try = [IO.Path]::ChangeExtension($src, ".cmd")
      if (Test-Path -LiteralPath $try) { return $try }
    }
    return $src
  }

  $fallback = Join-Path ${env:ProgramFiles} "nodejs\npm.cmd"
  if (Test-Path -LiteralPath $fallback) { return $fallback }

  throw "Nao consegui localizar npm(.cmd)."
}

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
  $m = [regex]::Match($text, "(?ms)^\s*function\s+$([regex]::Escape($funcName))\b")
  if (-not $m.Success) { return [pscustomobject]@{ Text=$text; Replaced=$false; Why="not-found" } }
  $start = $m.Index
  $blk = ExtractBraceBlock $text $start
  if (-not $blk) { return [pscustomobject]@{ Text=$text; Replaced=$false; Why="no-brace-block" } }
  $end = $blk.Close
  $newText = $text.Substring(0, $start) + $newFuncText + $text.Substring($end+1)
  return [pscustomobject]@{ Text=$newText; Replaced=$true; Why="ok" }
}

function InsertAfterFunction([string]$text, [string]$afterFuncName, [string]$insertText) {
  $m = [regex]::Match($text, "(?ms)^\s*function\s+$([regex]::Escape($afterFuncName))\b")
  if (-not $m.Success) { return [pscustomobject]@{ Text=$text; Inserted=$false; Why="after-not-found" } }
  $blk = ExtractBraceBlock $text $m.Index
  if (-not $blk) { return [pscustomobject]@{ Text=$text; Inserted=$false; Why="after-no-brace-block" } }
  $pos = $blk.Close + 1
  $newText = $text.Substring(0, $pos) + "`r`n`r`n" + $insertText + "`r`n" + $text.Substring($pos)
  return [pscustomobject]@{ Text=$newText; Inserted=$true; Why="ok" }
}

function RunInCwd([string]$cmd, [string[]]$cmdArgs, [string]$cwd) {
  $old = Get-Location
  try {
    Set-Location $cwd
    $argsToPass = @()
    if ($cmdArgs) { $argsToPass = @($cmdArgs) }
    Write-Host ("[RUN] " + $cmd + ($(if($argsToPass.Count -gt 0){ " " + ($argsToPass -join " ") } else { "" })))
    $out = & $cmd @argsToPass 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw ("Command failed: " + $cmd + " " + ($argsToPass -join " ") + "`n" + $out) }
    return $out.TrimEnd()
  } finally {
    Set-Location $old
  }
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$root  = (Resolve-Path ".").Path

if (-not (Test-Path -LiteralPath (Join-Path $root "package.json"))) { throw "Rode na raiz do repo (package.json). Root: $root" }

$reportsDir = Join-Path $root "reports"
$backupDir  = Join-Path $root "tools\_patch_backup"
EnsureDir $reportsDir
EnsureDir $backupDir

$reportPath = Join-Path $reportsDir ("{0}-cv-hotfix-b7x1-runner-and-sanitize-unify.md" -f $stamp)
$r = New-Object System.Collections.Generic.List[string]

AddLine $r "# CV HOTFIX B7X1 — Runner robusto + sanitize fix"
AddLine $r ""
AddLine $r ("- Stamp: " + $stamp)
AddLine $r ("- Root: " + $root)
AddLine $r ""

# ---------- TARGETS ----------
$targets = New-Object System.Collections.Generic.List[string]

$maybeB7n = @(
  "tools\cv-step-b7n-map-core-highlights-v0_2.ps1",
  "tools\cv-step-b7n-map-core-highlights-v0_1.ps1"
)
foreach($rel in $maybeB7n){
  $abs = Join-Path $root $rel
  if (Test-Path -LiteralPath $abs) { $targets.Add($rel) | Out-Null }
}

$maybeB7o4 = Get-ChildItem -LiteralPath (Join-Path $root "tools") -File -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -like "cv-hotfix-b7o4-fix-sanitize-script-and-verify-v*.ps1" } |
  Select-Object -ExpandProperty FullName

foreach($abs in $maybeB7o4){
  $rel = $abs.Substring($root.Length+1)
  $targets.Add($rel) | Out-Null
}

AddLine $r "## DIAG"
AddLine $r ""
AddLine $r ("- Runner targets encontrados: " + $targets.Count)
foreach($t in $targets){ AddLine $r ("  - " + $t) }

$sanRel = "tools\cv-hotfix-b7o3-core-highlights-sanitize-inject.ps1"
$sanAbs = Join-Path $root $sanRel
AddLine $r ""
AddLine $r ("- Sanitize target: " + $sanRel + " => " + (Test-Path -LiteralPath $sanAbs))
AddLine $r ""

# ---------- PATCH RUNNER ----------
$runCmdFunc = @(
  "function RunCmd {",
  "  param(",
  "    [Parameter(Mandatory=$true)][string]$cmd,",
  "    [string[]]$cmdArgs = @(),",
  "    [string]$cwd = $null",
  "  )",
  "  if (-not $cwd -or $cwd -eq '') { $cwd = (Resolve-Path '.').Path }",
  "  $old = Get-Location",
  "  try {",
  "    Set-Location $cwd",
  "    $argsToPass = @()",
  "    if ($cmdArgs) { $argsToPass = @($cmdArgs) }",
  "    Write-Host ('[RUN] ' + $cmd + ($(if($argsToPass.Count -gt 0){ ' ' + ($argsToPass -join ' ') } else { '' })))",
  "    $out = & $cmd @argsToPass 2>&1 | Out-String",
  "    if ($LASTEXITCODE -ne 0) { throw ('Command failed: ' + $cmd + ' ' + ($argsToPass -join ' ') + \"`n\" + $out) }",
  "    return $out.TrimEnd()",
  "  } finally {",
  "    Set-Location $old",
  "  }",
  "}"
) -join "`r`n"

$runNpmFunc = @(
  "function RunNpm {",
  "  param(",
  "    [Parameter(ValueFromRemainingArguments=$true)][object[]]$all",
  "  )",
  "  $npm = $null",
  "  $c1 = Get-Command npm.cmd -ErrorAction SilentlyContinue",
  "  if ($c1 -and (Test-Path -LiteralPath $c1.Source)) { $npm = $c1.Source }",
  "  if (-not $npm) {",
  "    $c2 = Get-Command npm -ErrorAction SilentlyContinue",
  "    if ($c2 -and (Test-Path -LiteralPath $c2.Source)) {",
  "      $src = [string]$c2.Source",
  "      if ($src.ToLower().EndsWith('.ps1')) {",
  "        $try = [IO.Path]::ChangeExtension($src, '.cmd')",
  "        if (Test-Path -LiteralPath $try) { $npm = $try } else { $npm = $src }",
  "      } else {",
  "        $npm = $src",
  "      }",
  "    }",
  "  }",
  "  if (-not $npm) {",
  "    $fallback = Join-Path ${env:ProgramFiles} 'nodejs\npm.cmd'",
  "    if (Test-Path -LiteralPath $fallback) { $npm = $fallback }",
  "  }",
  "  if (-not $npm) { throw 'Nao consegui localizar npm(.cmd).' }",
  "",
  "  # suporta chamadas tipo: RunNpm @('run','lint') $root  OU  RunNpm 'run' 'lint' $root",
  "  $cwd = $null",
  "  $argsList = New-Object System.Collections.Generic.List[string]",
  "  foreach ($x in $all) {",
  "    if (-not $cwd -and $x -is [string]) {",
  "      $s = [string]$x",
  "      if (Test-Path -LiteralPath $s -PathType Container) {",
  "        $pj = Join-Path $s 'package.json'",
  "        if (Test-Path -LiteralPath $pj) { $cwd = $s; continue }",
  "      }",
  "    }",
  "    if ($x -is [string[]]) { foreach ($y in $x) { if ($y) { $argsList.Add([string]$y) | Out-Null } } }",
  "    elseif ($x -is [System.Collections.IEnumerable] -and -not ($x -is [string])) { foreach ($y in $x) { if ($y) { $argsList.Add([string]$y) | Out-Null } } }",
  "    else { if ($x) { $argsList.Add([string]$x) | Out-Null } }",
  "  }",
  "  if (-not $cwd) { $cwd = (Resolve-Path '.').Path }",
  "  return (RunCmd $npm ($argsList.ToArray()) $cwd)",
  "}"
) -join "`r`n"

AddLine $r "## PATCH — Runner (RunCmd/RunNpm)"
AddLine $r ""

foreach($rel in $targets){
  $abs = Join-Path $root $rel
  $raw = Get-Content -LiteralPath $abs -Raw
  $patched = $raw

  $rr1 = ReplaceFunctionBlock $patched "RunCmd" $runCmdFunc
  $patched = $rr1.Text

  $hasRunNpm = [regex]::IsMatch($patched, "(?ms)^\s*function\s+RunNpm\b")
  if ($hasRunNpm) {
    $rr2 = ReplaceFunctionBlock $patched "RunNpm" $runNpmFunc
    $patched = $rr2.Text
    $runNpmStatus = $(if($rr2.Replaced){"OK"}else{"SKIP ("+$rr2.Why+")"})
  } else {
    $ins = InsertAfterFunction $patched "RunCmd" $runNpmFunc
    $patched = $ins.Text
    $runNpmStatus = $(if($ins.Inserted){"INSERT"}else{"SKIP ("+$ins.Why+")"})
  }

  if ($patched -ne $raw) {
    $bk = BackupFile $abs $backupDir $stamp
    WriteUtf8NoBom $abs $patched
    AddLine $r ("- " + $rel)
    AddLine $r ("  - RunCmd: " + ($(if($rr1.Replaced){"OK"}else{"SKIP ("+$rr1.Why+")"})))
    AddLine $r ("  - RunNpm: " + $runNpmStatus)
    AddLine $r ("  - backup: " + $bk.Substring($root.Length+1))
  } else {
    AddLine $r ("- " + $rel + " (sem mudanca)")
  }
}

AddLine $r ""

# ---------- PATCH SANITIZE ----------
AddLine $r "## PATCH — Sanitize (.Replace char -> string)"
AddLine $r ""

if (Test-Path -LiteralPath $sanAbs) {
  $raw = Get-Content -LiteralPath $sanAbs -Raw
  $new = $raw

  # Corrige casos clássicos:
  # $s = $s.Replace($c, "")  (onde $c é [char]) => $s.Replace([string]$c, "")
  $new = [regex]::Replace($new, '\.Replace\(\s*\$c\s*,\s*""\s*\)', '.Replace([string]$c, "")')
  $new = [regex]::Replace($new, "\.Replace\(\s*\$c\s*,\s*''\s*\)", ".Replace([string]`$c, '')")

  if ($new -ne $raw) {
    $bk = BackupFile $sanAbs $backupDir $stamp
    WriteUtf8NoBom $sanAbs $new
    AddLine $r ("[OK] atualizado: " + $sanRel)
    AddLine $r ("- backup: " + $bk.Substring($root.Length+1))
  } else {
    AddLine $r "[OK] sem mudanca (pattern nao bateu ou ja estava corrigido)."
  }
} else {
  AddLine $r "[SKIP] sanitize script nao encontrado."
}

AddLine $r ""

# ---------- VERIFY ----------
AddLine $r "## VERIFY"
AddLine $r ""

if ($SkipVerify) {
  AddLine $r "[SKIP] -SkipVerify informado."
} else {
  $npm = ResolveNpmCmd
  AddLine $r ("- npm: " + $npm)

  AddLine $r ""
  AddLine $r "### npm run lint"
  try {
    $out1 = RunInCwd $npm @("run","lint") $root
    AddLine $r "```"
    AddLine $r $out1
    AddLine $r "```"
  } catch {
    AddLine $r "[ERR] lint falhou"
    AddLine $r "```"
    AddLine $r (($_ | Out-String).TrimEnd())
    AddLine $r "```"
    throw
  }

  AddLine $r ""
  AddLine $r "### npm run build"
  try {
    $out2 = RunInCwd $npm @("run","build") $root
    AddLine $r "```"
    AddLine $r $out2
    AddLine $r "```"
    AddLine $r ""
    AddLine $r "[OK] lint/build ok"
  } catch {
    AddLine $r "[ERR] build falhou"
    AddLine $r "```"
    AddLine $r (($_ | Out-String).TrimEnd())
    AddLine $r "```"
    throw
  }
}

WriteUtf8NoBom $reportPath ($r -join "`n")
Write-Host ("OK: report -> " + $reportPath)
Write-Host "DONE."