# tools/cv-hotfix-b7x2-runner-meta-sanitize-v0_1.ps1
# CV — Hotfix unificado:
# A) Fix meta undefined no /v2/mapa (meta={meta} -> meta={undefined as any})
# B) Reescreve RunCmd/RunNpm (robusto) em scripts B7I/B7N (para não cair no npm Usage)
# C) Corrige bug do sanitize script (Replace(char,"") -> Replace([string]char,""))
# D) (opcional) Clean .next e roda npm run lint/build
#
# Uso:
#   pwsh -NoProfile -ExecutionPolicy Bypass -File tools\cv-hotfix-b7x2-runner-meta-sanitize-v0_1.ps1 -CleanNext
#   pwsh -NoProfile -ExecutionPolicy Bypass -File tools\cv-hotfix-b7x2-runner-meta-sanitize-v0_1.ps1 -SkipVerify

param(
  [switch]$SkipVerify,
  [switch]$CleanNext
)

$ErrorActionPreference = 'Stop'

function NewUtf8NoBomEncoding() { New-Object System.Text.UTF8Encoding($false) }
function EnsureDir([string]$p) { if (-not (Test-Path -LiteralPath $p)) { [IO.Directory]::CreateDirectory($p) | Out-Null } }
function WriteUtf8NoBom([string]$path, [string]$content) { [IO.File]::WriteAllText($path, $content, (NewUtf8NoBomEncoding)) }
function AddLine([System.Collections.Generic.List[string]]$r, [string]$s='') { $r.Add($s) | Out-Null }

function BackupFile([string]$absPath, [string]$backupRoot, [string]$stamp) {
  EnsureDir $backupRoot
  $dir = Join-Path $backupRoot $stamp
  EnsureDir $dir
  $name = Split-Path -Leaf $absPath
  $dst  = Join-Path $dir ($name + '.' + $stamp + '.bak')
  Copy-Item -LiteralPath $absPath -Destination $dst -Force
  return $dst
}

function ResolveNpmCmd() {
  $c = Get-Command npm.cmd -ErrorAction SilentlyContinue
  if ($c -and (Test-Path -LiteralPath $c.Source)) { return $c.Source }

  $fallback = Join-Path ${env:ProgramFiles} 'nodejs\npm.cmd'
  if (Test-Path -LiteralPath $fallback) { return $fallback }

  $c2 = Get-Command npm -ErrorAction SilentlyContinue
  if ($c2 -and (Test-Path -LiteralPath $c2.Source)) { return $c2.Source }

  throw 'Nao consegui localizar npm.cmd (nem fallback em ProgramFiles\nodejs\npm.cmd).'
}

function RunNpmRobust {
  param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [object[]]$all
  )

  if (-not $all -or $all.Count -lt 1) { throw 'RunNpmRobust: faltou args (ex: "run" "lint").' }

  $cwd = $null
  $argsList = New-Object System.Collections.Generic.List[string]

  foreach ($x in $all) {
    if (-not $cwd -and $x -is [string]) {
      $s = [string]$x
      if (Test-Path -LiteralPath $s -PathType Container) {
        $pj = Join-Path $s 'package.json'
        if (Test-Path -LiteralPath $pj) { $cwd = $s; continue }
      }
    }

    if ($x -is [string[]]) {
      foreach ($y in $x) { if ($y -ne $null -and ([string]$y) -ne '') { $argsList.Add([string]$y) | Out-Null } }
    } elseif ($x -is [System.Collections.IEnumerable] -and -not ($x -is [string])) {
      foreach ($y in $x) { if ($y -ne $null -and ([string]$y) -ne '') { $argsList.Add([string]$y) | Out-Null } }
    } else {
      if ($x -ne $null -and ([string]$x) -ne '') { $argsList.Add([string]$x) | Out-Null }
    }
  }

  if (-not $cwd) { $cwd = (Resolve-Path '.').Path }
  $npm = ResolveNpmCmd
  $cmdArgs = @($argsList.ToArray())

  if (-not $cmdArgs -or $cmdArgs.Count -lt 1) { throw 'RunNpmRobust: args vazios (isso vira npm Usage).' }

  $old = Get-Location
  try {
    Set-Location $cwd
    Write-Host ('[RUN] ' + $npm + ' ' + ($cmdArgs -join ' '))
    $out = & $npm @cmdArgs 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw ('Command failed: npm ' + ($cmdArgs -join ' ') + "`n" + $out) }
    return $out.TrimEnd()
  } finally {
    Set-Location $old
  }
}

function ExtractBraceBlock([string]$text, [int]$startIdx) {
  $open = $text.IndexOf('{', $startIdx)
  if ($open -lt 0) { return $null }
  $depth = 0
  for ($i=$open; $i -lt $text.Length; $i++) {
    $ch = $text[$i]
    if ($ch -eq '{') { $depth++ }
    elseif ($ch -eq '}') {
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
  if (-not $m.Success) { return [pscustomobject]@{ Text=$text; Replaced=$false; Why='not-found' } }
  $start = $m.Index
  $blk = ExtractBraceBlock $text $start
  if (-not $blk) { return [pscustomobject]@{ Text=$text; Replaced=$false; Why='no-brace-block' } }
  $end = $blk.Close
  $newText = $text.Substring(0, $start) + $newFuncText + $text.Substring($end+1)
  return [pscustomobject]@{ Text=$newText; Replaced=$true; Why='ok' }
}

function UpsertRobustRunner([string]$absPath, [System.Collections.Generic.List[string]]$r, [string]$relPath) {
  if (-not (Test-Path -LiteralPath $absPath)) {
    AddLine $r ('[SKIP] nao achei: ' + $relPath)
    return
  }

  $raw = Get-Content -LiteralPath $absPath -Raw

  $newRunCmd = @(
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
'      foreach ($y in $x) { if ($y -ne $null -and ([string]$y) -ne "") { $argsList.Add([string]$y) | Out-Null } }'
'    } elseif ($x -is [System.Collections.IEnumerable] -and -not ($x -is [string])) {'
'      foreach ($y in $x) { if ($y -ne $null -and ([string]$y) -ne "") { $argsList.Add([string]$y) | Out-Null } }'
'    } else {'
'      if ($x -ne $null -and ([string]$x) -ne "") { $argsList.Add([string]$x) | Out-Null }'
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
) -join "`n"

  $newRunNpm = @(
'function RunNpm {'
'  param('
'    [Parameter(ValueFromRemainingArguments=$true)]'
'    [object[]]$all'
'  )'
'  $npm = $null'
'  $c1 = Get-Command npm.cmd -ErrorAction SilentlyContinue'
'  if ($c1 -and (Test-Path -LiteralPath $c1.Source)) { $npm = $c1.Source }'
'  if (-not $npm) {'
'    $fallback = Join-Path ${env:ProgramFiles} "nodejs\npm.cmd"'
'    if (Test-Path -LiteralPath $fallback) { $npm = $fallback }'
'  }'
'  if (-not $npm) {'
'    $c2 = Get-Command npm -ErrorAction SilentlyContinue'
'    if ($c2 -and (Test-Path -LiteralPath $c2.Source)) { $npm = $c2.Source }'
'  }'
'  if (-not $npm) { throw "Nao consegui localizar npm(.cmd)." }'
'  $pass = @($npm) + $all'
'  return (RunCmd @pass)'
'}'
) -join "`n"

  $patched = $raw

  $rr1 = ReplaceFunctionBlock $patched 'RunCmd' ($newRunCmd + "`n")
  $patched = $rr1.Text
  $rr2 = ReplaceFunctionBlock $patched 'RunNpm' ($newRunNpm + "`n")
  $patched = $rr2.Text

  if ($patched -ne $raw) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $bkRoot = Join-Path (Resolve-Path '.').Path 'tools\_patch_backup'
    $bk = BackupFile $absPath $bkRoot $stamp
    WriteUtf8NoBom $absPath $patched
    AddLine $r ('[OK] runner robusto aplicado: ' + $relPath)
    AddLine $r ('- backup: ' + $bk)
  } else {
    AddLine $r ('[WARN] nao consegui substituir RunCmd/RunNpm em: ' + $relPath + ' (talvez nao existam ou formato diferente).')
  }
}

# -------------------------
# Main
# -------------------------
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$root = (Resolve-Path '.').Path

if (-not (Test-Path -LiteralPath (Join-Path $root 'package.json'))) {
  throw ('Rode na raiz do repo (package.json). Root atual: ' + $root)
}

$reportsDir = Join-Path $root 'reports'
$backupDir  = Join-Path $root 'tools\_patch_backup'
EnsureDir $reportsDir
EnsureDir $backupDir

$reportPath = Join-Path $reportsDir ($stamp + '-cv-hotfix-b7x2-runner-meta-sanitize.md')
$r = New-Object System.Collections.Generic.List[string]

AddLine $r '# CV HOTFIX B7X2 — Runner + meta + sanitize'
AddLine $r ''
AddLine $r ('- Stamp: ' + $stamp)
AddLine $r ('- Root: ' + $root)
AddLine $r ''

if ($CleanNext) {
  $nextDir = Join-Path $root '.next'
  AddLine $r '## CLEAN'
  AddLine $r ''
  if (Test-Path -LiteralPath $nextDir) {
    Remove-Item -LiteralPath $nextDir -Recurse -Force -ErrorAction SilentlyContinue
    AddLine $r '[OK] removido .next'
  } else {
    AddLine $r '[OK] .next nao existe'
  }
  AddLine $r ''
}

# A) meta undefined fix
AddLine $r '## PATCH A — meta undefined (/v2/mapa)'
AddLine $r ''
$mapRel = 'src\app\c\[slug]\v2\mapa\page.tsx'
$mapAbs = Join-Path $root $mapRel

if (-not (Test-Path -LiteralPath $mapAbs)) {
  AddLine $r ('[SKIP] nao achei: ' + $mapRel)
} else {
  $rawMap = Get-Content -LiteralPath $mapAbs -Raw
  $newMap = [regex]::Replace($rawMap, '\bmeta\s*=\s*\{\s*meta\s*\}', 'meta={undefined as any}')
  if ($newMap -ne $rawMap) {
    $bk = BackupFile $mapAbs $backupDir $stamp
    WriteUtf8NoBom $mapAbs $newMap
    AddLine $r '[OK] troquei meta={meta} -> meta={undefined as any}'
    AddLine $r ('- backup: ' + $bk)
  } else {
    AddLine $r '[OK] sem mudanca (nao achei meta={meta}).'
  }
}
AddLine $r ''

# B) runner robusto nos scripts que costumam quebrar
AddLine $r '## PATCH B — runner robusto (B7I/B7N)'
AddLine $r ''
UpsertRobustRunner (Join-Path $root 'tools\cv-step-b7i-portals-curated-everywhere-v0_1.ps1') $r 'tools\cv-step-b7i-portals-curated-everywhere-v0_1.ps1'
UpsertRobustRunner (Join-Path $root 'tools\cv-step-b7n-map-core-highlights-v0_2.ps1')        $r 'tools\cv-step-b7n-map-core-highlights-v0_2.ps1'
UpsertRobustRunner (Join-Path $root 'tools\cv-step-b7n-map-core-highlights-v0_1.ps1')        $r 'tools\cv-step-b7n-map-core-highlights-v0_1.ps1'
AddLine $r ''

# C) sanitize script bug fix
AddLine $r '## PATCH C — sanitize script (Replace char -> string)'
AddLine $r ''
$sanRel = 'tools\cv-hotfix-b7o3-core-highlights-sanitize-inject.ps1'
$sanAbs = Join-Path $root $sanRel

if (-not (Test-Path -LiteralPath $sanAbs)) {
  AddLine $r ('[SKIP] nao achei: ' + $sanRel)
} else {
  $sanRaw = Get-Content -LiteralPath $sanAbs -Raw
  $sanNew = $sanRaw
  $sanNew = [regex]::Replace($sanNew, '\.Replace\(\s*\$c\s*,\s*""\s*\)', '.Replace([string]$c, "")')
  $sanNew = [regex]::Replace($sanNew, "\.Replace\(\s*\$c\s*,\s*''\s*\)", ".Replace([string]`$c, '')")
  if ($sanNew -ne $sanRaw) {
    $bk = BackupFile $sanAbs $backupDir $stamp
    WriteUtf8NoBom $sanAbs $sanNew
    AddLine $r '[OK] corrigi Replace($c,"") para Replace([string]$c,"")'
    AddLine $r ('- backup: ' + $bk)
  } else {
    AddLine $r '[OK] sem mudanca (nao achei padrao .Replace($c,"")).'
  }
}
AddLine $r ''

# VERIFY
AddLine $r '## VERIFY'
AddLine $r ''

if ($SkipVerify) {
  AddLine $r '[SKIP] -SkipVerify informado.'
} else {
  try {
    AddLine $r '[RUN] npm run lint'
    AddLine $r '```'
    AddLine $r (RunNpmRobust 'run' 'lint' $root)
    AddLine $r '```'
    AddLine $r ''

    AddLine $r '[RUN] npm run build'
    AddLine $r '```'
    AddLine $r (RunNpmRobust 'run' 'build' $root)
    AddLine $r '```'
    AddLine $r ''
    AddLine $r '[OK] lint/build ok'
  } catch {
    AddLine $r ('[ERR] verify falhou: ' + $_.Exception.Message)
    AddLine $r ''
    AddLine $r '```'
    AddLine $r (($_ | Out-String).TrimEnd())
    AddLine $r '```'
    AddLine $r ''
    throw
  }
}

WriteUtf8NoBom $reportPath ($r -join "`n")
Write-Host ('OK: report -> ' + $reportPath)
Write-Host 'DONE.'