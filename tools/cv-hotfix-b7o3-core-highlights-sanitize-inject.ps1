param(
  [switch]$CleanNext
)

$ErrorActionPreference = "Stop"

function NowStamp() { (Get-Date).ToString("yyyyMMdd-HHmmss") }

function EnsureDir([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

function WriteUtf8NoBom([string]$file, [string]$text) {
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($file, $text, $enc)
}

function BackupFile([string]$file, [string]$backupDir) {
  EnsureDir $backupDir
  $name = Split-Path $file -Leaf
  $dst = Join-Path $backupDir ($name + "." + (NowStamp) + ".bak")
  Copy-Item -Force -LiteralPath $file -Destination $dst
  return $dst
}

function SanitizeText([string]$s) {
  if ($null -eq $s) { return "" }

  # BOM U+FEFF (no começo ou no meio)
  $s = $s.Replace([string][char]0xFEFF, "")

  # JS line/paragraph separators
  $s = $s.Replace([string][char]0x2028, "")
  $s = $s.Replace([string][char]0x2029, "")

  # zero-width / word joiner
  $zw = @([char]0x200B,[char]0x200C,[char]0x200D,[char]0x2060)
  foreach ($c in $zw) { $s = $s.Replace([string]$c, "") }  # <- FIX AQUI

  # Remove controles (mantém \r \n \t)
  $sb = New-Object System.Text.StringBuilder
  foreach ($ch in $s.ToCharArray()) {
    $code = [int][char]$ch
    if ($ch -eq "`r" -or $ch -eq "`n" -or $ch -eq "`t") { [void]$sb.Append($ch); continue }
    if ($code -lt 32 -or $code -eq 127) { continue }
    [void]$sb.Append($ch)
  }
  return $sb.ToString()
}

function InjectDataAttrs([string]$raw) {
  $m = [regex]::Match($raw, "<section\b[^>]*>", [System.Text.RegularExpressions.RegexOptions]::Singleline)
  if (-not $m.Success) { return @{ changed = $false; text = $raw; note = "no <section> tag found" } }

  $tag = $m.Value
  $newTag = $tag

  if ($newTag -notmatch "data-cv2-core-highlights\s*=") {
    $newTag = $newTag.TrimEnd(">")
    $newTag += ' data-cv2-core-highlights="1">'
  }
  if ($newTag -notmatch "data-cv2\s*=") {
    $newTag = $newTag.TrimEnd(">")
    $newTag += ' data-cv2="core-highlights">'
  }

  if ($newTag -eq $tag) { return @{ changed = $false; text = $raw; note = "attrs already present" } }

  $out = $raw.Substring(0, $m.Index) + $newTag + $raw.Substring($m.Index + $m.Length)
  return @{ changed = $true; text = $out; note = "injected attrs" }
}

function RunNpm([string[]]$args, [string]$cwd) {
  $npm = (Get-Command npm -ErrorAction Stop).Source
  Push-Location $cwd
  try { return (& $npm @args 2>&1 | Out-String) }
  finally { Pop-Location }
}

$root = (Resolve-Path ".").Path
$stamp = NowStamp
$target = Join-Path $root "src\components\v2\Cv2CoreHighlights.tsx"
$backupDir = Join-Path $root ("tools\_patch_backup\" + $stamp)
$reportDir = Join-Path $root "reports"
EnsureDir $reportDir

Write-Host "== CV HOTFIX B7O3 CORE HIGHLIGHTS SANITIZE+INJECT == $stamp"
Write-Host "[DIAG] Root: $root"
Write-Host "[DIAG] Target: $target"

if (-not (Test-Path -LiteralPath $target)) { throw "Target not found: $target" }

$beforeBak = BackupFile $target $backupDir
Write-Host "[BACKUP] $beforeBak"

$raw = Get-Content -Raw -LiteralPath $target
$raw2 = SanitizeText $raw
$inject = InjectDataAttrs $raw2
$raw3 = $inject.text

$changed = ($raw3 -ne $raw)

if ($changed) {
  WriteUtf8NoBom $target $raw3
  Write-Host "[PATCH] wrote sanitized file (UTF8 no BOM)"
  Write-Host ("[PATCH] inject note: " + $inject.note)
} else {
  Write-Host "[OK] no changes needed (already clean + attrs ok)"
}

if ($CleanNext) {
  $nextDir = Join-Path $root ".next"
  if (Test-Path -LiteralPath $nextDir) {
    Remove-Item -Recurse -Force -LiteralPath $nextDir
    Write-Host "[CLEAN] removed .next"
  }
}

# VERIFY
$verify = Join-Path $root "tools\cv-verify.ps1"
if (Test-Path -LiteralPath $verify) {
  Write-Host "[RUN] tools\cv-verify.ps1"
  & pwsh -NoProfile -ExecutionPolicy Bypass -File $verify
} else {
  Write-Host "[RUN] npm run lint"
  [void](RunNpm @("run","lint") $root)
  Write-Host "[RUN] npm run build"
  [void](RunNpm @("run","build") $root)
}

# REPORT
$report = Join-Path $reportDir ("CV-HOTFIX-B7O3-core-highlights-sanitize-" + $stamp + ".md")
$lines = @()
$lines += "# CV HOTFIX B7O3 — CoreHighlights sanitize + inject — $stamp"
$lines += "- Root: $root"
$lines += "- File: src\components\v2\Cv2CoreHighlights.tsx"
$lines += ""
$lines += "## Backup"
$lines += "- $beforeBak"
$lines += ""
$lines += "## Patch"
$lines += "- sanitized: " + ($raw2 -ne $raw)
$lines += "- injected attrs: " + $inject.changed
$lines += "- note: " + $inject.note
$lines += ""
$lines += "## Verify"
$lines += "- ok (if this script finished without error)"
WriteUtf8NoBom $report ($lines -join "`n")
Write-Host "[REPORT] $report"
Write-Host "[OK] done."