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

function BackupFile([string]$filePath, [string]$backupDir, [string]$tag) {
  EnsureDir $backupDir
  $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
  $name = Split-Path -Leaf $filePath
  $safeTag = ($tag -replace '[^a-zA-Z0-9_\-]','_')
  $dest = Join-Path $backupDir ($ts + '-' + $safeTag + '-' + $name + '.bak')
  Copy-Item -LiteralPath $filePath -Destination $dest -Force
  return $dest
}

$root = FindRepoRoot (Get-Location).Path
$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$step = 'cv-step-b5f3-fix-loading-multiline-mode'

$reportsDir = Join-Path $root 'reports'
$backupDir  = Join-Path $root 'tools\_patch_backup'
EnsureDir $reportsDir
EnsureDir $backupDir

$reportPath = Join-Path $reportsDir ($step + '-' + $ts + '.md')

$actions = New-Object System.Collections.Generic.List[string]
$backups = New-Object System.Collections.Generic.List[string]

$rels = @(
  'src\app\c\[slug]\v2\loading.tsx',
  'src\app\c\[slug]\v2\trilhas\loading.tsx',
  'src\app\c\[slug]\v2\trilhas\[id]\loading.tsx',
  'src\app\c\[slug]\v2\provas\loading.tsx'
)

foreach ($rel in $rels) {
  $p = Join-Path $root $rel
  if (-not (Test-Path -LiteralPath $p)) {
    $actions.Add('SKIP (not found): ' + $rel)
    continue
  }

  $raw = ReadText $p
  $patched = $raw

  # Colapsa: mode="   hub   " (com \s pegando quebras de linha)
  $patched = [regex]::Replace($patched, 'mode="\s*(hub|list)\s*"', 'mode="$1"')

  # Normaliza count={ 6 } (se alguém quebrou em várias linhas)
  $patched = [regex]::Replace($patched, 'count=\{\s*(\d+)\s*\}', 'count={$1}')

  if ($patched -ne $raw) {
    $bk = BackupFile $p $backupDir ($rel -replace '\\','_')
    $backups.Add((Split-Path -Leaf $bk))
    WriteUtf8NoBom $p $patched
    $actions.Add('Fixed multiline props in: ' + $rel)
  } else {
    $actions.Add('No changes needed: ' + $rel)
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
$rep.Add('# CV — Step B5f3: fix loading.tsx multiline mode/count')
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