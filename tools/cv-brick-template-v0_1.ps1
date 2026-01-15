param([switch]$CleanNext,[switch]$OpenReport,[switch]$SkipLint,[switch]$SkipBuild)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root  = (Resolve-Path ".").Path
$stamp = (Get-Date -Format "yyyyMMdd-HHmmss")
$name  = [IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)
$repDir = Join-Path $root "reports"
[IO.Directory]::CreateDirectory($repDir) | Out-Null
$report = Join-Path $repDir ($stamp + "-" + $name + ".md")
$enc = [System.Text.UTF8Encoding]::new($false)

function Log([string]$s){
  Write-Host $s
  [IO.File]::AppendAllText($report, $s + "`n", $enc)
}
function RunExe([string]$exe, [string[]]$a){
  Log ("[RUN] " + $exe + " " + ($a -join " "))
  & $exe @a 2>&1 | ForEach-Object {
    $line = $_.ToString()
    Write-Host $line
    [IO.File]::AppendAllText($report, $line + "`n", $enc)
  }
  $ec = $LASTEXITCODE
  if($ec -ne 0){ throw ("Command failed (exit " + $ec + "): " + $exe + " " + ($a -join " ")) }
}
function Get-NpmCmd {
  $cand = @(
    (Join-Path $env:ProgramFiles "nodejs\\npm.cmd"),
    "C:\\Program Files\\nodejs\\npm.cmd"
  ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
  if($cand){ return $cand }
  $cmd = (Get-Command npm.cmd -ErrorAction SilentlyContinue).Source
  if($cmd){ return $cmd }
  throw "npm.cmd não encontrado. Confirme Node.js instalado."
}

Log ("# " + $name)
Log ("- root: " + $root)
Log ("- stamp: " + $stamp)
Log ("- report: " + $report)

# ========= PATCH AQUI =========
Log "[INFO] template: sem patch neste tijolo (só verify)."

# ========= VERIFY =========
if($CleanNext){
  $next = Join-Path $root ".next"
  if(Test-Path $next){ Log "[CLEAN] removed .next"; Remove-Item $next -Recurse -Force }
}
RunExe "git" @("status","--porcelain")
$npm = Get-NpmCmd
if(-not $SkipLint){ RunExe $npm @("run","lint") }
if(-not $SkipBuild){ RunExe $npm @("run","build") }
Log "[OK] lint/build ok"

if($OpenReport){ Start-Process $report }