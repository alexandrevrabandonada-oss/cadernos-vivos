param(
  [switch]$OpenReport
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
  $here = (Resolve-Path '.').Path
  for ($i=0; $i -lt 10; $i++) {
    if (Test-Path -LiteralPath (Join-Path $here 'package.json')) { return $here }
    $parent = Split-Path -Parent $here
    if ($parent -eq $here) { break }
    $here = $parent
  }
  throw 'Repo root nao encontrado (package.json). Rode na raiz do projeto.'
}

function EnsureDir([string]$dir) {
  if (-not (Test-Path -LiteralPath $dir)) { [IO.Directory]::CreateDirectory($dir) | Out-Null }
}

function WriteUtf8NoBom([string]$path, [string]$text) {
  $enc = New-Object System.Text.UTF8Encoding($false)
  EnsureDir (Split-Path -Parent $path)
  [IO.File]::WriteAllText($path, $text, $enc)
}

function TrimBom([string]$s) {
  if ($null -eq $s) { return '' }
  return $s.Replace([string][char]0xFEFF, '')
}

function ReadText([string]$path) {
  return (TrimBom([IO.File]::ReadAllText($path)))
}

function SplitLines([string]$s) {
  return ($s -split '\r?\n')
}

function RelPath([string]$root, [string]$abs) {
  $r = $abs.Substring($root.Length).TrimStart('\','/')
  return ($r -replace '/', '\')
}

function FindLineIndex([string[]]$lines, [string]$needle) {
  for ($i=0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -like ('*' + $needle + '*')) { return $i }
  }
  return -1
}

function SnipAround([string[]]$lines, [int]$idx, [int]$radius) {
  $start = [Math]::Max(0, $idx - $radius)
  $end = [Math]::Min($lines.Length - 1, $idx + $radius)
  $out = New-Object System.Collections.Generic.List[string]
  for ($i=$start; $i -le $end; $i++) {
    $out.Add(('{0,4}: {1}' -f ($i+1), $lines[$i]))
  }
  return $out
}

function ExtractDefaultExportSignature([string[]]$lines) {
  for ($i=0; $i -lt $lines.Length; $i++) {
    $l = $lines[$i].Trim()
    if ($l -like 'export default*function*' -or $l -like 'export default*async function*') {
      return $l
    }
  }
  for ($i=0; $i -lt $lines.Length; $i++) {
    $l = $lines[$i].Trim()
    if ($l -like 'export function*' -or $l -like 'export const*') { return $l }
  }
  return ''
}

$root = Get-RepoRoot
$stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
$report = Join-Path $root ('reports\{0}-cv-diag-b8a1-v2-universe-inventory.md' -f $stamp)

$log = New-Object System.Collections.Generic.List[string]
$log.Add('# CV DIAG B8A1 — Inventario Universo V2')
$log.Add('')
$log.Add('- Data: **' + $stamp + '**')
$log.Add('- Repo: `' + $root + '`')
$log.Add('')

# Git (best-effort)
$log.Add('## Git')
$log.Add('')
try {
  $branch = (git rev-parse --abbrev-ref HEAD 2>$null).Trim()
  $dirty = (git status --porcelain 2>$null)
  $dirtyCount = 0
  if ($dirty) { $dirtyCount = $dirty.Count }
  $dirtyFlag = (if ($dirtyCount -gt 0) { 'sim (' + $dirtyCount + ' items)' } else { 'nao' })
  $log.Add('- Branch: **' + $branch + '**')
  $log.Add('- Dirty: **' + $dirtyFlag + '**')
} catch {
  $log.Add('_Git indisponivel neste ambiente._')
}
$log.Add('')

# V2 pages
$v2PagesDir = Join-Path $root 'src\app\c\[slug]\v2'
$log.Add('## Rotas V2 (pages)')
$log.Add('')

if (-not (Test-Path -LiteralPath $v2PagesDir)) {
  $log.Add('[WARN] Dir nao encontrado: `' + $v2PagesDir + '`')
  $log.Add('')
} else {
  $pages = Get-ChildItem -LiteralPath $v2PagesDir -Recurse -Filter 'page.tsx' -File
  $log.Add('- Total: **' + $pages.Count + '**')
  $log.Add('')

  $keyNames = @(
    'HomeV2','HomeV2Hub','MapaV2Interactive','MapaV2','LinhaV2','LinhaDoTempoV2','TimelineV2',
    'ProvasV2','TrilhasV2','DebateV2','ShellV2','Cv2DoorGuide','Cv2PortalsCurated','Cv2V2Nav',
    'Cv2MindmapHubClient','Cv2UniverseRail','Cv2MapRail','Cv2MapNavPinsClient','Cv2PortalsCurated'
  )

  foreach ($p in $pages) {
    $rel = RelPath $root $p.FullName
    $raw = ReadText $p.FullName
    $lines = SplitLines $raw

    $sig = ExtractDefaultExportSignature $lines
    $idx = FindLineIndex $lines 'export default'

    $usesAwaitParams = ($raw -match 'await\s+params') -or ($raw -match 'React\.use\(\s*params\s*\)')
    $usesParamsDot   = ($raw -match 'params\?\.\s*slug') -or ($raw -match 'params\.\s*slug')

    $imports = New-Object System.Collections.Generic.List[string]
    foreach ($k in $keyNames) {
      $pattern = 'import\s+.*\b' + [regex]::Escape($k) + '\b'
      if ($raw -match $pattern) { $imports.Add($k) }
    }

    $log.Add('### `' + $rel + '`')
    $log.Add('')
    $log.Add('- signature: `' + $sig + '`')

    $pflag = '-'
    if ($usesAwaitParams) { $pflag = '[OK] await/use' }
    elseif ($usesParamsDot) { $pflag = '[WARN] params.slug sem await/use (pode quebrar no Next16)' }

    $log.Add('- Next16 params: ' + $pflag)

    if ($imports.Count -gt 0) { $log.Add('- imports chaves: ' + ($imports -join ', ')) }
    else { $log.Add('- imports chaves: _nenhum_') }

    $log.Add('')

    if ($idx -ge 0) {
      $sn = SnipAround $lines $idx 3
      $log.Add('```tsx')
      foreach ($s in $sn) { $log.Add($s) }
      $log.Add('```')
      $log.Add('')
    }
  }
}

# Components V2
$v2CompDir = Join-Path $root 'src\components\v2'
$log.Add('## Componentes V2 (inventario rapido)')
$log.Add('')

if (-not (Test-Path -LiteralPath $v2CompDir)) {
  $log.Add('[WARN] Dir nao encontrado: `' + $v2CompDir + '`')
  $log.Add('')
} else {
  $comps = Get-ChildItem -LiteralPath $v2CompDir -Filter '*.tsx' -File | Sort-Object Name
  $log.Add('- Total: **' + $comps.Count + '**')
  $log.Add('')

  foreach ($c in $comps) {
    $rel = RelPath $root $c.FullName
    $raw = ReadText $c.FullName
    $lines = SplitLines $raw
    $sig = ExtractDefaultExportSignature $lines

    $log.Add('- `' + $rel + '`')
    if ($sig) { $log.Add('  - `' + $sig + '`') }
  }
  $log.Add('')
}

# Summary
$log.Add('## Leitura do estado')
$log.Add('')
$log.Add('- Se as rotas V2 aparecem com imports chaves = _nenhum_, elas estao em modo shell (nao e perda).')
$log.Add('- Seus componentes V2 ricos existem e podem ser replugados com seguranca agora que Next16 async params foi estabilizado.')
$log.Add('- Proximo passo recomendado: replug map-first (MapaV2Interactive) + Portais em todas as telas, mantendo EmptyState como fallback.')
$log.Add('')

WriteUtf8NoBom $report ($log -join "`n")
Write-Host ('[REPORT] ' + $report)

if ($OpenReport) {
  try { Start-Process notepad.exe $report | Out-Null } catch { }
}

Write-Host 'DONE.'