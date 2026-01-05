# CV — V2 Tijolo Infra — Bootstrap + Guards + Verify — v0_19c
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

function EnsureDir([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}
function WriteUtf8NoBom([string]$path, [string]$text) {
  EnsureDir (Split-Path -Parent $path)
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($path, $text, $enc)
}
function WriteLines([string]$path, [string[]]$lines) {
  WriteUtf8NoBom $path ($lines -join "`n")
}
function BackupFile([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) { return $null }
  $bkRoot = Join-Path (Get-Location) "tools\_patch_backup"
  EnsureDir $bkRoot
  $stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
  $name = (Split-Path -Leaf $path)
  if ($name -match '\.tsx?$') { $name = $name + ".bak" }
  $dest = Join-Path $bkRoot ($stamp + "-" + $name)
  Copy-Item -LiteralPath $path -Destination $dest -Force
  return $dest
}

$repo  = Get-Location
$tools = Join-Path $repo "tools"
EnsureDir $tools
Write-Host ("[DIAG] Repo: " + $repo)

# --- 1) tools/_bootstrap.ps1 ---
$bootstrapPath = Join-Path $tools "_bootstrap.ps1"
$bkBoot = BackupFile $bootstrapPath

$bootstrapLines = @(
  'Set-StrictMode -Version Latest',
  '$ErrorActionPreference = ''Stop''',
  '',
  'function EnsureDir([string]$p) {',
  '  if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }',
  '}',
  '',
  'function WriteUtf8NoBom([string]$path, [string]$text) {',
  '  EnsureDir (Split-Path -Parent $path)',
  '  $enc = New-Object System.Text.UTF8Encoding($false)',
  '  [System.IO.File]::WriteAllText($path, $text, $enc)',
  '}',
  '',
  'function WriteLinesUtf8NoBom([string]$path, [string[]]$lines) {',
  '  WriteUtf8NoBom $path ($lines -join "`n")',
  '}',
  '',
  'function BackupFile([string]$path) {',
  '  if (-not (Test-Path -LiteralPath $path)) { return $null }',
  '  $bkRoot = Join-Path (Get-Location) ''tools\_patch_backup''',
  '  EnsureDir $bkRoot',
  '  $stamp = (Get-Date).ToString(''yyyyMMdd-HHmmss'')',
  '  $name = (Split-Path -Leaf $path)',
  '  if ($name -match ''\.tsx?$'') { $name = $name + ''.bak'' }',
  '  $dest = Join-Path $bkRoot ($stamp + ''-'' + $name)',
  '  Copy-Item -LiteralPath $path -Destination $dest -Force',
  '  return $dest',
  '}',
  '',
  'function ResolveExe($exe) {',
  '  if ($exe -is [System.Management.Automation.CommandInfo]) { return $exe.Source }',
  '  return [string]$exe',
  '}',
  '',
  '# IMPORTANTE: não use param nomeado $args (conflita com automatic var $args)',
  'function RunCmd($exe, [string[]]$cmdArgs) {',
  '  $exePath = ResolveExe $exe',
  '  if ([string]::IsNullOrWhiteSpace($exePath)) { throw ''[STOP] RunCmd: exe vazio/nulo.'' }',
  '  if (-not $cmdArgs -or $cmdArgs.Count -eq 0) { throw ''[STOP] RunCmd: sem args.'' }',
  '  Write-Host (''[RUN] '' + $exePath + '' '' + ($cmdArgs -join '' ''))',
  '  & $exePath @cmdArgs',
  '  if ($LASTEXITCODE -ne 0) {',
  '    throw (''[STOP] falhou (exit '' + $LASTEXITCODE + ''): '' + $exePath + '' '' + ($cmdArgs -join '' ''))',
  '  }',
  '}',
  '',
  'function GetNpmCmd() {',
  '  $c = Get-Command ''npm.cmd'' -ErrorAction SilentlyContinue',
  '  if ($c) { return $c.Source }',
  '  return ''npm.cmd''',
  '}',
  '',
  'function WriteReport([string]$name, [string]$text) {',
  '  $reports = Join-Path (Get-Location) ''reports''',
  '  EnsureDir $reports',
  '  $path = Join-Path $reports $name',
  '  WriteUtf8NoBom $path $text',
  '  Write-Host (''[OK] Report: '' + $path)',
  '  return $path',
  '}'
)

WriteLines $bootstrapPath $bootstrapLines
Write-Host ("[OK] wrote: " + $bootstrapPath)
if ($bkBoot) { Write-Host ("[BK] " + $bkBoot) }

# carrega bootstrap pra usar RunCmd/WriteReport
. $bootstrapPath

# --- 2) tools/cv-guard-v2.ps1 ---
$guardPath = Join-Path $tools "cv-guard-v2.ps1"
$bkGuard = BackupFile $guardPath

$guardLines = @(
  '# CV — Guard V2 (anti-regex href + anti-import backslash)',
  '$ErrorActionPreference = ''Stop''',
  '. "$PSScriptRoot/_bootstrap.ps1"',
  '',
  '$repo = Get-Location',
  '$src  = Join-Path $repo ''src''',
  'if (-not (Test-Path -LiteralPath $src)) { throw (''[STOP] não achei src/: '' + $src) }',
  '',
  '$patterns = @(',
  '  @{ Name = ''href-regex''; Regex = ''href=\{\/c\/\/''; Hint = ''Use href={"/c/" + slug + "..."} (string), nunca regex.'' },',
  '  @{ Name = ''import-backslash-dq''; Regex = ''from\s+"@\/[^"\r\n]*\\''; Hint = ''Use forward slash em module specifier: "@/components/v2/V2Nav".'' },',
  '  @{ Name = ''import-backslash-sq''; Regex = "from\s+''@\/[^''\r\n]*\\"; Hint = ''Use forward slash em module specifier: "@/components/v2/V2Nav".'' }',
  ')',
  '',
  '$hits = @()',
  '$files = Get-ChildItem -LiteralPath $src -Recurse -File -Include *.ts,*.tsx',
  'foreach ($f in $files) {',
  '  $t = Get-Content -LiteralPath $f.FullName -Raw',
  '  foreach ($p in $patterns) {',
  '    if ($t -match $p.Regex) {',
  '      $hits += (''['' + $p.Name + ''] '' + $f.FullName + '' — '' + $p.Hint)',
  '      break',
  '    }',
  '  }',
  '}',
  '',
  'if ($hits.Count -gt 0) {',
  '  Write-Host ''[STOP] Guard V2 falhou. Ocorrências:''',
  '  foreach ($h in $hits) { Write-Host ('' - '' + $h) }',
  '  throw ''[STOP] Corrija as ocorrências acima.''',
  '}',
  '',
  'Write-Host ''[OK] Guard V2 passou.'''
)

WriteLines $guardPath $guardLines
Write-Host ("[OK] wrote: " + $guardPath)
if ($bkGuard) { Write-Host ("[BK] " + $bkGuard) }

# --- 3) tools/cv-verify.ps1 ---
$verifyPath = Join-Path $tools "cv-verify.ps1"
$bkVerify = BackupFile $verifyPath

$verifyLines = @(
  '# CV — Verify (Guard → Lint → Build)',
  '$ErrorActionPreference = ''Stop''',
  '. "$PSScriptRoot/_bootstrap.ps1"',
  '',
  '& (Join-Path $PSScriptRoot ''cv-guard-v2.ps1'')',
  '',
  '$npm = GetNpmCmd',
  'RunCmd $npm @(''run'',''lint'')',
  'RunCmd $npm @(''run'',''build'')',
  '',
  'Write-Host ''[OK] verify OK (guard+lint+build).'''
)

WriteLines $verifyPath $verifyLines
Write-Host ("[OK] wrote: " + $verifyPath)
if ($bkVerify) { Write-Host ("[BK] " + $bkVerify) }

# --- 4) VERIFY agora ---
& $verifyPath

# --- 5) REPORT ---
$reportText = @(
  '# CV — Tijolo Infra v0_19c — Bootstrap + Guards + Verify',
  '',
  '## O que mudou',
  '- tools/_bootstrap.ps1: RunCmd robusto (sem param $args), ResolveExe, GetNpmCmd, WriteReport.',
  '- tools/cv-guard-v2.ps1: trava se aparecer:',
  '  - href={/c//...} (regex/divisão em TSX)',
  '  - import com backslash em module specifier (ex: "@/components/v2\V2Nav")',
  '- tools/cv-verify.ps1: roda Guard → npm run lint → npm run build.',
  '',
  '## Como usar',
  '- pwsh -NoProfile -ExecutionPolicy Bypass -File tools/cv-verify.ps1',
  ''
) -join "`n"

WriteReport "cv-infra-bootstrap-guards-v0_19c.md" $reportText | Out-Null
Write-Host "[OK] v0_19c aplicado."