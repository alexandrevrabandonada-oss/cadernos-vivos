param(
  [switch]$OpenReport
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

function Rel([string]$base, [string]$full) {
  try { $b = (Resolve-Path -LiteralPath $base).Path.TrimEnd('\') } catch { $b = $base.TrimEnd('\') }
  try { $f = (Resolve-Path -LiteralPath $full).Path } catch { $f = $full }
  if ($f.StartsWith($b)) { return $f.Substring($b.Length).TrimStart('\') }
  return $f
}

function HasAny([string]$text, [string[]]$needles) {
  foreach ($n in $needles) {
    if ($text.IndexOf($n, [StringComparison]::OrdinalIgnoreCase) -ge 0) { return $true }
  }
  return $false
}

$root = FindRepoRoot (Get-Location).Path
EnsureDir (Join-Path $root 'reports')

$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$reportPath = Join-Path $root ('reports\cv-diag-data-layer-' + $ts + '.md')

# package.json deps check
$pkgRaw = ReadUtf8 (Join-Path $root 'package.json')
$hasZod = ($pkgRaw.IndexOf('"zod"', [StringComparison]::OrdinalIgnoreCase) -ge 0)

# scan dirs
$scanDirs = @(
  (Join-Path $root 'src\lib'),
  (Join-Path $root 'src\app'),
  (Join-Path $root 'content')
) | Where-Object { Test-Path -LiteralPath $_ }

$files = @()
foreach ($d in $scanDirs) {
  $items = @(Get-ChildItem -LiteralPath $d -Recurse -File -ErrorAction SilentlyContinue)
  if ($items) { $files += $items }
}

# filter types
$files = @($files | Where-Object {
  $_ -ne $null -and (
    $_.Name.EndsWith('.ts') -or $_.Name.EndsWith('.tsx') -or $_.Name.EndsWith('.js') -or $_.Name.EndsWith('.jsx') -or
    $_.Name.EndsWith('.json') -or $_.Name.EndsWith('.md') -or $_.Name.EndsWith('.mdx') -or $_.Name.EndsWith('.txt')
  )
})

$patterns = @{
  'meta.json / caderno root' = @('meta.json','content/cadernos','content\cadernos','/cadernos/','\cadernos\')
  'fs/readFile'              = @('readFile','readFileSync','readdir','readdirSync','fs.','node:fs')
  'slug loader/getCaderno'    = @('getCaderno','loadCaderno','readCaderno','cadernoBySlug','bySlug','slug]')
  'meta.ui.default'           = @('meta.ui.default','uiDefault','ui.default','defaultUi','redirect','/v2')
  'V2 components usage'       = @('components/v2','/v2/','HomeV2Hub','MapaV2','DebateV2','LinhaV2','ProvasV2','TrilhasV2')
}

$hits = @{}
foreach ($k in $patterns.Keys) { $hits[$k] = @() }

foreach ($f in $files) {
  $p = $f.FullName
  $txt = ''
  try { $txt = ReadUtf8 $p } catch { continue }
  foreach ($k in $patterns.Keys) {
    if (HasAny $txt $patterns[$k]) {
      $hits[$k] += (Rel $root $p)
    }
  }
}

# meta.json list (real)
$metaPaths = @()
try {
  $metaPaths = @(Get-ChildItem -LiteralPath (Join-Path $root 'content') -Recurse -File -Filter 'meta.json' -ErrorAction SilentlyContinue | ForEach-Object { Rel $root $_.FullName })
} catch {}

$report = @()
$report += '# CV — DIAG Data Layer (B1)'
$report += ''
$report += ('- when: ' + $ts)
$report += ('- zod in package.json: **' + ($(if ($hasZod) { 'YES' } else { 'NO' })) + '**')
$report += ''

$report += '## meta.json encontrados'
if ($metaPaths.Count -gt 0) {
  $report += ('- count: **' + $metaPaths.Count + '**')
  foreach ($m in ($metaPaths | Sort-Object)) { $report += ('- `' + $m + '`') }
} else {
  $report += '- (nenhum meta.json encontrado em content/)'
}
$report += ''

$report += '## Mapa de arquivos que tocam o “motor”'
foreach ($k in ($patterns.Keys | Sort-Object)) {
  $list = @($hits[$k] | Sort-Object -Unique)
  $report += ('### ' + $k)
  $report += ('- hits: **' + $list.Count + '**')
  if ($list.Count -gt 0) {
    foreach ($x in $list) { $report += ('- `' + $x + '`') }
  }
  $report += ''
}

WriteUtf8NoBom $reportPath ($report -join "`n")
Write-Host ('[OK] Report -> ' + $reportPath)
if ($OpenReport) { try { Start-Process $reportPath } catch {} }