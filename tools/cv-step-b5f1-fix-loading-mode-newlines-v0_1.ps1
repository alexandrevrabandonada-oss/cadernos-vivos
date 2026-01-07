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

function CanonLoading([string]$title, [int]$count, [string]$mode) {
  $lines = @(
    'import { Cv2SkelScreen } from "@/components/v2/Cv2Skeleton";',
    '',
    'export default function Loading() {',
    '  return <Cv2SkelScreen title="' + $title + '" count={' + $count + '} mode="' + $mode + '" />;',
    '}',
    ''
  )
  return ($lines -join "`n")
}

$root = FindRepoRoot (Get-Location).Path
$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$step = 'cv-step-b5f1-fix-loading-mode-newlines'

$reportsDir = Join-Path $root 'reports'
$backupDir  = Join-Path $root 'tools\_patch_backup'
EnsureDir $reportsDir
EnsureDir $backupDir

$reportPath = Join-Path $reportsDir ($step + '-' + $ts + '.md')

$actions = New-Object System.Collections.Generic.List[string]
$backups = New-Object System.Collections.Generic.List[string]

$targets = @(
  @{ path = (Join-Path $root 'src\app\c\[slug]\v2\loading.tsx'); title='Carregando hub…'; count=6; mode='hub' },
  @{ path = (Join-Path $root 'src\app\c\[slug]\v2\trilhas\loading.tsx'); title='Carregando trilhas…'; count=6; mode='list' },
  @{ path = (Join-Path $root 'src\app\c\[slug]\v2\trilhas\[id]\loading.tsx'); title='Carregando trilha…'; count=5; mode='list' },
  @{ path = (Join-Path $root 'src\app\c\[slug]\v2\provas\loading.tsx'); title='Carregando provas…'; count=6; mode='list' }
)

foreach ($t in $targets) {
  $p = $t.path
  if (-not (Test-Path -LiteralPath $p)) {
    $actions.Add('SKIP (not found): ' + (Rel $root $p))
    continue
  }

  $raw = ReadText $p
  $canon = CanonLoading $t.title ([int]$t.count) ([string]$t.mode)

  if ($raw -ne $canon) {
    $bk = BackupFile $p $backupDir
    $backups.Add((Split-Path -Leaf $bk))
    WriteUtf8NoBom $p $canon
    $actions.Add('Rewrote canonical loading.tsx: ' + (Rel $root $p))
  } else {
    $actions.Add('OK already canonical: ' + (Rel $root $p))
  }
}

# VERIFY
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

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add('# CV — Step B5f1: fix loading.tsx mode/count newlines')
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

WriteUtf8NoBom $reportPath ($rep -join "`n")
Write-Host ('[OK] Report -> ' + $reportPath)
if ($OpenReport) { try { Start-Process $reportPath | Out-Null } catch {} }