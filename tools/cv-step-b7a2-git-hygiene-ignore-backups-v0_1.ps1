# cv-step-b7a2-git-hygiene-ignore-backups-v0_1
$ErrorActionPreference = "Stop"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$repoRoot = (Resolve-Path ".").Path
$nl = [Environment]::NewLine

function EnsureDir([string]$abs) { if (-not (Test-Path -LiteralPath $abs)) { [IO.Directory]::CreateDirectory($abs) | Out-Null } }
function ReadText([string]$abs) { if (-not (Test-Path -LiteralPath $abs)) { return $null }; return [IO.File]::ReadAllText($abs) }
function WriteText([string]$abs, [string]$text) {
  $enc = New-Object System.Text.UTF8Encoding($false)
  EnsureDir (Split-Path -Parent $abs)
  [IO.File]::WriteAllText($abs, $text, $enc)
}
function BackupFile([string]$rel) {
  $abs = Join-Path $repoRoot $rel
  if (-not (Test-Path -LiteralPath $abs)) { return }
  $bkDir = Join-Path $repoRoot 'tools\_patch_backup'
  EnsureDir $bkDir
  $dst = Join-Path $bkDir ($stamp + '-' + (Split-Path -Leaf $abs) + '.bak')
  Copy-Item -LiteralPath $abs -Destination $dst -Force
}

EnsureDir (Join-Path $repoRoot 'reports')
EnsureDir (Join-Path $repoRoot 'tools\_patch_backup')

$rep = Join-Path $repoRoot ('reports\' + $stamp + '-cv-step-b7a2-git-hygiene-ignore-backups.md')
$r = New-Object System.Collections.Generic.List[string]
$r.Add('# Tijolo B7A2 — Git hygiene (ignore backups) — ' + $stamp) | Out-Null
$r.Add('') | Out-Null
$r.Add('Repo: ' + $repoRoot) | Out-Null
$r.Add('') | Out-Null

$r.Add('## DIAG (pre)') | Out-Null
$r.Add('') | Out-Null
try { $r.Add((git status | Out-String).TrimEnd()) | Out-Null } catch { $r.Add('ERR: git status') | Out-Null }
$r.Add('') | Out-Null

$giRel = '.gitignore'
$giAbs = Join-Path $repoRoot $giRel
$raw = ReadText $giAbs
if ($null -eq $raw) { $raw = '' }

$marker = '# CV — ignore patch backups'
$block = @(
  '',
  $marker,
  'tools/_patch_backup/',
  'tools/_patch_backup/**'
) -join $nl

$r.Add('## PATCH') | Out-Null
$r.Add('') | Out-Null

if ($raw -match [regex]::Escape($marker)) {
  $r.Add('- skip: .gitignore já tem bloco CV — ignore patch backups') | Out-Null
} else {
  BackupFile $giRel
  $out = $raw.TrimEnd() + $block + $nl
  WriteText $giAbs $out
  $r.Add('- updated: .gitignore (added ignore for tools/_patch_backup/)') | Out-Null
}
$r.Add('') | Out-Null

$r.Add('## DIAG (post)') | Out-Null
$r.Add('') | Out-Null
try { $r.Add((git status | Out-String).TrimEnd()) | Out-Null } catch { $r.Add('ERR: git status') | Out-Null }
$r.Add('') | Out-Null

WriteText $rep ([string]::Join($nl, $r.ToArray()) + $nl)
Write-Host ('[REPORT] ' + $rep)
Write-Host '[OK] B7A2 finalizado.'