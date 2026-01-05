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
  throw ('Não achei package.json subindo a partir de: ' + $start + '. Rode na raiz do repo.')
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

function SkipWs([string]$s, [ref]$i) {
  while ($i.Value -lt $s.Length -and (IsWs $s[$i.Value])) { $i.Value++ }
}

function ParseIdent([string]$s, [ref]$i) {
  $start = $i.Value
  while ($i.Value -lt $s.Length) {
    $c = $s[$i.Value]
    $ok = ([char]::IsLetterOrDigit($c) -or $c -eq '_' -or $c -eq '-' -or $c -eq ':' )
    if ($ok) { $i.Value++ } else { break }
  }
  if ($i.Value -le $start) { return $null }
  return $s.Substring($start, $i.Value - $start)
}

function ParseQuoted([string]$s, [ref]$i) {
  $q = $s[$i.Value]
  $start = $i.Value
  $i.Value++ # skip opening
  while ($i.Value -lt $s.Length) {
    $c = $s[$i.Value]
    if ($c -eq '\') { $i.Value += 2; continue }
    if ($c -eq $q) { $i.Value++; break }
    $i.Value++
  }
  $end = $i.Value
  return @{ kind='string'; start=$start; end=$end; text=$s.Substring($start, $end-$start) }
}

function ParseBraced([string]$s, [ref]$i) {
  $start = $i.Value
  $depth = 0
  $inQ = [char]0
  while ($i.Value -lt $s.Length) {
    $c = $s[$i.Value]
    if ($inQ -ne [char]0) {
      if ($c -eq '\') { $i.Value += 2; continue }
      if ($c -eq $inQ) { $inQ = [char]0; $i.Value++; continue }
      $i.Value++; continue
    }

    if ($c -eq '"' -or $c -eq "'") { $inQ = $c; $i.Value++; continue }
    if ($c -eq '{') { $depth++; $i.Value++; continue }
    if ($c -eq '}') {
      $depth--
      $i.Value++
      if ($depth -le 0) { break }
      continue
    }
    $i.Value++
  }
  $end = $i.Value
  $txt = $s.Substring($start, $end-$start) # includes outer braces
  $inner = $txt
  if ($inner.StartsWith('{') -and $inner.EndsWith('}')) { $inner = $inner.Substring(1, $inner.Length-2) }
  return @{ kind='brace'; start=$start; end=$end; text=$txt; inner=$inner }
}

function ParseAttrValue([string]$s, [ref]$i) {
  SkipWs $s ([ref]$i)
  if ($i.Value -ge $s.Length) { return $null }
  $c = $s[$i.Value]
  if ($c -eq '{') { return ParseBraced $s ([ref]$i) }
  if ($c -eq '"' -or $c -eq "'") { return ParseQuoted $s ([ref]$i) }

  # bare token until whitespace or end tag-ish
  $start = $i.Value
  while ($i.Value -lt $s.Length) {
    $ch = $s[$i.Value]
    if (IsWs $ch -or $ch -eq '>' ) { break }
    $i.Value++
  }
  $end = $i.Value
  return @{ kind='bare'; start=$start; end=$end; text=$s.Substring($start, $end-$start) }
}

function ExpandLeftWs([string]$s, [int]$start) {
  $k = $start
  while ($k -gt 0) {
    $prev = $s[$k-1]
    if (IsWs $prev) { $k-- } else { break }
  }
  return $k
}

function ParseOpeningTagProps([string]$tag) {
  $props = @()
  if (-not $tag.StartsWith('<')) { return $props }

  $i = 1
  SkipWs $tag ([ref]$i)
  $tagName = ParseIdent $tag ([ref]$i)
  if (-not $tagName) { $tagName = '' }

  while ($i -lt $tag.Length) {
    SkipWs $tag ([ref]$i)
    if ($i -ge $tag.Length) { break }

    $c = $tag[$i]
    if ($c -eq '>') { break }
    if ($c -eq '/' -and ($i+1) -lt $tag.Length -and $tag[$i+1] -eq '>') { break }

    # spread like {...x}
    if ($c -eq '{') {
      $spread = ParseBraced $tag ([ref]$i)
      $props += @{ name='(spread)'; segStart=$spread.start; segEnd=$spread.end; value=$spread; tagName=$tagName }
      continue
    }

    $segStart = $i
    $name = ParseIdent $tag ([ref]$i)
    if (-not $name) { $i++; continue }

    $j = $i
    SkipWs $tag ([ref]$j)
    if ($j -lt $tag.Length -and $tag[$j] -eq '=') {
      $j++
      $i = $j
      $val = ParseAttrValue $tag ([ref]$i)
      if (-not $val) { continue }
      $segEnd = $i
      $props += @{ name=$name; segStart=$segStart; segEnd=$segEnd; value=$val; tagName=$tagName }
    } else {
      # boolean prop
      $props += @{ name=$name; segStart=$segStart; segEnd=$i; value=$null; tagName=$tagName }
      $i = $j
    }
  }

  return $props
}

function FixDuplicatePropsInTag([string]$tag, [ref]$changesOut) {
  $props = ParseOpeningTagProps $tag
  $byName = @{}
  foreach ($p in $props) {
    if ($p.name -eq '(spread)') { continue }
    if (-not $byName.ContainsKey($p.name)) { $byName[$p.name] = @() }
    $byName[$p.name] += $p
  }

  $dupes = @()
  foreach ($k in $byName.Keys) {
    if ($byName[$k].Count -gt 1) { $dupes += $k }
  }
  if ($dupes.Count -eq 0) { return $tag }

  $newTag = $tag

  foreach ($propName in $dupes) {
    $items = @($byName[$propName] | Sort-Object segStart)
    if ($items.Count -lt 2) { continue }

    $changesOut.Value += @(@{ prop=$propName; count=$items.Count })

    if ($propName -eq 'style') {
      # Merge style={{...}} + style={{...}} -> style={{ ...(A||{}), ...(B||{}) }}
      $inners = @()
      foreach ($it in $items) {
        if ($null -eq $it.value) { continue }
        if ($it.value.kind -eq 'brace') {
          $inner = ($it.value.inner).Trim()
          if ($inner.Length -gt 0) { $inners += ('((' + $inner + ') || {})') }
        } else {
          # fallback
          $inners += '({})'
        }
      }
      if ($inners.Count -ge 2) {
        $merged = 'style={{ ' + (($inners | ForEach-Object { '...(' + $_ + ')' }) -join ', ') + ' }}'

        $first = $items[0]
        $toRemove = @($items | Select-Object -Skip 1)

        foreach ($r in ($toRemove | Sort-Object segStart -Descending)) {
          $rs = ExpandLeftWs $newTag $r.segStart
          $newTag = $newTag.Remove($rs, $r.segEnd - $rs)
        }

        $fs = ExpandLeftWs $newTag $first.segStart
        $newTag = $newTag.Remove($fs, $first.segEnd - $fs).Insert($fs, ' ' + $merged)
      } else {
        # can't merge, keep last
        $keep = $items[-1]
        $drop = @($items | Select-Object -First ($items.Count - 1))
        foreach ($r in ($drop | Sort-Object segStart -Descending)) {
          $rs = ExpandLeftWs $newTag $r.segStart
          $newTag = $newTag.Remove($rs, $r.segEnd - $rs)
        }
      }
      continue
    }

    if ($propName -eq 'className') {
      $vals = @()
      foreach ($it in $items) {
        if ($null -eq $it.value) { continue }
        if ($it.value.kind -eq 'string') {
          $vals += $it.value.text
        } elseif ($it.value.kind -eq 'brace') {
          $inner = ($it.value.inner).Trim()
          if ($inner.Length -gt 0) { $vals += ('(' + $inner + ')') }
        } else {
          $vals += $it.value.text
        }
      }
      if ($vals.Count -ge 2) {
        $merged = 'className={[' + ($vals -join ', ') + '].filter(Boolean).join(" ")}'

        $first = $items[0]
        $toRemove = @($items | Select-Object -Skip 1)

        foreach ($r in ($toRemove | Sort-Object segStart -Descending)) {
          $rs = ExpandLeftWs $newTag $r.segStart
          $newTag = $newTag.Remove($rs, $r.segEnd - $rs)
        }

        $fs = ExpandLeftWs $newTag $first.segStart
        $newTag = $newTag.Remove($fs, $first.segEnd - $fs).Insert($fs, ' ' + $merged)
      } else {
        # keep last
        $keep = $items[-1]
        $drop = @($items | Select-Object -First ($items.Count - 1))
        foreach ($r in ($drop | Sort-Object segStart -Descending)) {
          $rs = ExpandLeftWs $newTag $r.segStart
          $newTag = $newTag.Remove($rs, $r.segEnd - $rs)
        }
      }
      continue
    }

    # default: keep last, drop earlier
    $drop = @($items | Select-Object -First ($items.Count - 1))
    foreach ($r in ($drop | Sort-Object segStart -Descending)) {
      $rs = ExpandLeftWs $newTag $r.segStart
      $newTag = $newTag.Remove($rs, $r.segEnd - $rs)
    }
  }

  return $newTag
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
    $i++ # after '<'
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

# ===== main =====
$root = FindRepoRoot (Get-Location).Path
EnsureDir (Join-Path $root 'reports')
EnsureDir (Join-Path $root 'tools\_patch_backup')

$target = Join-Path $root 'src\components\v2\MapaV2Interactive.tsx'
if (-not (Test-Path -LiteralPath $target)) { throw ('Arquivo não encontrado: ' + $target) }

$raw = ReadUtf8 $target
$tags = FindOpeningTags $raw

$repls = @()
$fixed = 0
$changeLog = @()

foreach ($t in $tags) {
  $changes = @()
  $newTag = FixDuplicatePropsInTag $t.text ([ref]$changes)
  if ($newTag -ne $t.text) {
    $fixed++
    $repls += @{ start=$t.start; end=$t.end; new=$newTag; old=$t.text; changes=$changes }
    foreach ($c in $changes) { $changeLog += ($c.prop + ' x' + $c.count) }
  }
}

$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$reportPath = Join-Path $root ('reports\cv-step-fix-dup-props-mapa-v2-' + $ts + '.md')

$report = @()
$report += '# CV — Fix duplicate JSX props (MapaV2Interactive)'
$report += ''
$report += '- when: ' + $ts
$report += '- file: `src/components/v2/MapaV2Interactive.tsx`'
$report += '- tags modified: **' + $fixed + '**'
if ($changeLog.Count -gt 0) { $report += '- props fixed: ' + (($changeLog | Sort-Object -Unique) -join ', ') }
$report += ''

if ($fixed -eq 0) {
  $report += '## DIAG'
  $report += '- Nenhuma prop duplicada encontrada em tags JSX (talvez já tenha sido corrigido).'
  $report += ''
} else {
  $bk = BackupFile $target (Join-Path $root 'tools\_patch_backup')
  $report += '## BACKUP'
  $report += '- ' + (Split-Path -Leaf $bk)
  $report += ''

  # apply from end to start
  $newRaw = $raw
  foreach ($r in ($repls | Sort-Object start -Descending)) {
    $newRaw = $newRaw.Remove($r.start, $r.end-$r.start).Insert($r.start, $r.new)
  }
  WriteUtf8NoBom $target $newRaw

  $report += '## PATCH'
  $report += '- Applied replacements: ' + $repls.Count
  $report += ''
}

$verifyExit = 0
if (-not $NoVerify) {
  $verify = Join-Path $root 'tools\cv-verify.ps1'
  $report += '## VERIFY'
  if (Test-Path -LiteralPath $verify) {
    try {
      $out = & pwsh -NoProfile -ExecutionPolicy Bypass -File $verify 2>&1 | Out-String
      $verifyExit = $LASTEXITCODE
      $report += '- exit: **' + $verifyExit + '**'
      $report += ''
      $report += '```'
      $report += $out.TrimEnd()
      $report += '```'
    } catch {
      $verifyExit = 1
      $report += '- FAILED (exception)'
      $report += '- ' + $_.Exception.Message
    }
  } else {
    $report += '- tools/cv-verify.ps1 não encontrado (pulando)'
  }
  $report += ''
}

$report += '## NEXT'
if ($verifyExit -eq 0) {
  $report += '- ✅ Tudo verde. Próximo passo: commit deste bloco e seguimos para Contrato de dados + Zod + fallbacks.'
} else {
  $report += '- ⚠️ Ainda há erros no verify. Agora já sem o bloqueio de props duplicadas (se era isso).'
}

WriteUtf8NoBom $reportPath ($report -join "`n")
Write-Host ('[OK] Report -> ' + $reportPath)