# CV HOTFIX B7N3 v0_2 — Fix Run args binding (npm run lint/build)
# Patch tools/cv-step-b7n-map-core-highlights-v0_2.ps1 to:
# - Run $npm ("run","lint") instead of Run $npm @("run","lint")
# - function Run([string]$cmd, [string[]]$args)

$ErrorActionPreference = "Stop"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Write-Host ("== CV HOTFIX B7N3 FIX RUN ARGS v0_2 == " + $stamp)

$root = (Resolve-Path ".").Path

function EnsureDir([string]$p){
  if(-not (Test-Path -LiteralPath $p)){
    New-Item -ItemType Directory -Force -Path $p | Out-Null
  }
}

function WriteUtf8NoBom([string]$path, [string]$content){
  EnsureDir (Split-Path -Parent $path)
  $enc = New-Object System.Text.UTF8Encoding($false)
  [IO.File]::WriteAllText($path, $content, $enc)
}

function BackupFile([string]$absPath){
  if(Test-Path -LiteralPath $absPath){
    $bdir = Join-Path $root ("tools\_patch_backup\" + $stamp)
    EnsureDir $bdir
    $dst = Join-Path $bdir ([IO.Path]::GetFileName($absPath))
    Copy-Item -LiteralPath $absPath -Destination $dst -Force
    return $dst
  }
  return $null
}

$reportsDir = Join-Path $root "reports"
EnsureDir $reportsDir
$reportPath = Join-Path $reportsDir ($stamp + "-cv-hotfix-b7n3-fix-run-args-v0_2.md")

$targetRel = "tools\cv-step-b7n-map-core-highlights-v0_2.ps1"
$targetAbs = Join-Path $root $targetRel

$log = New-Object System.Collections.Generic.List[string]
$log.Add("# CV HOTFIX B7N3 v0_2 — Fix Run args binding — " + $stamp) | Out-Null
$log.Add("") | Out-Null
$log.Add("Target: " + $targetRel) | Out-Null
$log.Add("") | Out-Null

if (-not (Test-Path -LiteralPath $targetAbs)) {
  $log.Add("[ERR] target missing: " + $targetRel) | Out-Null
  WriteUtf8NoBom $reportPath ($log -join "`n")
  throw ("Missing target script. Veja: " + $reportPath)
}

$raw = Get-Content -LiteralPath $targetAbs -Raw
$patched = $raw

# 1) Fix Run signature: function Run($cmd, $args) -> function Run([string]$cmd, [string[]]$args)
$patched = [regex]::Replace(
  $patched,
  'function\s+Run\s*\(\s*\$cmd\s*,\s*\$args\s*\)',
  'function Run([string]$cmd, [string[]]$args)'
)

# 2) Fix calls: Run $npm @("run","lint") -> Run $npm ("run","lint")
$patched = [regex]::Replace($patched, 'Run\s+\$npm\s+@\(\s*"run"\s*,\s*"lint"\s*\)', 'Run $npm ("run","lint")')
$patched = [regex]::Replace($patched, 'Run\s+\$npm\s+@\(\s*"run"\s*,\s*"build"\s*\)', 'Run $npm ("run","build")')

if ($patched -eq $raw) {
  $log.Add("[OK] nenhuma mudança necessária (já estava corrigido).") | Out-Null
} else {
  $bk = BackupFile $targetAbs
  WriteUtf8NoBom $targetAbs $patched
  $log.Add("[OK] patch aplicado em " + $targetRel) | Out-Null
  if ($bk) { $log.Add("- backup: " + $bk.Substring($root.Length+1)) | Out-Null }
}

$log.Add("") | Out-Null
$log.Add("## RE-RUN B7N v0_2") | Out-Null
$log.Add("") | Out-Null

try {
  $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
  $log.Add("[RUN] pwsh -NoProfile -ExecutionPolicy Bypass -File " + $targetRel) | Out-Null

  $out = & $pwsh -NoProfile -ExecutionPolicy Bypass -File $targetAbs 2>&1 | Out-String

  $log.Add("") | Out-Null
  $log.Add("----") | Out-Null
  $log.Add($out.TrimEnd()) | Out-Null
  $log.Add("----") | Out-Null
  $log.Add("") | Out-Null

  $log.Add("[OK] B7N executado (veja log acima).") | Out-Null
} catch {
  $log.Add("[ERR] re-run falhou: " + $_.Exception.Message) | Out-Null
}

WriteUtf8NoBom $reportPath ($log -join "`n")
Write-Host ("[OK] report -> " + $reportPath)
Write-Host "DONE."