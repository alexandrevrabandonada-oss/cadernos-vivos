# CV — V2 Tijolo Infra — Bootstrap + Guard + Verify (robusto) — v0_20
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
function WriteLinesUtf8NoBom([string]$path, [string[]]$lines) {
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
function ResolveExe($exe) {
  if ($exe -is [System.Management.Automation.CommandInfo]) { return $exe.Source }
  return [string]$exe
}
function RunCmd($exe, [string[]]$cmdArgs) {
  $exePath = ResolveExe $exe
  if ([string]::IsNullOrWhiteSpace($exePath)) { throw "[STOP] RunCmd: exe vazio/nulo." }
  if (-not $cmdArgs -or $cmdArgs.Count -eq 0) { throw "[STOP] RunCmd: sem args." }

  Write-Host ("[RUN] " + $exePath + " " + ($cmdArgs -join " "))
  & $exePath @cmdArgs
  if ($LASTEXITCODE -ne 0) {
    throw ("[STOP] falhou (exit " + $LASTEXITCODE + "): " + $exePath + " " + ($cmdArgs -join " "))
  }
}
function GetNpmCmd() {
  $c = Get-Command "npm.cmd" -ErrorAction SilentlyContinue
  if ($c) { return $c.Source }
  return "npm.cmd"
}
function WriteReport([string]$name, [string]$text) {
  $reports = Join-Path (Get-Location) "reports"
  EnsureDir $reports
  $p = Join-Path $reports $name
  WriteUtf8NoBom $p $text
  Write-Host ("[OK] Report: " + $p)
  return $p
}

$repo  = Get-Location
$tools = Join-Path $repo "tools"
EnsureDir $tools

Write-Host ("[DIAG] Repo: " + $repo)

# 1) tools/_bootstrap.ps1
$bootstrapPath = Join-Path $tools "_bootstrap.ps1"
$bkBoot = BackupFile $bootstrapPath

$bootLines = @(
  'Set-StrictMode -Version Latest'
  '$ErrorActionPreference = ''Stop'''
  ''
  'function EnsureDir([string]$p) {'
  '  if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }'
  '}'
  ''
  'function WriteUtf8NoBom([string]$path, [string]$text) {'
  '  EnsureDir (Split-Path -Parent $path)'
  '  $enc = New-Object System.Text.UTF8Encoding($false)'
  '  [System.IO.File]::WriteAllText($path, $text, $enc)'
  '}'
  ''
  'function WriteLinesUtf8NoBom([string]$path, [string[]]$lines) {'
  '  WriteUtf8NoBom $path ($lines -join "`n")'
  '}'
  ''
  'function BackupFile([string]$path) {'
  '  if (-not (Test-Path -LiteralPath $path)) { return $null }'
  '  $bkRoot = Join-Path (Get-Location) ''tools\_patch_backup'''
  '  EnsureDir $bkRoot'
  '  $stamp = (Get-Date).ToString(''yyyyMMdd-HHmmss'')'
  '  $name = (Split-Path -Leaf $path)'
  '  if ($name -match ''\.tsx?$'') { $name = $name + ''.bak'' }'
  '  $dest = Join-Path $bkRoot ($stamp + ''-'' + $name)'
  '  Copy-Item -LiteralPath $path -Destination $dest -Force'
  '  return $dest'
  '}'
  ''
  'function ResolveExe($exe) {'
  '  if ($exe -is [System.Management.Automation.CommandInfo]) { return $exe.Source }'
  '  return [string]$exe'
  '}'
  ''
  'function RunCmd($exe, [string[]]$cmdArgs) {'
  '  $exePath = ResolveExe $exe'
  '  if ([string]::IsNullOrWhiteSpace($exePath)) { throw ''[STOP] RunCmd: exe vazio/nulo.'' }'
  '  if (-not $cmdArgs -or $cmdArgs.Count -eq 0) { throw ''[STOP] RunCmd: sem args.'' }'
  '  Write-Host (''[RUN] '' + $exePath + '' '' + ($cmdArgs -join '' ''))'
  '  & $exePath @cmdArgs'
  '  if ($LASTEXITCODE -ne 0) { throw (''[STOP] falhou (exit '' + $LASTEXITCODE + ''): '' + $exePath + '' '' + ($cmdArgs -join '' '')) }'
  '}'
  ''
  'function GetNpmCmd() {'
  '  $c = Get-Command ''npm.cmd'' -ErrorAction SilentlyContinue'
  '  if ($c) { return $c.Source }'
  '  return ''npm.cmd'''
  '}'
  ''
  'function WriteReport([string]$name, [string]$text) {'
  '  $reports = Join-Path (Get-Location) ''reports'''
  '  EnsureDir $reports'
  '  $p = Join-Path $reports $name'
  '  WriteUtf8NoBom $p $text'
  '  Write-Host (''[OK] Report: '' + $p)'
  '  return $p'
  '}'
)

WriteLinesUtf8NoBom $bootstrapPath $bootLines
Write-Host ("[OK] wrote: " + $bootstrapPath)
if ($bkBoot) { Write-Host ("[BK] " + $bkBoot) }

# 2) tools/cv-guard-v2.ps1  (sem regex frágil: check por linha)
$guardPath = Join-Path $tools "cv-guard-v2.ps1"
$bkGuard = BackupFile $guardPath

$guardLines = @(
  '# CV — Guard V2 (anti-href regex + anti-import backslash)'
  '$ErrorActionPreference = ''Stop'''
  '. "$PSScriptRoot/_bootstrap.ps1"'
  ''
  '$repo = Get-Location'
  '$src  = Join-Path $repo ''src'''
  'if (-not (Test-Path -LiteralPath $src)) { throw (''[STOP] não achei src/: '' + $src) }'
  ''
  '$files = Get-ChildItem -LiteralPath $src -Recurse -File -Include *.ts,*.tsx'
  '$hits = @()'
  ''
  'foreach ($f in $files) {'
  '  $lines = Get-Content -LiteralPath $f.FullName'
  '  $i = 0'
  '  foreach ($ln in $lines) {'
  '    $i++'
  '    # 1) href regex/divisão em TSX (href={/c//v2...})'
  '    if ($ln -like ''*href={/c//*'') {'
  '      $hits += (''[href-regex] '' + $f.FullName + '':'' + $i + '' — Use href={"/c/" + slug + "..."} (string), nunca regex.'')'
  '      continue'
  '    }'
  '    # 2) import com backslash no module specifier (somente linhas com from "..." / from ''...'')'
  '    if (($ln -match ''\bfrom\s+["'']'') -and $ln.Contains(''@/'') -and $ln.Contains(''\'')) {'
  '      $hits += (''[import-backslash] '' + $f.FullName + '':'' + $i + '' — Use forward slash: "@/components/v2/V2Nav".'')'
  '      continue'
  '    }'
  '  }'
  '}'
  ''
  'if ($hits.Count -gt 0) {'
  '  Write-Host ''[STOP] Guard V2 falhou. Ocorrências:'''
  '  foreach ($h in $hits) { Write-Host ('' - '' + $h) }'
  '  throw ''[STOP] Corrija as ocorrências acima.'''
  '}'
  ''
  'Write-Host ''[OK] Guard V2 passou.'''
)

WriteLinesUtf8NoBom $guardPath $guardLines
Write-Host ("[OK] wrote: " + $guardPath)
if ($bkGuard) { Write-Host ("[BK] " + $bkGuard) }

# 3) tools/cv-verify.ps1
$verifyPath = Join-Path $tools "cv-verify.ps1"
$bkVerify = BackupFile $verifyPath

$verifyLines = @(
  '# CV — Verify (Guard → Lint → Build)'
  '$ErrorActionPreference = ''Stop'''
  '. "$PSScriptRoot/_bootstrap.ps1"'
  ''
  '& (Join-Path $PSScriptRoot ''cv-guard-v2.ps1'')'
  ''
  '$npm = GetNpmCmd'
  'RunCmd $npm @(''run'',''lint'')'
  'RunCmd $npm @(''run'',''build'')'
  ''
  'Write-Host ''[OK] verify OK (guard+lint+build).'''
)

WriteLinesUtf8NoBom $verifyPath $verifyLines
Write-Host ("[OK] wrote: " + $verifyPath)
if ($bkVerify) { Write-Host ("[BK] " + $bkVerify) }

# 4) VERIFY agora
Write-Host "[RUN] tools/cv-verify.ps1"
& $verifyPath

# 5) REPORT
$report = @(
  '# CV — Tijolo Infra v0_20 — Bootstrap + Guard + Verify'
  ''
  '## O que mudou'
  '- tools/_bootstrap.ps1: funções base (EnsureDir/WriteUtf8NoBom/BackupFile/RunCmd/GetNpmCmd/WriteReport).'
  '- tools/cv-guard-v2.ps1: trava se aparecer:'
  '  - href={/c//...} (regex/divisão em TSX)'
  '  - import com backslash em module specifier (ex: "@/components/v2\V2Nav")'
  '- tools/cv-verify.ps1: roda Guard → npm run lint → npm run build.'
  ''
  '## Como usar daqui pra frente'
  '- pwsh -NoProfile -ExecutionPolicy Bypass -File tools/cv-verify.ps1'
  ''
  '## Status'
  '- verify: OK'
) -join "`n"

WriteReport "cv-infra-bootstrap-guards-v0_20.md" $report | Out-Null
Write-Host "[OK] v0_20 aplicado."