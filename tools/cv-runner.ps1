param(
  [switch]$OpenReport,
  [switch]$NoClean,
  [switch]$SkipLint,
  [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$reportsDir = Join-Path $repoRoot 'reports'
if(-not (Test-Path $reportsDir)){ New-Item -ItemType Directory -Force -Path $reportsDir | Out-Null }

function NowStamp(){ (Get-Date).ToString('yyyyMMdd-HHmmss') }
function WriteUtf8NoBom([string]$path,[string]$content){
  $enc = New-Object System.Text.UTF8Encoding($false)
  [IO.File]::WriteAllText($path, $content, $enc)
}
function AppendUtf8NoBom([string]$path,[string]$content){
  $enc = New-Object System.Text.UTF8Encoding($false)
  [IO.File]::AppendAllText($path, $content, $enc)
}

$stamp = NowStamp
$reportPath = Join-Path $reportsDir ('{0}-cv-runner.md' -f $stamp)
WriteUtf8NoBom $reportPath ("# CV Runner (canônico, safe npm quoting)`n`nRepo: " + $repoRoot + "`n`n")

function Step([string]$title, [scriptblock]$fn){
  AppendUtf8NoBom $reportPath ("[STEP] " + $title + "`n~~~`n")
  $global:LASTEXITCODE = 0
  $ok = $true
  try {
    $out = & $fn 2>&1
    if($null -ne $out){ foreach($l in $out){ AppendUtf8NoBom $reportPath (([string]$l) + "`n") } }
  } catch {
    $ok = $false
    AppendUtf8NoBom $reportPath (($_.Exception.Message) + "`n")
  }
  $code = $LASTEXITCODE
  AppendUtf8NoBom $reportPath ("~~~`n")
  if((-not $ok) -or ($code -ne 0)){
    AppendUtf8NoBom $reportPath ("[ERR] exit: " + $code + "`n`n")
    return $false
  }
  AppendUtf8NoBom $reportPath ("`n")
  return $true
}

if(-not $NoClean){
  $toClean = @('.next','out','.turbo','node_modules\.cache','node_modules\.turbo')
  foreach($p in $toClean){
    $full = Join-Path $repoRoot $p
    if(Test-Path $full){
      try { Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $full } catch {}
    }
  }
}

$gitExe = (Get-Command git.exe -ErrorAction Stop).Source
$npmCmd = (Get-Command npm.cmd -ErrorAction Stop).Source
AppendUtf8NoBom $reportPath ("[ENV] git.exe: " + $gitExe + "`n")
AppendUtf8NoBom $reportPath ("[ENV] npm.cmd: " + $npmCmd + "`n`n")

Push-Location $repoRoot
try {
  $failed = $false
  if(-not (Step "git status --porcelain" { & $gitExe status --porcelain })){ $failed = $true }
  if(-not $SkipLint){ if(-not (Step "npm run lint" { & $npmCmd run lint })){ $failed = $true } }
  if(-not $SkipBuild){ if(-not (Step "npm run build" { & $npmCmd run build })){ $failed = $true } }
  if($failed){ throw ("Runner failed (see report): " + $reportPath) }
} finally {
  Pop-Location
}

Write-Host ("[REPORT] " + $reportPath)
if($OpenReport){ try { Start-Process $reportPath | Out-Null } catch {} }
