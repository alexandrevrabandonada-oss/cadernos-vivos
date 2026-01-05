param(
  [switch]$NoVerify
)

$ErrorActionPreference = 'Stop'

function EnsureDir([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

function FindRepoRoot([string]$start) {
  $cur = (Resolve-Path -LiteralPath $start).Path
  while ($true) {
    if (Test-Path -LiteralPath (Join-Path $cur 'package.json')) { return $cur }
    $parent = Split-Path -Parent $cur
    if ($parent -eq $cur -or [string]::IsNullOrWhiteSpace($parent)) { break }
    $cur = $parent
  }
  throw 'Não achei package.json. Rode na raiz do repo.'
}

function ReadUtf8([string]$p) {
  return [IO.File]::ReadAllText($p, [Text.UTF8Encoding]::new($false))
}

function WriteUtf8NoBom([string]$p, [string]$content) {
  [IO.File]::WriteAllText($p, $content, [Text.UTF8Encoding]::new($false))
}

function BackupFile([string]$filePath, [string]$backupDir) {
  EnsureDir $backupDir
  $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
  $name = Split-Path -Leaf $filePath
  $dest = Join-Path $backupDir ($ts + '-' + $name + '.bak')
  Copy-Item -LiteralPath $filePath -Destination $dest -Force
  return $dest
}

function IsWs([char]$c) {
  return ($c -eq ' ' -or $c -eq "`n" -or $c -eq "`r" -or $c -eq "`t")
}

function SkipWs([string]$s, [int]$i) {
  while ($i -lt $s.Length -and (IsWs $s[$i])) { $i++ }
  return $i
}

function ParseIdent([string]$s, [int]$i) {
  $start = $i
  while ($i -lt $s.Length) {
    $c = $s[$i]
    $ok = ([char]::IsLetterOrDigit($c) -or $c -eq '_' -or $c -eq '-' -or $c -eq ':' )
    if ($ok) { $i++ } else { break }
  }
  if ($i -le $start) { return $null }
  return @{ name=$s.Substring($start, $i-$start); i=$i }
}

function ScanQuoted([string]$s, [int]$i) {
  $q = $s[$i]
  $i++
  while ($i -lt $s.Length) {
    $c = $s[$i]
    if ($c -eq '\') { $i += 2; continue }
    if ($c -eq $q) { $i++; break }
    $i++
  }
  return $i
}

function ScanBraced([string]$s, [int]$i) {
  $depth = 0
  $inQ = [char]0
  while ($i -lt $s.Length) {
    $c = $s[$i]
    if ($inQ -ne [char]0) {
      if ($c -eq '\') { $i += 2; continue }
      if ($c -eq $inQ) { $inQ = [char]0; $i++; continue }
      $i++; continue
    }
    if ($c -eq '"' -or $c -eq "'") { $inQ = $c; $i++; continue }
    if ($c -eq '{') { $depth++; $i++; continue }
    if ($c -eq '}') {
      $depth--
      $i++
      if ($depth -le 0) { break }
      continue
    }
    $i++
  }
  return $i
}

function ExpandLeftWs([string]$s, [int]$start) {
  $k = $start
  while ($k -gt 0 -and (IsWs $s[$k-1])) { $k-- }
  return $k
}

function FindOpeningTags([string]$raw) {
  $tags = @()
  $i = 0
  while ($i -lt $raw.Length) {
    if ($raw[$i] -ne '<') { $i++; continue }
    if (($i+1) -ge $raw.Length) { break }

    $n = $raw[$i+1]
    if ($n -eq '/' -or $n -eq '!' -or $n -eq '?') { $i++; continue }
    if ($n -eq '>') { $i += 2; continue } # fragment <>

    $start = $i
    $i++
    $brace = 0
    $inQ = [char]0

    while ($i -lt $raw.Length) {
      $ch = $raw[$i]

      if ($inQ -ne [char]0) {
        if ($ch -eq '\') { $i += 2; continue }
        if ($ch -eq $inQ) { $inQ = [char]0; $i++; continue }
        $i++; continue
      }

      if ($ch -eq '"' -or $ch -eq "'") { $inQ = $ch; $i++; continue }
      if ($ch -eq '{') { $brace++; $i++; continue }
      if ($ch -eq '}') { if ($brace -gt 0) { $brace-- }; $i++; continue }

      if ($ch -eq '>' -and $brace -eq 0) {
        $end = $i + 1
        $tags += @{ start=$start; end=$end; text=$raw.Substring($start, $end-$start) }
        $i = $end
        break
      }

      $i++
    }
  }
  return $tags
}

function ParseProps([string]$tag) {
  $props = @()
  if (-not $tag.StartsWith('<')) { return $props }

  $i = 1
  $i = SkipWs $tag $i
  $tmp = ParseIdent $tag $i
  if ($null -ne $tmp) { $i = $tmp.i }

  while ($i -lt $tag.Length) {
    $i = SkipWs $tag $i
    if ($i -ge $tag.Length) { break }

    $c = $tag[$i]
    if ($c -eq '>') { break }
    if ($c -eq '/' -and ($i+1) -lt $tag.Length -and $tag[$i+1] -eq '>') { break }

    # spread {...x} -> ignora
    if ($c -eq '{') {
      $i = ScanBraced $tag $i
      continue
    }

    $segStart = $i
    $tmp2 = ParseIdent $tag $i
    if ($null -eq $tmp2) { $i++; continue }

    $name = $tmp2.name
    $i = $tmp2.i

    $j = SkipWs $tag $i
    if ($j -lt $tag.Length -and $tag[$j] -eq '=') {
      $j++
      $j = SkipWs $tag $j
      if ($j -ge $tag.Length) { break }

      $ch = $tag[$j]
      if ($ch -eq '{') {
        $j = ScanBraced $tag $j
      } elseif ($ch -eq '"' -or $ch -eq "'") {
        $j = ScanQuoted $tag $j
      } else {
        while ($j -lt $tag.Length -and -not (IsWs $tag[$j]) -and $tag[$j] -ne '>') { $j++ }
      }

      $segEnd = $j
      $segStartWs = ExpandLeftWs $tag $segStart
      $props += @{ name=$name; segStart=$segStartWs; segEnd=$segEnd }
      $i = $j
    } else {
      # boolean prop
      $segEnd2 = $i
      $segStartWs2 = ExpandLeftWs $tag $segStart
      $props += @{ name=$name; segStart=$segStartWs2; segEnd=$segEnd2 }
      $i = $j
    }
  }

  return $props
}

function FixTagKeepLast([string]$tag, [ref]$summaryOut) {
  $props = ParseProps $tag
  if ($props.Count -eq 0) { return $tag }

  $map = @{}
  foreach ($p in $props) {
    if (-not $map.ContainsKey($p.name)) { $map[$p.name] = @() }
    $map[$p.name] += $p
  }

  $dupes = @()
  foreach ($k in $map.Keys) { if ($map[$k].Count -gt 1) { $dupes += $k } }
  if ($dupes.Count -eq 0) { return $tag }

  $newTag = $tag

  foreach ($k in $dupes) {
    $items = @($map[$k] | Sort-Object segStart)
    $summaryOut.Value += @(@{ prop=$k; count=$items.Count })

    # remove earlier, keep last
    $drop = @($items | Select-Object -First ($items.Count - 1))
    foreach ($r in ($drop | Sort-Object segStart -Descending)) {
      $newTag = $newTag.Remove($r.segStart, $r.segEnd - $r.segStart)
    }
  }

  return $newTag
}

# ===== MAIN =====
$root = FindRepoRoot (Get-Location).Path
EnsureDir (Join-Path $root 'reports')
EnsureDir (Join-Path $root 'tools\_patch_backup')

$target = Join-Path $root 'src\components\v2\MapaV2Interactive.tsx'
if (-not (Test-Path -LiteralPath $target)) { throw ('Arquivo não encontrado: ' + $target) }

$raw = ReadUtf8 $target
$tags = FindOpeningTags $raw

$repls = @()
$fixed = 0
$summary = @()

foreach ($t in $tags) {
  $dups = @()
  $newTag = FixTagKeepLast $t.text ([ref]$dups)
  if ($newTag -ne $t.text) {
    $fixed++
    $repls += @{ start=$t.start; end=$t.end; new=$newTag }
    foreach ($d in $dups) { $summary += ($d.prop + ' x' + $d.count) }
  }
}

$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$reportPath = Join-Path $root ('reports\cv-step-fix-dup-props-mapa-v2-' + $ts + '.md')

$report = @()
$report += '# CV — Fix duplicate JSX props (MapaV2Interactive)'
$report += ''
$report += ('- when: ' + $ts)
$report += '- file: `src/components/v2/MapaV2Interactive.tsx`'
$report += ('- tags modified: **' + $fixed + '**')
if ($summary.Count -gt 0) { $report += ('- duplicates: ' + (($summary | Sort-Object -Unique) -join ', ')) }
$report += ''

if ($fixed -eq 0) {
  $report += '## DIAG'
  $report += '- Nenhuma prop duplicada encontrada nas tags JSX deste arquivo.'
  $report += ''
} else {
  $bk = BackupFile $target (Join-Path $root 'tools\_patch_backup')
  $report += '## BACKUP'
  $report += ('- ' + (Split-Path -Leaf $bk))
  $report += ''

  $newRaw = $raw
  foreach ($r in ($repls | Sort-Object start -Descending)) {
    $newRaw = $newRaw.Remove($r.start, $r.end-$r.start).Insert($r.start, $r.new)
  }
  WriteUtf8NoBom $target $newRaw

  $report += '## PATCH'
  $report += ('- replacements: ' + $repls.Count)
  $report += ''
}

$verifyExit = 0
if (-not $NoVerify) {
  $verify = Join-Path $root 'tools\cv-verify.ps1'
  $report += '## VERIFY'
  if (Test-Path -LiteralPath $verify) {
    $out = (& pwsh -NoProfile -ExecutionPolicy Bypass -File $verify 2>&1 | Out-String)
    $verifyExit = $LASTEXITCODE
    $report += ('- exit: **' + $verifyExit + '**')
    $report += ''
    $report += '```'
    $report += $out.TrimEnd()
    $report += '```'
  } else {
    $report += '- tools/cv-verify.ps1 não encontrado (pulando)'
  }
  $report += ''
}

$report += '## NEXT'
if ($verifyExit -eq 0) {
  $report += '- ✅ Tudo verde. Próximo passo: commit deste bloco e seguimos para Contrato de dados + Zod + fallbacks.'
} else {
  $report += '- ⚠️ Ainda há erros no verify. Agora sem o bloqueio de props duplicadas (se era isso).'
}

WriteUtf8NoBom $reportPath ($report -join "`n")
Write-Host ('[OK] Report -> ' + $reportPath)