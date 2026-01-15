param(
  [switch]$OpenReport,
  [switch]$ArchiveOldReports,
  [int]$ArchiveDays = 30
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function EnsureDir([string]$p){
  if(-not (Test-Path $p)){
    New-Item -ItemType Directory -Force -Path $p | Out-Null
  }
}
function WriteUtf8NoBom([string]$path,[string]$content){
  $enc = New-Object System.Text.UTF8Encoding($false)
  [IO.File]::WriteAllText($path, $content, $enc)
}
function AppendUtf8NoBom([string]$path,[string]$content){
  $enc = New-Object System.Text.UTF8Encoding($false)
  [IO.File]::AppendAllText($path, $content, $enc)
}
function BackupFile([string]$path,[string]$backupDir){
  if(Test-Path $path){
    EnsureDir $backupDir
    $name = Split-Path -Leaf $path
    Copy-Item -Force $path (Join-Path $backupDir $name)
    return $true
  }
  return $false
}
function NowStamp(){ (Get-Date).ToString("yyyyMMdd-HHmmss") }

$repoRoot   = (Resolve-Path ".").Path
$toolsDir   = Join-Path $repoRoot "tools"
$reportsDir = Join-Path $repoRoot "reports"
EnsureDir $toolsDir
EnsureDir $reportsDir

$stamp = NowStamp
$reportPath = Join-Path $reportsDir ("{0}-cv-baseline-clean.md" -f $stamp)

WriteUtf8NoBom $reportPath ("# CV Baseline Clean v0.2`n`nRepo: " + $repoRoot + "`n`n")

function RunCmd([string]$title, [scriptblock]$fn){
  AppendUtf8NoBom $reportPath ("[CMD] " + $title + "`n~~~`n")
  $global:LASTEXITCODE = 0
  try {
    $out = & $fn 2>&1
    if($null -ne $out){
      foreach($l in $out){ AppendUtf8NoBom $reportPath (([string]$l) + "`n") }
    }
  } catch {
    AppendUtf8NoBom $reportPath (($_.Exception.Message) + "`n")
  }
  AppendUtf8NoBom $reportPath ("~~~`nexit: " + $LASTEXITCODE + "`n`n")
  return $LASTEXITCODE
}

AppendUtf8NoBom $reportPath "## DIAG`n`n"
AppendUtf8NoBom $reportPath ("- PSVersion: " + $PSVersionTable.PSVersion + "`n")
AppendUtf8NoBom $reportPath ("- OS: " + [System.Environment]::OSVersion.VersionString + "`n`n")

RunCmd "node -v" { node -v } | Out-Null
RunCmd "npm -v"  { npm -v }  | Out-Null

$gitExe = $null
try { $gitExe = (Get-Command git.exe -ErrorAction Stop).Source } catch {}
if($null -ne $gitExe){
  RunCmd "git status --porcelain" { & $gitExe status --porcelain } | Out-Null
} else {
  AppendUtf8NoBom $reportPath "- git.exe not found on PATH`n`n"
}

$gitignorePath = Join-Path $repoRoot ".gitignore"
$runnerPath    = Join-Path $toolsDir "cv-runner.ps1"
$pkgPath       = Join-Path $repoRoot "package.json"

AppendUtf8NoBom $reportPath ("- .gitignore exists: " + (Test-Path $gitignorePath) + "`n")
AppendUtf8NoBom $reportPath ("- tools/cv-runner.ps1 exists: " + (Test-Path $runnerPath) + "`n")
AppendUtf8NoBom $reportPath ("- package.json exists: " + (Test-Path $pkgPath) + "`n`n")

try {
  $reportFiles = Get-ChildItem -Path $reportsDir -Filter "*.md" -File -ErrorAction SilentlyContinue
  $count = 0
  if($null -ne $reportFiles){ $count = @($reportFiles).Count }
  AppendUtf8NoBom $reportPath ("- reports/*.md count: " + $count + "`n`n")
} catch {}

AppendUtf8NoBom $reportPath "## PATCH`n`n"

$backupDir = Join-Path $toolsDir ("_patch_backup\baseline-clean-{0}" -f $stamp)
EnsureDir $backupDir

$needWrite = $false
$existing = ""
if(Test-Path $gitignorePath){
  BackupFile $gitignorePath $backupDir | Out-Null
  $existing = Get-Content -Raw -Encoding UTF8 $gitignorePath
}

$lines = @()
if($existing -ne ""){
  $lines = $existing -split "`n" | ForEach-Object { $_.TrimEnd("`r") }
}

function EnsureIgnoreLine([string]$line){
  if(-not ($lines -contains $line)){
    $script:lines += $line
    $script:needWrite = $true
    AppendUtf8NoBom $reportPath ("- add .gitignore: " + $line + "`n")
  } else {
    AppendUtf8NoBom $reportPath ("- keep .gitignore: " + $line + "`n")
  }
}

EnsureIgnoreLine "# --- cadernos-vivos baseline clean ---"

EnsureIgnoreLine ".eslintcache"
EnsureIgnoreLine "node_modules/"
EnsureIgnoreLine ".next/"
EnsureIgnoreLine "out/"
EnsureIgnoreLine ".turbo/"
EnsureIgnoreLine "coverage/"
EnsureIgnoreLine "tools/_patch_backup/"

EnsureIgnoreLine "reports/**"
EnsureIgnoreLine "!reports/"
EnsureIgnoreLine "!reports/README.md"

EnsureIgnoreLine ".DS_Store"
EnsureIgnoreLine "Thumbs.db"

if($needWrite){
  $out = ($lines -join "`r`n") + "`r`n"
  WriteUtf8NoBom $gitignorePath $out
  AppendUtf8NoBom $reportPath ("- wrote .gitignore (backup in " + $backupDir + ")`n")
} else {
  AppendUtf8NoBom $reportPath "- .gitignore unchanged`n"
}
AppendUtf8NoBom $reportPath "`n"

$reportsReadme = Join-Path $reportsDir "README.md"
if(-not (Test-Path $reportsReadme)){
  $readme = @()
  $readme += "# reports/"
  $readme += ""
  $readme += "Pasta de relatórios locais (runner, smokes, diagnósticos)."
  $readme += "Por padrão, o conteúdo de reports/ é ignorado pelo Git para não poluir o repo."
  $readme += ""
  $readme += "Se precisar versionar um relatório importante, mova para docs/ (ou outra pasta versionada)."
  $readme += ""
  WriteUtf8NoBom $reportsReadme (($readme -join "`r`n") + "`r`n")
  AppendUtf8NoBom $reportPath "- created reports/README.md`n`n"
} else {
  AppendUtf8NoBom $reportPath "- reports/README.md already exists`n`n"
}

if($ArchiveOldReports){
  $archiveDir = Join-Path $reportsDir ("_archive\{0}" -f (Get-Date).ToString("yyyyMM"))
  EnsureDir $archiveDir
  $cut = (Get-Date).AddDays(-1 * [Math]::Abs($ArchiveDays))
  AppendUtf8NoBom $reportPath ("- archive enabled: moving reports older than " + $cut.ToString("yyyy-MM-dd") + "`n")
  $items = Get-ChildItem -Path $reportsDir -Filter "*.md" -File -ErrorAction SilentlyContinue
  foreach($it in $items){
    if($it.Name -eq "README.md"){ continue }
    if($it.LastWriteTime -lt $cut){
      try {
        Move-Item -Force $it.FullName (Join-Path $archiveDir $it.Name)
        AppendUtf8NoBom $reportPath ("  - moved: " + $it.Name + "`n")
      } catch {
        AppendUtf8NoBom $reportPath ("  - failed move: " + $it.Name + " :: " + $_.Exception.Message + "`n")
      }
    }
  }
  AppendUtf8NoBom $reportPath "`n"
}

AppendUtf8NoBom $reportPath "## VERIFY`n`n"

$pwsh = (Get-Command pwsh -ErrorAction Stop).Source
if(Test-Path $runnerPath){
  AppendUtf8NoBom $reportPath "[RUN] tools/cv-runner.ps1`n~~~`n"
  $out2 = & $pwsh -NoProfile -ExecutionPolicy Bypass -File $runnerPath 2>&1
  $code2 = $LASTEXITCODE
  if($null -ne $out2){ foreach($l in $out2){ AppendUtf8NoBom $reportPath (([string]$l) + "`n") } }
  AppendUtf8NoBom $reportPath ("~~~`nexit: " + $code2 + "`n`n")
} else {
  AppendUtf8NoBom $reportPath "- runner not found: tools/cv-runner.ps1`n`n"
}

AppendUtf8NoBom $reportPath "## POST`n`n"
if($null -ne $gitExe){
  RunCmd "git status --porcelain" { & $gitExe status --porcelain } | Out-Null
}

AppendUtf8NoBom $reportPath "## NEXT (manual)`n`n"
AppendUtf8NoBom $reportPath "Sugestão de commit (rode você):`n`n"
AppendUtf8NoBom $reportPath "  git add .gitignore reports/README.md`n"
AppendUtf8NoBom $reportPath "  git commit -m `"chore: baseline clean (ignore local reports/cache)`"`n`n"

Write-Host ("[REPORT] " + $reportPath)
if($OpenReport){
  try { Start-Process $reportPath | Out-Null } catch {}
}