param(
  [switch]$OpenReport
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

function EnsureDir([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
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

function ReadText([string]$p) {
  try { return [IO.File]::ReadAllText($p, [Text.UTF8Encoding]::new($false)) } catch { return '' }
}

$root = FindRepoRoot (Get-Location).Path
$reportsDir = Join-Path $root 'reports'
EnsureDir $reportsDir

$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$reportPath = Join-Path $reportsDir ('cv-step-b5a-diag-ux-v2-' + $ts + '.md')

# Escopo V2
$paths = @(
  (Join-Path $root 'src\app\c\[slug]\v2'),
  (Join-Path $root 'src\components\v2'),
  (Join-Path $root 'src\lib\v2')
) | Where-Object { Test-Path -LiteralPath $_ }

# Arquivos globais (tokens/tema)
$globalCandidates = @(
  (Join-Path $root 'src\app\globals.css'),
  (Join-Path $root 'src\styles\globals.css'),
  (Join-Path $root 'app\globals.css'),
  (Join-Path $root 'styles\globals.css'),
  (Join-Path $root 'tailwind.config.js'),
  (Join-Path $root 'tailwind.config.ts'),
  (Join-Path $root 'postcss.config.js'),
  (Join-Path $root 'postcss.config.mjs')
)

$globalFound = @()
foreach ($p in $globalCandidates) { if (Test-Path -LiteralPath $p) { $globalFound += $p } }

# Coleta de arquivos V2
$extCounts = @{}
$allFiles = @()
foreach ($p in $paths) {
  $files = Get-ChildItem -LiteralPath $p -Recurse -File -ErrorAction SilentlyContinue
  foreach ($f in $files) {
    $allFiles += $f.FullName
    $ext = $f.Extension.ToLowerInvariant()
    if (-not $extCounts.ContainsKey($ext)) { $extCounts[$ext] = 0 }
    $extCounts[$ext] = $extCounts[$ext] + 1
  }
}

# Métricas rápidas em TS/TSX/JS/JSX
$codeFiles = $allFiles | Where-Object { $_.ToLowerInvariant().EndsWith('.ts') -or $_.ToLowerInvariant().EndsWith('.tsx') -or $_.ToLowerInvariant().EndsWith('.js') -or $_.ToLowerInvariant().EndsWith('.jsx') }

$clientCount = 0
$ariaCount = 0
$roleCount = 0
$transitionCount = 0
$reducedMotionHint = 0
$focusHint = 0

$topFilesBySize = $codeFiles | ForEach-Object {
  $fi = Get-Item -LiteralPath $_ -ErrorAction SilentlyContinue
  if ($fi) { [PSCustomObject]@{ Path = $_; Size = $fi.Length } }
} | Sort-Object Size -Descending | Select-Object -First 12

# Procurar strings indicativas (sem regex pesada)
foreach ($f in $codeFiles) {
  $t = ReadText $f
  if ([string]::IsNullOrWhiteSpace($t)) { continue }

  if ($t -match "^\s*'use client'\s*;?\s*$" -or $t -match "^\s*`"use client`"\s*;?\s*$") { $clientCount++ }

  if ($t.Contains('aria-')) { $ariaCount++ }
  if ($t.Contains('role=')) { $roleCount++ }

  if ($t.Contains('transition') -or $t.Contains('animate') -or $t.Contains('motion')) { $transitionCount++ }

  if ($t.Contains('prefers-reduced-motion') -or $t.Contains('reduce motion') -or $t.Contains('reduced-motion')) { $reducedMotionHint++ }

  if ($t.Contains(':focus') -or $t.Contains('focus-visible') -or $t.Contains('tabIndex') -or $t.Contains('onKeyDown')) { $focusHint++ }
}

# CSS variables (se houver globals)
$cssVars = New-Object System.Collections.Generic.List[string]
foreach ($gf in $globalFound) {
  if (-not $gf.ToLowerInvariant().EndsWith('.css')) { continue }
  $txt = ReadText $gf
  if ([string]::IsNullOrWhiteSpace($txt)) { continue }
  $lines = $txt -split "`r?`n"
  foreach ($ln in $lines) {
    $s = $ln.Trim()
    if ($s.StartsWith('--')) {
      $name = $s.Split(':')[0].Trim()
      if ($name -and -not $cssVars.Contains($name)) { $cssVars.Add($name) }
      if ($cssVars.Count -ge 60) { break }
    }
  }
}

# Rotas V2 detectadas (pages)
$v2Pages = @()
if (Test-Path -LiteralPath (Join-Path $root 'src\app\c\[slug]\v2')) {
  $pageFiles = Get-ChildItem -LiteralPath (Join-Path $root 'src\app\c\[slug]\v2') -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -eq 'page.tsx' -or $_.Name -eq 'page.ts' -or $_.Name -eq 'page.jsx' -or $_.Name -eq 'page.js' }
  foreach ($pf in $pageFiles) { $v2Pages += (Rel $root $pf.FullName) }
  $v2Pages = $v2Pages | Sort-Object
}

# Heurísticas e recomendações
$recs = New-Object System.Collections.Generic.List[string]

if ($cssVars.Count -lt 8) {
  $recs.Add('Criar tokens V2 (CSS vars) para Concreto Zen: superficies, texto, acento, borda, sombra, blur e spacing. Facilita consistencia e tema.')
} else {
  $recs.Add('Aproveitar tokens existentes e padronizar nomes com prefixo (ex: --cv2-*) para evitar conflito com V1.')
}

if ($focusHint -lt 3) {
  $recs.Add('A11y: garantir foco visivel (focus-visible) em links/botoes do Hub e Nav; e navegacao por teclado nos cards.')
}

if ($reducedMotionHint -eq 0) {
  $recs.Add('Motion: adicionar suporte a prefers-reduced-motion (desligar transicoes/animacoes quando ativado).')
}

if ($clientCount -gt 8) {
  $recs.Add('Performance: revisar componentes client-only e empurrar o que puder para server (principalmente telas com conteudo estatico).')
}

$recs.Add('Unificar componente de Card V2 (mesmo visual e comportamento) para Hub/Provas/Trilhas, com estados: hover, active, disabled, loading.')
$recs.Add('Mapas mentais: no Hub, trocar grade simples por layout de nos conectados (linhas/flow) com hierarquia visual e legenda curta.')
$recs.Add('Nav: reforcar estado ativo, breadcrumb leve e titulo fixo do caderno no topo (sem poluir).')

# Report (sem code fence)
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add('# CV — Step B5a: DIAG UX V2 (Concreto Zen)')
$rep.Add('')
$rep.Add('- when: ' + $ts)
$rep.Add('- repo: ' + $root)
$rep.Add('')

$rep.Add('## SCOPE')
if ($paths.Count -eq 0) { $rep.Add('- (nenhum path V2 encontrado)') } else { foreach ($p in $paths) { $rep.Add('- ' + (Rel $root $p)) } }
$rep.Add('')

$rep.Add('## FILES (counts)')
foreach ($k in ($extCounts.Keys | Sort-Object)) {
  $rep.Add('- ' + $k + ': ' + $extCounts[$k])
}
$rep.Add('')

$rep.Add('## V2 ROUTES (page files)')
if ($v2Pages.Count -eq 0) {
  $rep.Add('- (nenhuma page encontrada)')
} else {
  foreach ($r in $v2Pages) { $rep.Add('- ' + $r) }
}
$rep.Add('')

$rep.Add('## GLOBAL THEME / TOKENS (found candidates)')
if ($globalFound.Count -eq 0) {
  $rep.Add('- (nenhum globals.css/tailwind/postcss detectado nos caminhos comuns)')
} else {
  foreach ($g in $globalFound) { $rep.Add('- ' + (Rel $root $g)) }
}
$rep.Add('')

$rep.Add('## CSS VARIABLES (sample)')
if ($cssVars.Count -eq 0) {
  $rep.Add('- (nenhuma CSS var detectada nos globals encontrados)')
} else {
  $rep.Add('- total detected (unique, capped): ' + $cssVars.Count)
  foreach ($v in $cssVars) { $rep.Add('- ' + $v) }
}
$rep.Add('')

$rep.Add('## QUICK UX METRICS (V2 code)')
$rep.Add('- client components (use client): ' + $clientCount)
$rep.Add('- files with aria-: ' + $ariaCount)
$rep.Add('- files with role=: ' + $roleCount)
$rep.Add('- files with transition/animate/motion hints: ' + $transitionCount)
$rep.Add('- reduced-motion hints: ' + $reducedMotionHint)
$rep.Add('- focus/keyboard hints: ' + $focusHint)
$rep.Add('')

$rep.Add('## TOP FILES BY SIZE (possible refactor candidates)')
foreach ($x in $topFilesBySize) {
  $rep.Add('- ' + (Rel $root $x.Path) + ' (' + $x.Size + ' bytes)')
}
$rep.Add('')

$rep.Add('## RECOMMENDATIONS (B5 priority)')
foreach ($r in $recs) { $rep.Add('- ' + $r) }
$rep.Add('')
$rep.Add('## NEXT (suggested B5 sequence)')
$rep.Add('- B5b: Add V2 tokens + base surfaces (Concreto Zen) (no breaking changes)')
$rep.Add('- B5c: V2 Card component + unify Hub/Provas/Trilhas')
$rep.Add('- B5d: Hub as mind-map layout (nodes + connectors) + subtle moods pulse')
$rep.Add('- B5e: A11y + reduced-motion pass (focus, keyboard, aria)')
$rep.Add('- B5f: Microtransitions and skeletons (light, zen)')

WriteUtf8NoBom $reportPath ($rep -join "`n")
Write-Host ('[OK] Report -> ' + $reportPath)
if ($OpenReport) { try { Start-Process $reportPath | Out-Null } catch {} }