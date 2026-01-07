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

function AddClassToLiteralClassName([string]$text, [string]$requiredClass, [string]$insertionClass) {
  # Só mexe em className="...." (string literal), e apenas quando achar requiredClass (ex: cv2-card).
  # Se insertionClass já existir no mesmo literal, não duplica.
  $pattern = 'className\s*=\s*"(.*?)"'
  return [regex]::Replace($text, $pattern, {
    param($m)
    $cls = $m.Groups[1].Value
    if (-not $cls.Contains($requiredClass)) { return $m.Value }
    if ($cls.Contains($insertionClass)) { return $m.Value }
    return 'className="' + ($cls.Trim() + ' ' + $insertionClass).Trim() + '"'
  })
}

$root = FindRepoRoot (Get-Location).Path
$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$step = 'cv-step-b5c-v2-card-and-unify-pages'

$reportsDir = Join-Path $root 'reports'
$backupDir  = Join-Path $root 'tools\_patch_backup'
EnsureDir $reportsDir
EnsureDir $backupDir

$reportPath = Join-Path $reportsDir ($step + '-' + $ts + '.md')

$actions = New-Object System.Collections.Generic.List[string]
$backups = New-Object System.Collections.Generic.List[string]

# 1) CSS: adicionar microinteracao padrao de card (escopado em .cv-v2)
$globals = Join-Path $root 'src\app\globals.css'
if (-not (Test-Path -LiteralPath $globals)) { throw ('globals.css nao encontrado: ' + $globals) }

$gRaw = ReadText $globals
$cssMarker = 'CV2 CARDS: interactive'
if ($gRaw.Contains($cssMarker)) {
  $actions.Add('globals.css: CV2 cards CSS ja existe (marker encontrado).')
} else {
  $bk = BackupFile $globals $backupDir
  $backups.Add((Split-Path -Leaf $bk))

  $css = @(
    '',
    '/* CV2 CARDS: interactive */',
    '.cv-v2 .cv2-cardInteractive {',
    '  display: block;',
    '  text-decoration: none;',
    '  padding: var(--cv2-pad);',
    '  transition: transform 120ms ease, border-color 120ms ease, box-shadow 120ms ease;',
    '}',
    '',
    '.cv-v2 .cv2-cardInteractive:hover {',
    '  transform: translateY(-1px);',
    '  border-color: rgba(183,255,90,0.30);',
    '  box-shadow: var(--cv2-shadow);',
    '}',
    '',
    '.cv-v2 .cv2-cardInteractive:active {',
    '  transform: translateY(0px);',
    '}',
    '',
    '.cv-v2 .cv2-cardTitle {',
    '  font-weight: 750;',
    '  letter-spacing: -0.02em;',
    '  line-height: 1.15;',
    '}',
    '',
    '.cv-v2 .cv2-cardDesc {',
    '  color: var(--cv2-muted);',
    '  line-height: 1.45;',
    '}',
    ''
  ) -join "`n"

  $gOut = $gRaw.TrimEnd() + "`n" + $css
  WriteUtf8NoBom $globals $gOut
  $actions.Add('globals.css: added CV2 interactive card microinteraction + title/desc styles.')
}

# 2) Criar componente reutilizavel Cv2Card
$cardComp = Join-Path $root 'src\components\v2\Cv2Card.tsx'
if (Test-Path -LiteralPath $cardComp) {
  $actions.Add('Cv2Card.tsx: ja existe (nao alterei).')
} else {
  EnsureDir (Split-Path -Parent $cardComp)

  $cardLines = @(
    'import Link from "next/link";',
    'import type { ReactNode } from "react";',
    '',
    'type Props = {',
    '  href: string;',
    '  title: string;',
    '  description?: string;',
    '  right?: ReactNode;',
    '  className?: string;',
    '};',
    '',
    'export function Cv2Card({ href, title, description, right, className }: Props) {',
    '  const cls = ["cv2-card", "cv2-cardInteractive", className].filter(Boolean).join(" ");',
    '  return (',
    '    <Link className={cls} href={href}>',
    '      <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", gap: "12px" }}>',
    '        <div>',
    '          <div className="cv2-cardTitle">{title}</div>',
    '          {description ? <div className="cv2-cardDesc" style={{ marginTop: "6px" }}>{description}</div> : null}',
    '        </div>',
    '        {right ? <div aria-hidden="true">{right}</div> : null}',
    '      </div>',
    '    </Link>',
    '  );',
    '}'
  )
  WriteUtf8NoBom $cardComp ($cardLines -join "`n")
  $actions.Add('Created src/components/v2/Cv2Card.tsx.')
}

# 3) Padronizar cards existentes: Hub/Provas/Trilhas
$targets = @(
  (Join-Path $root 'src\components\v2\HomeV2Hub.tsx'),
  (Join-Path $root 'src\components\v2\ProvasV2.tsx'),
  (Join-Path $root 'src\components\v2\TrilhasV2.tsx')
)

foreach ($t in $targets) {
  if (-not (Test-Path -LiteralPath $t)) {
    $actions.Add('WARN: nao encontrei (pulei): ' + (Rel $root $t))
    continue
  }

  $raw = ReadText $t
  $patched = $raw

  # Se ja tiver className literal com cv2-card, garante cv2-cardInteractive
  $patched = AddClassToLiteralClassName $patched 'cv2-card' 'cv2-cardInteractive'

  if ($patched -ne $raw) {
    $bk = BackupFile $t $backupDir
    $backups.Add((Split-Path -Leaf $bk))
    WriteUtf8NoBom $t $patched
    $actions.Add('Patched: ensured cv2-cardInteractive in ' + (Rel $root $t))
  } else {
    $actions.Add('No changes needed: ' + (Rel $root $t))
  }
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
$rep.Add('# CV — Step B5c: V2 card component + unify cards')
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
  $rep.Add('- B5d: Hub como mapa mental (nos + conectores) usando os mesmos cards.')
  $rep.Add('- B5e: teclado de verdade (setas/enter) no Hub e melhorias de aria-label onde faltar.')
} else {
  $rep.Add('- Corrigir verify e re-rodar.')
}

WriteUtf8NoBom $reportPath ($rep -join "`n")
Write-Host ('[OK] Report -> ' + $reportPath)
if ($OpenReport) { try { Start-Process $reportPath | Out-Null } catch {} }