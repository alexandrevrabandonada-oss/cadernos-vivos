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

$root = FindRepoRoot (Get-Location).Path
$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$step = 'cv-step-b5e1-fix-keynav-no-any'

$reportsDir = Join-Path $root 'reports'
$backupDir  = Join-Path $root 'tools\_patch_backup'
EnsureDir $reportsDir
EnsureDir $backupDir

$reportPath = Join-Path $reportsDir ($step + '-' + $ts + '.md')

$actions = New-Object System.Collections.Generic.List[string]
$backups = New-Object System.Collections.Generic.List[string]

$target = Join-Path $root 'src\components\v2\Cv2HubKeyNavClient.tsx'
if (-not (Test-Path -LiteralPath $target)) { throw ('target nao encontrado: ' + $target) }

$raw = ReadText $target
$patched = $raw

# remove "as any" (sem mudar logica)
$patched = [regex]::Replace($patched, 'root\.addEventListener\("focusin",\s*onFocusIn\s+as\s+any\);', 'root.addEventListener("focusin", onFocusIn);')
$patched = [regex]::Replace($patched, 'root\.addEventListener\("keydown",\s*onKeyDown\s+as\s+any\);', 'root.addEventListener("keydown", onKeyDown);')
$patched = [regex]::Replace($patched, 'root\.removeEventListener\("focusin",\s*onFocusIn\s+as\s+any\);', 'root.removeEventListener("focusin", onFocusIn);')
$patched = [regex]::Replace($patched, 'root\.removeEventListener\("keydown",\s*onKeyDown\s+as\s+any\);', 'root.removeEventListener("keydown", onKeyDown);')

if ($patched -ne $raw) {
  $bk = BackupFile $target $backupDir
  $backups.Add((Split-Path -Leaf $bk))
  WriteUtf8NoBom $target $patched
  $actions.Add('Patched Cv2HubKeyNavClient.tsx: removed explicit any casts in add/removeEventListener.')
} else {
  $actions.Add('No changes needed: patterns not found (file may already be fixed).')
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
$rep.Add('# CV — Step B5e1: fix lint (no-explicit-any) in hub keynav')
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

WriteUtf8NoBom $reportPath ($rep -join "`n")
Write-Host ('[OK] Report -> ' + $reportPath)
if ($OpenReport) { try { Start-Process $reportPath | Out-Null } catch {} }