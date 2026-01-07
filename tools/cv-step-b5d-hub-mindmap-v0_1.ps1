param(
  [switch]$OpenReport,
  [switch]$NoVerify
)

$ErrorActionPreference = 'Stop'

function FindRepoRoot([string]$start) {
  $cur = (Resolve-Path -LiteralPath $start).Path
  while ($true) {
    if (Test-Path -LiteralPath (Join-Path $cur 'package.json')) { return $cur }
    $parent = Split-Path -Parent $cur
    if ($parent -eq $cur -or [string]::IsNullOrWhiteSpace($parent)) { break }
    $cur = $parent
  }
  throw 'Nao achei package.json. Rode na raiz do repo.'
}

function EnsureDir([string]$p) { if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function WriteUtf8NoBom([string]$p, [string]$content) { [IO.File]::WriteAllText($p, $content, [Text.UTF8Encoding]::new($false)) }

function BackupFile([string]$filePath, [string]$backupDir) {
  EnsureDir $backupDir
  $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
  $name = Split-Path -Leaf $filePath
  $dest = Join-Path $backupDir ($ts + '-' + $name + '.bak')
  Copy-Item -LiteralPath $filePath -Destination $dest -Force
  return $dest
}

function Rel([string]$base, [string]$full) {
  try { $b = (Resolve-Path -LiteralPath $base).Path.TrimEnd('\') } catch { $b = $base.TrimEnd('\') }
  try { $f = (Resolve-Path -LiteralPath $full).Path } catch { $f = $full }
  if ($f.StartsWith($b)) { return $f.Substring($b.Length).TrimStart('\') }
  return $f
}

function ReadText([string]$p) {
  return [IO.File]::ReadAllText($p, [Text.UTF8Encoding]::new($false))
}

function FindEndOfTag([string]$s, [int]$startIdx) {
  # encontra o '>' do primeiro start tag, respeitando aspas
  $i = $startIdx
  $inQ = [char]0
  while ($i -lt $s.Length) {
    $ch = $s[$i]
    if ($inQ -ne [char]0) {
      if ($ch -eq $inQ) { $inQ = [char]0 }
      $i++
      continue
    }
    if ($ch -eq '"' -or $ch -eq "'") { $inQ = $ch; $i++; continue }
    if ($ch -eq '>') { return $i }
    $i++
  }
  return -1
}

function EnsureAttrOnFirstReturnTag([string]$raw, [string]$attrText, [string]$classToEnsure) {
  # tenta inserir attrText e className/classToEnsure no primeiro elemento retornado
  $idxReturn = $raw.IndexOf('return')
  if ($idxReturn -lt 0) { return @{ ok=$false; text=$raw; note='no return found' } }

  $idxParen = $raw.IndexOf('(', $idxReturn)
  if ($idxParen -lt 0) { return @{ ok=$false; text=$raw; note='no return(' } }

  # acha o primeiro '<' depois do return(
  $idxLt = $raw.IndexOf('<', $idxParen)
  if ($idxLt -lt 0) { return @{ ok=$false; text=$raw; note='no jsx tag after return(' } }

  # caso fragment <> ... </>, faz wrapper simples
  if ($idxLt + 1 -lt $raw.Length -and $raw[$idxLt+1] -eq '>') {
    $openFrag = '<>'
    $closeFrag = '</>'
    $idxOpen = $raw.IndexOf($openFrag, $idxLt)
    if ($idxOpen -lt 0) { return @{ ok=$false; text=$raw; note='fragment open not found' } }
    $idxClose = $raw.IndexOf($closeFrag, $idxOpen + $openFrag.Length)
    if ($idxClose -lt 0) { return @{ ok=$false; text=$raw; note='fragment close not found' } }

    $wrapOpen = '<div className="' + $classToEnsure + '" ' + $attrText + '>'
    $wrapClose = '</div>'

    $t1 = $raw.Substring(0, $idxOpen) + $wrapOpen + $raw.Substring($idxOpen + $openFrag.Length)
    # ajustar idxClose por causa do tamanho diferente
    $shift = $wrapOpen.Length - $openFrag.Length
    $idxClose2 = $idxClose + $shift
    $t2 = $t1.Substring(0, $idxClose2) + $wrapClose + $t1.Substring($idxClose2 + $closeFrag.Length)
    return @{ ok=$true; text=$t2; note='wrapped fragment with div' }
  }

  # pega o nome da tag
  $j = $idxLt + 1
  while ($j -lt $raw.Length) {
    $c = $raw[$j]
    if (($c -ge 'a' -and $c -le 'z') -or ($c -ge 'A' -and $c -le 'Z')) { $j++; continue }
    break
  }
  if ($j -le $idxLt + 1) { return @{ ok=$false; text=$raw; note='cannot read tag name' } }

  $idxGt = FindEndOfTag $raw $idxLt
  if ($idxGt -lt 0) { return @{ ok=$false; text=$raw; note='cannot find end of start tag' } }

  $tag = $raw.Substring($idxLt, $idxGt - $idxLt + 1)

  # se já tem attr, ok
  if ($tag.Contains($attrText.Split('=')[0])) {
    # ainda garante classe
  } else {
    $tag = $tag.TrimEnd('>')
    $tag = $tag + ' ' + $attrText + '>'
  }

  # garante className
  if ($tag -match 'className\s*=\s*"([^"]*)"') {
    $cls = [regex]::Match($tag, 'className\s*=\s*"([^"]*)"').Groups[1].Value
    if (-not ($cls -split '\s+' | Where-Object { $_ -eq $classToEnsure })) {
      $newCls = ($cls.Trim() + ' ' + $classToEnsure).Trim()
      $tag = [regex]::Replace($tag, 'className\s*=\s*"([^"]*)"', 'className="' + $newCls + '"', 1)
    }
  } else {
    $tag = $tag.TrimEnd('>')
    $tag = $tag + ' className="' + $classToEnsure + '">'
  }

  $out = $raw.Substring(0, $idxLt) + $tag + $raw.Substring($idxGt + 1)
  return @{ ok=$true; text=$out; note='patched first return tag' }
}

$root = FindRepoRoot (Get-Location).Path
$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$step = 'cv-step-b5d-hub-mindmap'

$reportsDir = Join-Path $root 'reports'
$backupDir  = Join-Path $root 'tools\_patch_backup'
EnsureDir $reportsDir
EnsureDir $backupDir

$reportPath = Join-Path $reportsDir ($step + '-' + $ts + '.md')

$actions = New-Object System.Collections.Generic.List[string]
$backups = New-Object System.Collections.Generic.List[string]

# 1) CSS mind-map no globals.css (escopado V2)
$globals = Join-Path $root 'src\app\globals.css'
if (-not (Test-Path -LiteralPath $globals)) { throw ('globals.css nao encontrado: ' + $globals) }

$gRaw = ReadText $globals
$cssMarker = 'CV2 HUB MAP: mind-map'
if ($gRaw.Contains($cssMarker)) {
  $actions.Add('globals.css: hub mind-map CSS ja existe (marker encontrado).')
} else {
  $bk = BackupFile $globals $backupDir
  $backups.Add((Split-Path -Leaf $bk))

  $css = @(
    '',
    '/* CV2 HUB MAP: mind-map */',
    '.cv-v2 .cv2-hubMap {',
    '  padding: 22px;',
    '}',
    '',
    '.cv-v2 .cv2-hubMap::before {',
    '  content: "";',
    '  position: fixed;',
    '  inset: 0;',
    '  pointer-events: none;',
    '  background:',
    '    radial-gradient(700px 500px at 18% 12%, rgba(183,255,90,0.10), transparent 60%),',
    '    radial-gradient(800px 520px at 85% 20%, rgba(255,255,255,0.06), transparent 65%),',
    '    linear-gradient(to bottom, rgba(255,255,255,0.04), transparent 40%);',
    '  opacity: 1;',
    '  z-index: 0;',
    '}',
    '',
    '.cv-v2 .cv2-hubMap > * {',
    '  position: relative;',
    '  z-index: 1;',
    '}',
    '',
    '.cv-v2 [data-cv2-hub="map"] a.cv2-card,',
    '.cv-v2 [data-cv2-hub="map"] .cv2-card {',
    '  position: relative;',
    '}',
    '',
    '.cv-v2 [data-cv2-hub="map"] a.cv2-card::before,',
    '.cv-v2 [data-cv2-hub="map"] .cv2-card::before {',
    '  content: "";',
    '  position: absolute;',
    '  left: -18px;',
    '  top: 22px;',
    '  width: 18px;',
    '  height: 1px;',
    '  background: rgba(183,255,90,0.24);',
    '}',
    '',
    '.cv-v2 [data-cv2-hub="map"] a.cv2-card::after,',
    '.cv-v2 [data-cv2-hub="map"] .cv2-card::after {',
    '  content: "";',
    '  position: absolute;',
    '  left: -23px;',
    '  top: 18px;',
    '  width: 10px;',
    '  height: 10px;',
    '  border-radius: 999px;',
    '  background: rgba(183,255,90,0.18);',
    '  box-shadow: 0 0 0 4px rgba(183,255,90,0.06);',
    '}',
    '',
    '.cv-v2 [data-cv2-hub="map"] .cv2-cardInteractive:hover::after {',
    '  background: rgba(183,255,90,0.26);',
    '  box-shadow: 0 0 0 5px rgba(183,255,90,0.08), 0 0 24px rgba(183,255,90,0.18);',
    '}',
    '',
    '.cv-v2 [data-cv2-hub="map"] .cv2-cardInteractive {',
    '  overflow: hidden;',
    '}',
    '',
    '.cv-v2 [data-cv2-hub="map"] .cv2-cardInteractive::marker {',
    '  content: "";',
    '}',
    '',
    '/* linhas sutis no fundo (grade organica) */',
    '.cv-v2 [data-cv2-hub="map"] {',
    '  background-image:',
    '    linear-gradient(to right, rgba(255,255,255,0.03) 1px, transparent 1px),',
    '    linear-gradient(to bottom, rgba(255,255,255,0.03) 1px, transparent 1px);',
    '  background-size: 44px 44px;',
    '  background-position: 0 0;',
    '}',
    '',
    '@media (max-width: 640px) {',
    '  .cv-v2 .cv2-hubMap { padding: 16px; }',
    '  .cv-v2 [data-cv2-hub="map"] a.cv2-card::before,',
    '  .cv-v2 [data-cv2-hub="map"] .cv2-card::before {',
    '    left: -14px; width: 14px;',
    '  }',
    '  .cv-v2 [data-cv2-hub="map"] a.cv2-card::after,',
    '  .cv-v2 [data-cv2-hub="map"] .cv2-card::after {',
    '    left: -19px;',
    '  }',
    '}',
    ''
  ) -join "`n"

  WriteUtf8NoBom $globals ($gRaw.TrimEnd() + "`n" + $css)
  $actions.Add('globals.css: added mind-map background + connectors for hub cards (scoped to data-cv2-hub="map").')
}

# 2) Patch HomeV2Hub.tsx: marcar container com data-cv2-hub="map" e cv2-hubMap
$hub = Join-Path $root 'src\components\v2\HomeV2Hub.tsx'
if (-not (Test-Path -LiteralPath $hub)) { throw ('HomeV2Hub.tsx nao encontrado: ' + $hub) }

$hubRaw = ReadText $hub
$needAttr = 'data-cv2-hub="map"'
$needClass = 'cv2-hubMap'

if ($hubRaw.Contains($needAttr) -and $hubRaw.Contains($needClass)) {
  $actions.Add('HomeV2Hub.tsx: ja marcado com data-cv2-hub="map" e classe cv2-hubMap.')
} else {
  $bk2 = BackupFile $hub $backupDir
  $backups.Add((Split-Path -Leaf $bk2))

  $res = EnsureAttrOnFirstReturnTag $hubRaw $needAttr $needClass
  if (-not $res.ok) {
    throw ('Nao consegui patchar o primeiro return do HomeV2Hub.tsx: ' + $res.note)
  }

  WriteUtf8NoBom $hub $res.text
  $actions.Add('HomeV2Hub.tsx: ensured container has data-cv2-hub="map" + cv2-hubMap (' + $res.note + ').')
}

# 3) VERIFY
$verifyExit = 0
$verifyOut = ''
if (-not $NoVerify) {
  $verify = Join-Path $root 'tools\cv-verify.ps1'
  if (Test-Path -LiteralPath $verify) {
    $verifyOut = (& pwsh -NoProfile -ExecutionPolicy Bypass -File $verify 2>&1 | Out-String)
    $verifyExit = $LASTEXITCODE
  } else {
    $verifyOut = 'tools/cv-verify.ps1 nao encontrado (pulando)'
    $verifyExit = 0
  }
}

# 4) REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add('# CV — Step B5d: Hub V2 mind-map (nodes + connectors)')
$rep.Add('')
$rep.Add('- when: ' + $ts)
$rep.Add('- repo: ' + $root)
$rep.Add('')
$rep.Add('## ACTIONS')
foreach ($a in $actions) { $rep.Add('- ' + $a) }
$rep.Add('')
$rep.Add('## BACKUPS')
if ($backups.Count -eq 0) { $rep.Add('- (none)') } else { foreach ($b in $backups) { $rep.Add('- ' + $b) } }
$rep.Add('')
$rep.Add('## VERIFY')
$rep.Add('- exit: ' + $verifyExit)
$rep.Add('')
$rep.Add('--- VERIFY OUTPUT START ---')
foreach ($ln in ($verifyOut -split "`r?`n")) { $rep.Add($ln) }
$rep.Add('--- VERIFY OUTPUT END ---')
$rep.Add('')
$rep.Add('## NEXT')
if ($verifyExit -eq 0) {
  $rep.Add('- B5e: teclado no Hub (setas/enter) + aria-labels onde faltar.')
} else {
  $rep.Add('- Corrigir verify e re-rodar.')
}

WriteUtf8NoBom $reportPath ($rep -join "`n")
Write-Host ('[OK] Report -> ' + $reportPath)
if ($OpenReport) { try { Start-Process $reportPath | Out-Null } catch {} }