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
function ReadText([string]$p) { return [IO.File]::ReadAllText($p, [Text.UTF8Encoding]::new($false)) }

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
$step = 'cv-step-b5f-skeletons-and-loading'

$reportsDir = Join-Path $root 'reports'
$backupDir  = Join-Path $root 'tools\_patch_backup'
EnsureDir $reportsDir
EnsureDir $backupDir

$reportPath = Join-Path $reportsDir ($step + '-' + $ts + '.md')

$actions = New-Object System.Collections.Generic.List[string]
$backups = New-Object System.Collections.Generic.List[string]

# 1) CSS: skeleton shimmer (escopado em .cv-v2)
$globals = Join-Path $root 'src\app\globals.css'
if (-not (Test-Path -LiteralPath $globals)) { throw ('globals.css nao encontrado: ' + $globals) }

$gRaw = ReadText $globals
$cssMarker = 'CV2 SKELETONS: shimmer'
if ($gRaw.Contains($cssMarker)) {
  $actions.Add('globals.css: skeleton CSS ja existe (marker encontrado).')
} else {
  $bk = BackupFile $globals $backupDir
  $backups.Add((Split-Path -Leaf $bk))

  $css = @(
    '',
    '/* CV2 SKELETONS: shimmer */',
    '.cv-v2 .cv2-skel {',
    '  position: relative;',
    '  overflow: hidden;',
    '  border-radius: var(--cv2-radius-lg);',
    '  border: 1px solid var(--cv2-border);',
    '  background: rgba(255,255,255,0.06);',
    '}',
    '',
    '.cv-v2 .cv2-skel::after {',
    '  content: "";',
    '  position: absolute;',
    '  inset: 0;',
    '  transform: translateX(-60%);',
    '  background: linear-gradient(90deg, transparent 0%, rgba(255,255,255,0.08) 35%, rgba(183,255,90,0.10) 50%, rgba(255,255,255,0.08) 65%, transparent 100%);',
    '  animation: cv2Shimmer 1.25s ease-in-out infinite;',
    '}',
    '',
    '@keyframes cv2Shimmer {',
    '  0% { transform: translateX(-60%); }',
    '  100% { transform: translateX(60%); }',
    '}',
    '',
    '.cv-v2 .cv2-skelLine {',
    '  height: 12px;',
    '  border-radius: 999px;',
    '  background: rgba(255,255,255,0.08);',
    '  border: 1px solid rgba(255,255,255,0.06);',
    '}',
    '',
    '.cv-v2 .cv2-skelLine.sm { height: 10px; opacity: 0.9; }',
    '.cv-v2 .cv2-skelLine.lg { height: 14px; }',
    '',
    '.cv-v2 .cv2-skelStack {',
    '  display: flex;',
    '  flex-direction: column;',
    '  gap: 10px;',
    '}',
    '',
    '.cv-v2 .cv2-skelPad { padding: var(--cv2-pad); }',
    '',
    '@media (prefers-reduced-motion: reduce) {',
    '  .cv-v2 .cv2-skel::after {',
    '    animation: none !important;',
    '    transform: none !important;',
    '    opacity: 0.25;',
    '  }',
    '}',
    ''
  ) -join "`n"

  WriteUtf8NoBom $globals ($gRaw.TrimEnd() + "`n" + $css)
  $actions.Add('globals.css: added CV2 skeleton shimmer + lines (scoped to .cv-v2).')
}

# 2) Component: Cv2Skeleton.tsx
$skelComp = Join-Path $root 'src\components\v2\Cv2Skeleton.tsx'
if (Test-Path -LiteralPath $skelComp) {
  $actions.Add('Cv2Skeleton.tsx: ja existe (nao alterei).')
} else {
  EnsureDir (Split-Path -Parent $skelComp)

  $lines = @(
    'type SkelCardProps = {',
    '  className?: string;',
    '  lines?: number;',
    '};',
    '',
    'export function Cv2SkelCard({ className, lines = 3 }: SkelCardProps) {',
    '  const cls = ["cv2-card", "cv2-skel", "cv2-skelPad", className].filter(Boolean).join(" ");',
    '  const items = Array.from({ length: lines }).map((_, i) => i);',
    '  return (',
    '    <div className={cls} aria-hidden="true">', # skeleton visual only
    '      <div className="cv2-skelStack">',
    '        <div className="cv2-skelLine lg" style={{ width: "70%" }} />',
    '        {items.map((i) => (',
    '          <div key={i} className={"cv2-skelLine" + (i === items.length - 1 ? " sm" : "")} style={{ width: i === items.length - 1 ? "55%" : "88%" }} />',
    '        ))}',
    '      </div>',
    '    </div>',
    '  );',
    '}',
    '',
    'type ScreenProps = {',
    '  title?: string;',
    '  count?: number;',
    '  mode?: "hub" | "list";',
    '};',
    '',
    'export function Cv2SkelScreen({ title = "Carregando…", count = 5, mode = "list" }: ScreenProps) {',
    '  const items = Array.from({ length: count }).map((_, i) => i);',
    '  const wrapCls = mode === "hub" ? "cv2-hubMap" : "";',
    '  const wrapAttr = mode === "hub" ? { "data-cv2-hub": "map" as const } : {};',
    '  return (',
    '    <div className={wrapCls} {...wrapAttr} role="status" aria-live="polite" aria-busy="true">',
    '      <div className="cv2-muted" style={{ marginBottom: "12px" }}>{title}</div>',
    '      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(240px, 1fr))", gap: "14px" }}>',
    '        {items.map((i) => (',
    '          <Cv2SkelCard key={i} />',
    '        ))}',
    '      </div>',
    '    </div>',
    '  );',
    '}'
  )

  WriteUtf8NoBom $skelComp ($lines -join "`n")
  $actions.Add('Created src/components/v2/Cv2Skeleton.tsx (SkelCard + SkelScreen).')
}

# 3) loading.tsx files (Hub/Trilhas/Provas + trilhas/[id])
$loadingFiles = @(
  @{ path = (Join-Path $root 'src\app\c\[slug]\v2\loading.tsx'); kind='hub' },
  @{ path = (Join-Path $root 'src\app\c\[slug]\v2\trilhas\loading.tsx'); kind='list' },
  @{ path = (Join-Path $root 'src\app\c\[slug]\v2\trilhas\[id]\loading.tsx'); kind='list' },
  @{ path = (Join-Path $root 'src\app\c\[slug]\v2\provas\loading.tsx'); kind='list' }
)

foreach ($f in $loadingFiles) {
  $p = $f.path
  $kind = $f.kind

  if (Test-Path -LiteralPath $p) {
    $actions.Add('loading.tsx: ja existe (pulei): ' + (Rel $root $p))
    continue
  }

  EnsureDir (Split-Path -Parent $p)

  $title = 'Carregando…'
  $count = 5
  $mode = 'list'
  if ($kind -eq 'hub') { $title = 'Carregando hub…'; $count = 6; $mode = 'hub' }
  if ($p -like '*\provas\loading.tsx') { $title = 'Carregando provas…'; $count = 6; $mode = 'list' }
  if ($p -like '*\trilhas\loading.tsx') { $title = 'Carregando trilhas…'; $count = 6; $mode = 'list' }
  if ($p -like '*\trilhas\[id]\loading.tsx') { $title = 'Carregando trilha…'; $count = 5; $mode = 'list' }

  $fileLines = @(
    'import { Cv2SkelScreen } from "@/components/v2/Cv2Skeleton";',
    '',
    'export default function Loading() {',
    '  return <Cv2SkelScreen title="' + $title + '" count={' + $count + '} mode="' + $mode + '" />;',
    '}'
  )

  WriteUtf8NoBom $p ($fileLines -join "`n")
  $actions.Add('Created ' + (Rel $root $p))
}

# 4) VERIFY
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

# 5) REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add('# CV — Step B5f: skeletons + loading.tsx (V2)')
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
  $rep.Add('- Commit do bloco B5 (B5b..B5f).')
  $rep.Add('- Proximo: B6 (polimento visual e mapas interativos V2).')
} else {
  $rep.Add('- Corrigir verify e re-rodar.')
}

WriteUtf8NoBom $reportPath ($rep -join "`n")
Write-Host ('[OK] Report -> ' + $reportPath)
if ($OpenReport) { try { Start-Process $reportPath | Out-Null } catch {} }