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

function EnsureDir([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
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

function Rel([string]$base, [string]$full) {
  try { $b = (Resolve-Path -LiteralPath $base).Path.TrimEnd('\') } catch { $b = $base.TrimEnd('\') }
  try { $f = (Resolve-Path -LiteralPath $full).Path } catch { $f = $full }
  if ($f.StartsWith($b)) { return $f.Substring($b.Length).TrimStart('\') }
  return $f
}

$root = FindRepoRoot (Get-Location).Path
$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$step = 'cv-step-b5b-add-cv2-tokens-and-v2-layout'

$reportsDir = Join-Path $root 'reports'
$backupDir  = Join-Path $root 'tools\_patch_backup'
EnsureDir $reportsDir
EnsureDir $backupDir

$reportPath = Join-Path $reportsDir ($step + '-' + $ts + '.md')

$actions = New-Object System.Collections.Generic.List[string]
$backups = New-Object System.Collections.Generic.List[string]

# --- 1) globals.css: adicionar tokens CV2 (escopado em .cv-v2)
$globals = Join-Path $root 'src\app\globals.css'
if (-not (Test-Path -LiteralPath $globals)) { throw ('globals.css nao encontrado em: ' + $globals) }

$raw = [IO.File]::ReadAllText($globals, [Text.UTF8Encoding]::new($false))
$marker = 'CV2 TOKENS: Concreto Zen'

if ($raw.Contains($marker)) {
  $actions.Add('globals.css: tokens CV2 ja existem (marker encontrado).')
} else {
  $bk = BackupFile $globals $backupDir
  $backups.Add((Split-Path -Leaf $bk))

  $block = @(
    '',
    '/* CV2 TOKENS: Concreto Zen */',
    '.cv-v2 {',
    '  /* palette */',
    '  --cv2-bg: #0b0d10;',
    '  --cv2-fg: #e8edf2;',
    '  --cv2-muted: #9aa3ad;',
    '  --cv2-surface: #11161c;',
    '  --cv2-card: #151c24;',
    '  --cv2-border: rgba(255,255,255,0.10);',
    '  --cv2-accent: #b7ff5a;',
    '  --cv2-danger: #ff5a7a;',
    '  /* geometry */',
    '  --cv2-radius-sm: 12px;',
    '  --cv2-radius-lg: 18px;',
    '  --cv2-pad: 18px;',
    '  --cv2-gap: 14px;',
    '  /* fx */',
    '  --cv2-shadow: 0 10px 30px rgba(0,0,0,0.45);',
    '  --cv2-shadow-soft: 0 6px 18px rgba(0,0,0,0.28);',
    '  --cv2-blur: 10px;',
    '',
    '  background: radial-gradient(1200px 700px at 20% -10%, rgba(183,255,90,0.08), transparent 55%),',
    '              radial-gradient(900px 600px at 90% 10%, rgba(255,255,255,0.06), transparent 60%),',
    '              var(--cv2-bg);',
    '  color: var(--cv2-fg);',
    '  min-height: 100vh;',
    '}',
    '',
    '.cv-v2 .cv2-surface {',
    '  background: var(--cv2-surface);',
    '  border: 1px solid var(--cv2-border);',
    '  border-radius: var(--cv2-radius-lg);',
    '  box-shadow: var(--cv2-shadow-soft);',
    '}',
    '',
    '.cv-v2 .cv2-card {',
    '  background: var(--cv2-card);',
    '  border: 1px solid var(--cv2-border);',
    '  border-radius: var(--cv2-radius-lg);',
    '  box-shadow: var(--cv2-shadow-soft);',
    '}',
    '',
    '.cv-v2 .cv2-muted { color: var(--cv2-muted); }',
    '.cv-v2 .cv2-border { border-color: var(--cv2-border); }',
    '',
    '.cv-v2 a:focus-visible,',
    '.cv-v2 button:focus-visible,',
    '.cv-v2 [tabindex]:focus-visible {',
    '  outline: 2px solid rgba(183,255,90,0.85);',
    '  outline-offset: 3px;',
    '  border-radius: 10px;',
    '}',
    '',
    '@media (prefers-reduced-motion: reduce) {',
    '  .cv-v2 * {',
    '    animation: none !important;',
    '    transition: none !important;',
    '    scroll-behavior: auto !important;',
    '  }',
    '}',
    ''
  ) -join "`n"

  $raw2 = $raw.TrimEnd() + "`n" + $block
  WriteUtf8NoBom $globals $raw2
  $actions.Add('globals.css: added CV2 tokens + base surfaces scoped to .cv-v2.')
}

# --- 2) criar layout.tsx no /v2 para aplicar .cv-v2 (sem tocar no V1)
$v2Layout = Join-Path $root 'src\app\c\[slug]\v2\layout.tsx'
if (Test-Path -LiteralPath $v2Layout) {
  $actions.Add('V2 layout: ja existe (nao alterei): ' + (Rel $root $v2Layout))
} else {
  EnsureDir (Split-Path -Parent $v2Layout)

  $lines = @(
    'import type { ReactNode } from "react";',
    '',
    'export default function V2Layout({ children }: { children: ReactNode }) {',
    '  return <div className="cv-v2">{children}</div>;',
    '}'
  )
  WriteUtf8NoBom $v2Layout ($lines -join "`n")
  $actions.Add('Created src/app/c/[slug]/v2/layout.tsx to wrap V2 with .cv-v2.')
}

# --- VERIFY
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

# --- REPORT (sem code fence)
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add('# CV — Step B5b: CV2 tokens + V2 layout wrapper')
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
  $rep.Add('- B5c: criar componente Card V2 (cv2-card) e padronizar Hub/Provas/Trilhas.')
} else {
  $rep.Add('- Corrigir verify e re-rodar.')
}

WriteUtf8NoBom $reportPath ($rep -join "`n")
Write-Host ('[OK] Report -> ' + $reportPath)
if ($OpenReport) { try { Start-Process $reportPath | Out-Null } catch {} }