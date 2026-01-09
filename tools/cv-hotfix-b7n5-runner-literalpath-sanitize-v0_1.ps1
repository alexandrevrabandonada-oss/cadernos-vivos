# tools/cv-hotfix-b7n5-runner-literalpath-sanitize-v0_1.ps1
# Patch nos B7N: runner robusto + LiteralPath + sanitize Replace(char,string)
# DIAG -> PATCH -> VERIFY -> REPORT

param(
  [switch]$SkipVerify
)

$ErrorActionPreference = "Stop"

function NewUtf8NoBomEncoding() { New-Object System.Text.UTF8Encoding($false) }
function EnsureDir([string]$p) { if (-not (Test-Path -LiteralPath $p)) { [IO.Directory]::CreateDirectory($p) | Out-Null } }
function WriteUtf8NoBom([string]$path, [string]$content) { [IO.File]::WriteAllText($path, $content, (NewUtf8NoBomEncoding)) }

function BackupFile([string]$absPath, [string]$backupRoot, [string]$stamp) {
  EnsureDir $backupRoot
  $dir = Join-Path $backupRoot $stamp
  EnsureDir $dir
  $name = Split-Path -Leaf $absPath
  $dst  = Join-Path $dir ($name + "." + $stamp + ".bak")
  Copy-Item -LiteralPath $absPath -Destination $dst -Force
  return $dst
}

function AddLine([System.Collections.Generic.List[string]]$r, [string]$s="") { $r.Add($s) | Out-Null }

function FindNpmCmd {
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

function ExtractFunctionRange([string]$text, [string]$funcName) {
  $m = [regex]::Match($text, "(?ms)^\s*function\s+$funcName\b")
  if (-not $m.Success) { return $null }

  $start = $m.Index
  $open  = $text.IndexOf("{", $start)
  if ($open -lt 0) { return $null }

  $depth = 0
  for ($i=$open; $i -lt $text.Length; $i++) {
    $ch = $text[$i]
    if ($ch -eq "{") { $depth++ }
    elseif ($ch -eq "}") {
      $depth--
      if ($depth -eq 0) {
        return [pscustomobject]@{ Start=$start; Open=$open; End=$i; Block=$text.Substring($start, ($i-$start+1)) }
      }
    }
  }
  return $null
}

function ReplaceOrInsertRunner([string]$raw, [string]$runCmdText, [string]$runNpmText, [ref]$notes) {
  $txt = $raw
  $changed = $false

  $rngCmd = ExtractFunctionRange $txt "RunCmd"
  if ($rngCmd) {
    $txt = $txt.Substring(0, $rngCmd.Start) + $runCmdText + $txt.Substring($rngCmd.End + 1)
    $notes.Value.Add("RunCmd: replaced") | Out-Null
    $changed = $true
  } else {
    $notes.Value.Add("RunCmd: not-found") | Out-Null
  }

  $rngNpm = ExtractFunctionRange $txt "RunNpm"
  if ($rngNpm) {
    $txt = $txt.Substring(0, $rngNpm.Start) + $runNpmText + $txt.Substring($rngNpm.End + 1)
    $notes.Value.Add("RunNpm: replaced") | Out-Null
    $changed = $true
  } else {
    $notes.Value.Add("RunNpm: not-found") | Out-Null
  }

  # Se script usa RunNpm/RunCmd mas não tinha função, injeta antes do primeiro bloco DIAG/linha separadora
  $usesRun = ($txt -match "\bRunNpm\b") -or ($txt -match "\bRunCmd\b")
  $hasCmd  = ($txt -match "(?m)^\s*function\s+RunCmd\b")
  $hasNpm  = ($txt -match "(?m)^\s*function\s+RunNpm\b")

  if ($usesRun -and (-not $hasCmd -or -not $hasNpm)) {
    $lines = $txt -split "`r?`n"
    $ins = -1
    for ($i=0; $i -lt $lines.Length; $i++) {
      $ln = $lines[$i]
      if ($ln -match "^\s*#\s*-{5,}" -or $ln -match "^\s*#\s*DIAG" -or $ln -match "^\s*##\s*DIAG") { $ins = $i; break }
    }
    if ($ins -lt 0) { $ins = [Math]::Min(40, $lines.Length) }

    $inject = @()
    if (-not $hasCmd) { $inject += $runCmdText }
    if (-not $hasNpm) { $inject += $runNpmText }
    $inject += ""

    $before = @()
    if ($ins -gt 0) { $before = $lines[0..($ins-1)] }
    $after  = $lines[$ins..($lines.Length-1)]

    $txt = (($before + $inject + $after) -join "`n")
    $notes.Value.Add("Runner: injected") | Out-Null
    $changed = $true
  }

  return [pscustomobject]@{ Text=$txt; Changed=$changed }
}

function LiteralPathSafety([string]$txt, [ref]$notes) {
  $out = $txt

  # 1) Test-Path sem -LiteralPath/-Path => vira -LiteralPath
  $before = $out
  $out = [regex]::Replace($out, '(?m)\bTest-Path\s+(?!-LiteralPath\b|-Path\b)', 'Test-Path -LiteralPath ')
  if ($out -ne $before) { $notes.Value.Add("Test-Path: literalized") | Out-Null }

  # 2) Get-Content -Raw $x  => Get-Content -LiteralPath $x -Raw
  $before = $out
  $out = [regex]::Replace($out, '(?m)\bGet-Content\s+-Raw\s+(\$[A-Za-z_]\w*)', 'Get-Content -LiteralPath $1 -Raw')
  if ($out -ne $before) { $notes.Value.Add("Get-Content: literalized -Raw") | Out-Null }

  # 3) Cmdlets comuns: -Path -> -LiteralPath
  $before = $out
  $out = [regex]::Replace($out, '(?m)\b(Get-Content|Set-Content|Add-Content|Copy-Item|Move-Item|Remove-Item|Get-Item)\s+-Path\b', '$1 -LiteralPath')
  if ($out -ne $before) { $notes.Value.Add("Cmdlets: -Path -> -LiteralPath") | Out-Null }

  return $out
}

function FixSanitizeReplace([string]$txt, [ref]$notes) {
  $out = $txt
  $before = $out
  # .Replace($c,"") ou .Replace($c, "") => .Replace([string]$c, "")
  $out = [regex]::Replace($out, '(?m)\.Replace\(\s*\$c\s*,\s*""\s*\)', '.Replace([string]$c, "")')
  $out = [regex]::Replace($out, '(?m)\.Replace\(\s*\$c\s*,\s*""""\s*\)', '.Replace([string]$c, "")')
  if ($out -ne $before) { $notes.Value.Add("Sanitize: Replace(char,string) fixed") | Out-Null }
  return $out
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$root  = (Resolve-Path ".").Path

if (-not (Test-Path -LiteralPath (Join-Path $root "package.json"))) {
  throw ("Rode na raiz do repo (package.json). Root atual: " + $root)
}

$reportsDir = Join-Path $root "reports"
$backupDir  = Join-Path $root "tools\_patch_backup"
EnsureDir $reportsDir
EnsureDir $backupDir

$reportPath = Join-Path $reportsDir ($stamp + "-cv-hotfix-b7n5-runner-literalpath-sanitize.md")
$r = New-Object System.Collections.Generic.List[string]

AddLine $r "# CV HOTFIX B7N5 — runner + literalpath + sanitize"
AddLine $r ""
AddLine $r ("- Stamp: " + $stamp)
AddLine $r ("- Root: " + $root)
AddLine $r ""

# Runner robusto (sem here-string @' interno)
$runCmdLines = @(
'function RunCmd {'
'  param('
'    [Parameter(ValueFromRemainingArguments=$true)]'
'    [object[]]$all'
'  )'
'  if (-not $all -or $all.Count -lt 1) { throw "RunCmd: missing cmd" }'
'  $cmd = [string]$all[0]'
'  $rest = @()'
'  if ($all.Count -gt 1) { $rest = $all[1..($all.Count-1)] }'
'  $cwd = $null'
'  $argsList = New-Object System.Collections.Generic.List[string]'
'  foreach ($x in $rest) {'
'    if (-not $cwd -and $x -is [string]) {'
'      $s = [string]$x'
'      if (Test-Path -LiteralPath $s -PathType Container) {'
'        $pj = Join-Path $s "package.json"'
'        if (Test-Path -LiteralPath $pj) { $cwd = $s; continue }'
'      }'
'    }'
'    if ($x -is [string[]]) {'
'      foreach ($y in $x) { if ($y -ne $null -and [string]$y -ne "") { $argsList.Add([string]$y) | Out-Null } }'
'    } elseif ($x -is [System.Collections.IEnumerable] -and -not ($x -is [string])) {'
'      foreach ($y in $x) { if ($y -ne $null -and [string]$y -ne "") { $argsList.Add([string]$y) | Out-Null } }'
'    } else {'
'      if ($x -ne $null -and [string]$x -ne "") { $argsList.Add([string]$x) | Out-Null }'
'    }'
'  }'
'  if (-not $cwd) { $cwd = (Resolve-Path ".").Path }'
'  $cmdArgs = @($argsList.ToArray())'
'  $old = Get-Location'
'  try {'
'    Set-Location $cwd'
'    Write-Host ("[RUN] " + $cmd + ($(if($cmdArgs.Count -gt 0){ " " + ($cmdArgs -join " ") } else { "" })))'
'    $out = & $cmd @cmdArgs 2>&1 | Out-String'
'    if ($LASTEXITCODE -ne 0) { throw ("Command failed: " + $cmd + " " + ($cmdArgs -join " ") + "`n" + $out) }'
'    return $out.TrimEnd()'
'  } finally {'
'    Set-Location $old'
'  }'
'}'
)
$runCmdText = ($runCmdLines -join "`n")

$runNpmLines = @(
'function RunNpm {'
'  param('
'    [Parameter(ValueFromRemainingArguments=$true)]'
'    [object[]]$all'
'  )'
'  $npm = $null'
'  $c1 = Get-Command npm.cmd -ErrorAction SilentlyContinue'
'  if ($c1 -and (Test-Path -LiteralPath $c1.Source)) { $npm = $c1.Source }'
'  if (-not $npm) {'
'    $c2 = Get-Command npm -ErrorAction SilentlyContinue'
'    if ($c2 -and (Test-Path -LiteralPath $c2.Source)) {'
'      if ($c2.Source.ToLower().EndsWith(".ps1")) {'
'        $try = [IO.Path]::ChangeExtension($c2.Source, ".cmd")'
'        if (Test-Path -LiteralPath $try) { $npm = $try } else { $npm = $c2.Source }'
'      } else {'
'        $npm = $c2.Source'
'      }'
'    }'
'  }'
'  if (-not $npm) {'
'    $fallback = Join-Path ${env:ProgramFiles} "nodejs\npm.cmd"'
'    if (Test-Path -LiteralPath $fallback) { $npm = $fallback }'
'  }'
'  if (-not $npm) { throw "Nao consegui localizar npm(.cmd)." }'
'  $pass = @($npm) + $all'
'  return (RunCmd @pass)'
'}'
)
$runNpmText = ($runNpmLines -join "`n")

# Targets
$targets = @(
  "tools\cv-step-b7n-map-core-highlights-v0_1.ps1",
  "tools\cv-step-b7n-map-core-highlights-v0_2.ps1",
  "tools\cv-hotfix-b7o3-core-highlights-sanitize-inject.ps1",
  "tools\cv-hotfix-b7o4-fix-sanitize-script-and-verify-v0_2.ps1",
  "tools\cv-hotfix-b7o4-fix-sanitize-script-and-verify-v0_3.ps1"
) | Select-Object -Unique

AddLine $r "## DIAG"
AddLine $r ""
foreach ($rel in $targets) {
  $abs = Join-Path $root $rel
  AddLine $r ("- " + $rel + ": " + (Test-Path -LiteralPath $abs))
}
AddLine $r ""

AddLine $r "## PATCH"
AddLine $r ""

foreach ($rel in $targets) {
  $abs = Join-Path $root $rel
  if (-not (Test-Path -LiteralPath $abs)) { continue }

  $notes = New-Object System.Collections.Generic.List[string]
  $raw = Get-Content -LiteralPath $abs -Raw
  $new = $raw

  # runner
  $rr = ReplaceOrInsertRunner $new $runCmdText $runNpmText ([ref]$notes)
  $new = $rr.Text

  # literal path safety (principalmente B7N)
  if ($rel -like "tools\cv-step-b7n*") {
    $new = LiteralPathSafety $new ([ref]$notes)
  }

  # sanitize fix
  $new = FixSanitizeReplace $new ([ref]$notes)

  if ($new -ne $raw) {
    $bk = BackupFile $abs $backupDir $stamp
    WriteUtf8NoBom $abs $new
    AddLine $r ("[OK] patched: " + $rel)
    AddLine $r ("- backup: " + $bk.Substring($root.Length+1))
    AddLine $r ("- notes: " + ($notes -join "; "))
    AddLine $r ""
  } else {
    AddLine $r ("[OK] no-change: " + $rel)
    if ($notes.Count -gt 0) { AddLine $r ("- notes: " + ($notes -join "; ")) }
    AddLine $r ""
  }
}

AddLine $r "## VERIFY"
AddLine $r ""

if ($SkipVerify) {
  AddLine $r "[SKIP] -SkipVerify informado."
} else {
  $npm = FindNpmCmd
  $old = Get-Location
  try {
    Set-Location $root
    AddLine $r "[RUN] npm run lint"
    $o1 = & $npm @("run","lint") 2>&1 | Out-String
    AddLine $r '```'
    AddLine $r ($o1.TrimEnd())
    AddLine $r '```'
    AddLine $r ""

    AddLine $r "[RUN] npm run build"
    $o2 = & $npm @("run","build") 2>&1 | Out-String
    AddLine $r '```'
    AddLine $r ($o2.TrimEnd())
    AddLine $r '```'
    AddLine $r ""

    AddLine $r "[OK] lint/build ok"
  } finally {
    Set-Location $old
  }
}

WriteUtf8NoBom $reportPath ($r -join "`n")
Write-Host ("OK: report -> " + $reportPath)