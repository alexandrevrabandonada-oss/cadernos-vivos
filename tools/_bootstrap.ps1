Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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
  $bkRoot = Join-Path (Get-Location) 'tools\_patch_backup'
  EnsureDir $bkRoot
  $stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
  $name = (Split-Path -Leaf $path)
  if ($name -match '\.tsx?$') { $name = $name + '.bak' }
  $dest = Join-Path $bkRoot ($stamp + '-' + $name)
  Copy-Item -LiteralPath $path -Destination $dest -Force
  return $dest
}

function ResolveExe($exe) {
  if ($exe -is [System.Management.Automation.CommandInfo]) { return $exe.Source }
  return [string]$exe
}

function RunCmd($exe, [string[]]$cmdArgs) {
  $exePath = ResolveExe $exe
  if ([string]::IsNullOrWhiteSpace($exePath)) { throw '[STOP] RunCmd: exe vazio/nulo.' }
  if (-not $cmdArgs -or $cmdArgs.Count -eq 0) { throw '[STOP] RunCmd: sem args.' }
  Write-Host ('[RUN] ' + $exePath + ' ' + ($cmdArgs -join ' '))
  & $exePath @cmdArgs
  if ($LASTEXITCODE -ne 0) { throw ('[STOP] falhou (exit ' + $LASTEXITCODE + '): ' + $exePath + ' ' + ($cmdArgs -join ' ')) }
}


function GetPwshExe() {
  $c = Get-Command 'pwsh.exe' -ErrorAction SilentlyContinue
  if ($c) { return $c.Source }
  $c2 = Get-Command 'pwsh' -ErrorAction SilentlyContinue
  if ($c2) { return $c2.Source }
  return 'pwsh'
}

function RunPs1([string]$scriptPath, [string[]]$scriptArgs) {
  if ([string]::IsNullOrWhiteSpace($scriptPath)) { throw '[STOP] RunPs1: scriptPath vazio.' }
  $pwsh = GetPwshExe
  $args = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$scriptPath)
  if ($scriptArgs -and $scriptArgs.Count -gt 0) { $args += $scriptArgs }
  RunCmd $pwsh $args
}
function GetNpmCmd() {
  $c = Get-Command 'npm.cmd' -ErrorAction SilentlyContinue
  if ($c) { return $c.Source }
  return 'npm.cmd'
}

function WriteReport([string]$name, [string]$text) {
  $reports = Join-Path (Get-Location) 'reports'
  EnsureDir $reports
  $p = Join-Path $reports $name
  WriteUtf8NoBom $p $text
  Write-Host ('[OK] Report: ' + $p)
  return $p
}
# === 
CV HOTFIX (B8G5): RunNpm robust
 (cmd.exe) ===
function RunNpm {
  param([Parameter(Mandatory=True)][string[]]$Args)
  if(-not $Args){ return }
  $cmdLine = 'npm ' + ($Args -join ' ')
  & $env:ComSpec /d /c $cmdLine
  if($LASTEXITCODE -ne 0){ throw ('[STOP] npm falhou (exit ' + $LASTEXITCODE + '): ' + $cmdLine) }
}
# === END 
CV HOTFIX (B8G5): RunNpm robust
 ===
