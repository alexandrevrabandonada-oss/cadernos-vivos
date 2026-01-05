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
  throw ('Não achei package.json subindo a partir de: ' + $start + '. Rode na raiz do repo.')
}

function Rel([string]$base, [string]$full) {
  if ([string]::IsNullOrWhiteSpace($base) -or [string]::IsNullOrWhiteSpace($full)) { return $full }
  try {
    $b = (Resolve-Path -LiteralPath $base).Path.TrimEnd('\')
  } catch {
    $b = $base.TrimEnd('\')
  }
  try {
    $f = (Resolve-Path -LiteralPath $full).Path
  } catch {
    $f = $full
  }
  if (-not [string]::IsNullOrWhiteSpace($f) -and -not [string]::IsNullOrWhiteSpace($b) -and $f.StartsWith($b)) {
    return $f.Substring($b.Length).TrimStart('\')
  }
  return $f
}

$root = FindRepoRoot (Get-Location).Path
$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
EnsureDir (Join-Path $root 'reports')

$pkg = $null
try { $pkg = (Get-Content -LiteralPath (Join-Path $root 'package.json') -Raw | ConvertFrom-Json) } catch {}

# Descobrir App Router dir (src\app ou app)
$appCandidates = @(
  (Join-Path $root 'src\app'),
  (Join-Path $root 'app')
)
$appDir = $null
foreach ($c in $appCandidates) {
  if (Test-Path -LiteralPath $c) { $appDir = $c; break }
}

# Git (se existir)
$gitOk = $false
$gitBranch = ''
$gitLast = ''
$gitStatus = ''
try {
  $gitOk = (Test-Path -LiteralPath (Join-Path $root '.git'))
  if ($gitOk) {
    $gitBranch = (git -C $root rev-parse --abbrev-ref HEAD 2>$null)
    $gitLast   = (git -C $root log -1 --pretty=format:'%h %ad %s' --date=short 2>$null)
    $gitStatus = (git -C $root status --porcelain 2>$null | Out-String).Trim()
  }
} catch {}

# Rotas Next (App Router)
$pages = @()
$apiRoutes = @()
if ($appDir -ne $null) {
  $allFiles = @(Get-ChildItem -LiteralPath $appDir -Recurse -File -ErrorAction SilentlyContinue)
  if (-not $allFiles) { $allFiles = @() }

  $pages = @(
    $allFiles |
      Where-Object { ($_ -ne $null) -and ($_.Name -match '^page\.(tsx|ts|jsx|js)$') } |
      ForEach-Object { Rel $root $_.FullName }
  )

  $apiRoutes = @(
    $allFiles |
      Where-Object { ($_ -ne $null) -and ($_.Name -match '^route\.(tsx|ts|jsx|js)$') } |
      ForEach-Object { Rel $root $_.FullName }
  )
}

# Separar V2
$v2Pages = @($pages | Where-Object { $_ -match '\\v2\\' })
$v1Pages = @($pages | Where-Object { $_ -notmatch '\\v2\\' })

# Cadernos (heurística): procurar meta.json
$metaHits = @()
$possibleContentRoots = @(
  (Join-Path $root 'content'),
  (Join-Path $root 'src\content'),
  (Join-Path $root 'cadernos'),
  (Join-Path $root 'src\cadernos'),
  (Join-Path $root 'src\data'),
  (Join-Path $root 'data')
) | Where-Object { Test-Path -LiteralPath $_ }

foreach ($p in $possibleContentRoots) {
  try { $metaHits += @(Get-ChildItem -LiteralPath $p -Recurse -File -Filter 'meta.json' -ErrorAction SilentlyContinue) } catch {}
}
if (-not $metaHits) { $metaHits = @() }

$slugs = @()
$metaRel = @()
foreach ($m in $metaHits) {
  if ($m -eq $null) { continue }
  $metaRel += (Rel $root $m.FullName)
  $slugs += (Split-Path -Leaf (Split-Path -Parent $m.FullName))
}
$slugs = $slugs | Sort-Object -Unique

# Node/NPM
$nodeV = ''
$npmV = ''
try { $nodeV = (node -v 2>$null) } catch {}
try { $npmV = (npm -v 2>$null) } catch {}

$report = @()
$report += '# Cadernos Vivos — DIAG Inventário (' + $ts + ')'
$report += ''
$report += '## Repo'
$report += '- Root: ' + '`' + $root + '`'
if ($pkg -ne $null) {
  $report += '- package: **' + $pkg.name + '** v' + $pkg.version
}
if ($nodeV) { $report += '- node: ' + $nodeV }
if ($npmV)  { $report += '- npm: '  + $npmV }
$report += ''

$report += '## App Router'
if ($appDir -ne $null) {
  $report += '- appDir: ' + '`' + (Rel $root $appDir) + '`'
} else {
  $report += '- appDir: (não encontrado: tentei src\app e app)'
}
$report += ''

$report += '## Git'
if ($gitOk) {
  $report += '- branch: **' + $gitBranch + '**'
  if ($gitLast) { $report += '- last: ' + $gitLast }
  $report += '- dirty: ' + ($(if ($gitStatus) { 'YES' } else { 'NO' }))
  if ($gitStatus) {
    $report += ''
    $report += '```'
    $report += $gitStatus
    $report += '```'
  }
} else {
  $report += '- .git: não detectado'
}
$report += ''

$report += '## Rotas (App Router)'
$report += '- pages total: **' + $pages.Count + '** (V1: ' + $v1Pages.Count + ', V2: ' + $v2Pages.Count + ')'
$report += '- api routes: **' + $apiRoutes.Count + '**'
$report += ''

$report += '### Pages (V2)'
if ($v2Pages.Count -gt 0) {
  $report += ''
  foreach ($r in ($v2Pages | Sort-Object)) { $report += '- `' + $r + '`' }
} else {
  $report += '- (nenhuma encontrada ainda)'
}
$report += ''

$report += '### Pages (V1 / resto)'
if ($v1Pages.Count -gt 0) {
  $report += ''
  foreach ($r in ($v1Pages | Sort-Object)) { $report += '- `' + $r + '`' }
} else {
  $report += '- (nenhuma encontrada)'
}
$report += ''

$report += '### API Routes'
if ($apiRoutes.Count -gt 0) {
  $report += ''
  foreach ($r in ($apiRoutes | Sort-Object)) { $report += '- `' + $r + '`' }
} else {
  $report += '- (nenhuma encontrada)'
}
$report += ''

$report += '## Cadernos (detectados por meta.json)'
$rootsStr = '(nenhum padrão encontrado)'
if ($possibleContentRoots.Count -gt 0) {
  $rootsStr = (($possibleContentRoots | ForEach-Object { Rel $root $_ } | Sort-Object) -join ', ')
}
$report += '- content roots checados: ' + $rootsStr
$report += '- meta.json encontrados: **' + $metaHits.Count + '**'
$report += '- slugs únicos: **' + $slugs.Count + '**'
if ($slugs.Count -gt 0) {
  $report += ''
  foreach ($s in $slugs) { $report += '- `' + $s + '`' }
}
$report += ''

$report += '## Meta.json paths'
if ($metaRel.Count -gt 0) {
  $report += ''
  foreach ($p in ($metaRel | Sort-Object)) { $report += '- `' + $p + '`' }
} else {
  $report += '- (nenhum meta.json encontrado nos roots padrão — pode estar em outro lugar)'
}

$reportPath = Join-Path $root ('reports\cv-diag-' + $ts + '.md')
[IO.File]::WriteAllLines($reportPath, $report, [Text.UTF8Encoding]::new($false))

Write-Host ('[OK] Report -> ' + $reportPath)
if ($OpenReport) { try { Start-Process $reportPath } catch {} }