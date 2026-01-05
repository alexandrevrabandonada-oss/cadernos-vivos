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

function BackupFile([string]$filePath, [string]$backupDir) {
  EnsureDir $backupDir
  $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
  $name = Split-Path -Leaf $filePath
  $dest = Join-Path $backupDir ($ts + '-' + $name + '.bak')
  Copy-Item -LiteralPath $filePath -Destination $dest -Force
  return $dest
}

function ReadUtf8([string]$p) {
  return [IO.File]::ReadAllText($p, [Text.UTF8Encoding]::new($false))
}

function WriteUtf8NoBom([string]$p, [string]$content) {
  [IO.File]::WriteAllText($p, $content, [Text.UTF8Encoding]::new($false))
}

function SkipWs([string]$s, [ref]$i) {
  while ($i.Value -lt $s.Length) {
    $c = $s[$i.Value]
    if ($c -eq ' ' -or $c -eq "`n" -or $c -eq "`r" -or $c -eq "`t") { $i.Value++ } else { break }
  }
}

function ParseIdent([string]$s, [ref]$i) {
  $start = $i.Value
  while ($i.Value -lt $s.Length) {
    $c = $s[$i.Value]
    $ok = ([char]::IsLetterOrDigit($c) -or $c -eq '_' -or $c -eq '-' )
    if ($ok) { $i.Value++ } else { break }
  }
  if ($i.Value -le $start) { return $null }
  return $s.Substring($start, $i.Value - $start)
}

function ParseQuoted([string]$s, [ref]$i, [char]$q) {
  $start = $i.Value
  $i.Value++ # skip opening quote
  while ($i.Value -lt $s.Length) {
    $c = $s[$i.Value]
    if ($c -eq '\') { $i.Value += 2; continue }
    if ($c -eq $q) { $i.Value++; break }
    $i.Value++
  }
  $end = $i.Value
  return @{ start=$start; end=$end; text=$s.Substring($start, $end-$start); kind='string' }
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
      $i.Value++
      continue
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
  $txt = $s.Substring($start, $end-$start)  # includes outer { ... }
  $inner = $txt
  if ($inner.StartsWith('{') -and $inner.EndsWith('}')) { $inner = $inner.Substring(1, $inner.Length-2) }
  return @{ start=$start; end=$end; text=$txt; inner=$inner; kind='brace' }
}

function ParseAttrValue([string]$s, [ref]$i) {
  SkipWs $s ([ref]$i)
  if ($i.Value -ge $s.Length) { return $null }
  $c = $s[$i.Value]
  if ($c -eq '{') { return ParseBraced $s ([ref]$i) }
  if ($c -eq '"' -or $c -eq "'") { return ParseQuoted $s ([ref]$i) $c }
  # bare value (rare)
  $start = $i.Value
  while ($i.Value -lt $s.Length) {
    $ch = $s[$i.Value]
    if ($ch -eq ' ' -or $ch -eq "`n" -or $ch -eq "`r" -or $ch -eq "`t" -or $ch -eq '>' ) { break }
    $i.Value++
  }
  $end = $i.Value
  return @{ start=$start; end=$end; text=$s.Substring($start, $end-$start); kind='bare' }
}

function ParseOpeningTagProps([string]$tag) {
  $props = @()
  $i = 0
  # assume starts with '<'
  if (-not $tag.StartsWith('<')) { return $props }

  # skip '<' + tagName
  $i = 1
  SkipWs $tag ([ref]$i)
  $tagName = ParseIdent $tag ([ref]$i)
  if (-not $tagName) { $tagName = '' }

  while ($i -lt $tag.Length) {
    SkipWs $tag ([ref]$i)
    if ($i -ge $tag.Length) { break }
    $c = $tag[$i]
    if ($c -eq '>' ) { break }
    if ($c -eq '/' -and ($i+1) -lt $tag.Length -and $tag[$i+1] -eq '>') { break }

    # spread attrs: {...props}
    if ($c -eq '{') {
      $tmp = ParseBraced $tag ([ref]$i)
      $props += @{ name='(spread)'; segStart=$tmp.start; segEnd=$tmp.end; value=$tmp; tagName=$tagName }
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
      # boolean attr
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

  $changesOut.Value += @($dupes | ForEach-Object { @{ prop=$_; count=$byName[$_].Count } })

  $newTag = $tag

  # apply edits from end to start within the tag
  foreach ($propName in $dupes) {
    $items = $byName[$propName]
    if ($items.Count -lt 2) { continue }

    # sort by segStart
    $items = $items | Sort-Object segStart

    if ($propName -eq 'style') {
      # Merge all style values into one: style={{ ...((a)||{}), ...((b)||{}) }}
      $exprParts = @()
      foreach ($it in $items) {
        if ($it.value -eq $null) { continue }
        if ($it.value.kind -eq 'brace') {
          $inner = $it.value.inner.Trim()
          if ($inner.Length -gt 0) { $exprParts += ('...(((' + $inner + ') || {}))') }
        } elseif ($it.value.kind -eq 'string') {
          # unusual, but keep as-is as last resort
          $exprParts += ('...(({}))')
        } else {
          $raw = $it.value.text.Trim()
          if ($raw.Length -gt 0) { $exprParts += ('...(((' + $raw + ') || {}))') }
        }
      }
      if ($exprParts.Count -eq 0) { continue }
      $merged = 'style={{ ' + ($exprParts -join ', ') + ' }}'

      # replace first occurrence segment with merged; remove the others
      $first = $items[0]
      $toRemove = $items | Select-Object -Skip 1

      # remove from end
      foreach ($r in ($toRemove | Sort-Object segStart -Descending)) {
        $newTag = $newTag.Remove($r.segStart, $r.segEnd - $r.segStart)
      }
      # replace first segment (need to adjust if we removed earlier segments after it; but we only removed after it)
      $newTag = $newTag.Remove($first.segStart, $first.segEnd - $first.segStart).Insert($first.segStart, $merged)
      continue
    }

    if ($propName -eq 'className') {
      # Merge into className={[a,b].filter(Boolean).join(" ")}
      $exprs = @()
      foreach ($it in $items) {
        if ($it.value -eq $null) { continue }
        if ($it.value.kind -eq 'string') {
          $exprs += $it.value.text
        } elseif ($it.value.kind -eq 'brace') {
          $inner = $it.value.inner.Trim()
          if ($inner.Length -gt 0) { $exprs += ('(' + $inner + ')') }
        } else {
          $exprs += $it.value.text
        }
      }
      if ($exprs.Count -eq 0) { continue }
      $merged = 'className={[' + ($exprs -join ', ') + '].filter(Boolean).join(" ")}'

      $first = $items[0]
      $toRemove = $items | Select-Object -Skip 1
      foreach ($r in ($toRemove | Sort-Object segStart -Descending)) {
        $newTag = $newTag.Remove($r.segStart, $r.segEnd - $r.segStart)
      }
      $newTag = $newTag.Remove($first.segStart, $first.segEnd - $first.segStart).Insert($first.segStart, $merged)
      continue
    }

    # default: keep last occurrence, remove earlier duplicates
    $keep = $items[-1]
    $drop = $items | Select-Object -First ($items.Count - 1)
    foreach ($r in ($drop | Sort-Object segStart -Descending)) {
      $newTag = $newTag.Remove($r.segStart, $r.segEnd - $r.segStart)
    }
  }

  return $newTag
}

function FindOpeningTags([string]$raw) {
  $tags = @()
  $i = 0
  while ($i -lt $raw.Length) {
    $c = $raw[$i]
    if ($c -ne '<') { $i++; continue }

    if (($i+1) -ge $raw.Length) { break }
    $n = $raw[$i+1]
    if ($n -eq '/' -or $n -eq '!' -or $n -eq '?') { $i++; continue }
    if ($n -eq '>') { $i += 2; continue } # fragment <>

    $start = $i
    $i++ # move past '<'
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

$root = FindRepoRoot (Get-Location).Path
EnsureDir (Join-Path $root 'reports')
EnsureDir (Join-Path $root 'tools\_patch_backup')

$target = Join-Path $root 'src\components\v2\MapaV2Interactive.tsx'
if (-not (Test-Path -LiteralPath $target)) {
  throw ('Arquivo não encontrado: ' + $target)
}

$raw = ReadUtf8 $target
$tags = FindOpeningTags $raw

$allChanges = @()
$fixedCount = 0
$replacements = @()

# build replacements
foreach ($t in $tags) {
  $changes = @()
  $newTag = FixDuplicatePropsInTag $t.text ([ref]$changes)
  if ($newTag -ne $t.text) {
    $fixedCount++
    $replacements += @{ start=$t.start; end=$t.end; old=$t.text; new=$newTag; changes=$changes }
  }
}

$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$reportPath = Join-Path $root ('reports\cv-step-fix-dup-props-' + $ts + '.md')

$report = @()
$report += '# CV — Fix duplicate props (MapaV2Interactive)'
$report += ''
$report += '- when: ' + $ts
$report += '- file: `src/components/v2/MapaV2Interactive.tsx`'
$report += '- tags changed: **' + $fixedCount + '**'
$report += ''

if ($fixedCount -eq 0) {
  $report += '## DIAG'
  $report += '- Nenhuma tag com props duplicadas encontrada no arquivo (talvez o erro já tenha sido corrigido).'
  $report += ''
} else {
  $bk = BackupFile $target (Join-Path $root 'tools\_patch_backup')
  $report += '## BACKUP'
  $report += '- ' + (Split-Path -Leaf $bk)
  $report += ''

  # apply replacements from end to start (avoid shifting indexes)
  $newRaw = $raw
  foreach ($r in ($replacements | Sort-Object start -Descending)) {
    $newRaw = $newRaw.Remove($r.start, $r.end-$r.start).Insert($r.start, $r.new)
  }
  WriteUtf8NoBom $target $newRaw

  $report += '## PATCH'
  foreach ($r in $replacements) {
    $props = ($r.changes | ForEach-Object { $_.prop + ' x' + $_.count }) -join ', '
    if ([string]::IsNullOrWhiteSpace($props)) { $props = '(n/a)' }
    $report += '- fixed tag: ' + $props
  }
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
      $report += '- tools/cv-verify.ps1 exit: **' + $verifyExit + '**'
      $report += ''
      $report += '```'
      $report += $out.TrimEnd()
      $report += '```'
    } catch {
      $verifyExit = 1
      $report += '- verify: **FAILED** (exception)'
      $report += '- ' + $_.Exception.Message
    }
  } else {
    $report += '- tools/cv-verify.ps1 não encontrado (pulando)'
  }
  $report += ''
}

$report += '## NEXT'
if ($verifyExit -eq 0) {
  $report += '- Se estiver tudo verde: **commit** este bloco (lint/build ok) e seguimos para o próximo tijolo (Contrato de dados + Zod + fallbacks).'
} else {
  $report += '- Ainda há erros no VERIFY. Corrigir os próximos erros apontados (agora sem o bloqueio de props duplicadas).'
}

WriteUtf8NoBom $reportPath ($report -join "`n")
Write-Host ('[OK] Report -> ' + $reportPath)