# tools/cv-hotfix-b7i5-fix-b7i-runner-args-var-v0_1.ps1
# Fix B7I: trocar $args (auto var) por $cmdArgs dentro dos runners (RunCmd/RunNpm) + rerun + verify.
# DIAG -> PATCH -> RUN -> VERIFY -> REPORT

param(
  [switch]$SkipRun,
  [switch]$SkipVerify
)

$ErrorActionPreference = "Stop"

function NewUtf8NoBomEncoding() { New-Object System.Text.UTF8Encoding($false) }
function EnsureDir([string]$p){ if(-not (Test-Path -LiteralPath $p)){ [IO.Directory]::CreateDirectory($p) | Out-Null } }
function WriteUtf8NoBom([string]$path,[string]$content){ [IO.File]::WriteAllText($path,$content,(NewUtf8NoBomEncoding)) }
function BackupFile([string]$abs,[string]$bkRoot,[string]$stamp){
  EnsureDir $bkRoot
  $dir = Join-Path $bkRoot $stamp
  EnsureDir $dir
  $name = Split-Path -Leaf $abs
  $dst = Join-Path $dir ($name + "." + $stamp + ".bak")
  Copy-Item -LiteralPath $abs -Destination $dst -Force
  return $dst
}
function AddLine([System.Collections.Generic.List[string]]$r,[string]$s=""){ $r.Add($s) | Out-Null }

function ResolveNpmCmd() {
  $c1 = Get-Command npm.cmd -ErrorAction SilentlyContinue
  if ($c1 -and (Test-Path -LiteralPath $c1.Source)) { return $c1.Source }
  $c2 = Get-Command npm -ErrorAction SilentlyContinue
  if ($c2 -and (Test-Path -LiteralPath $c2.Source)) {
    if ($c2.Source.ToLower().EndsWith(".ps1")) {
      $try = [IO.Path]::ChangeExtension($c2.Source, ".cmd")
      if (Test-Path -LiteralPath $try) { return $try }
    }
    return $c2.Source
  }
  $fallback = Join-Path ${env:ProgramFiles} "nodejs\npm.cmd"
  if (Test-Path -LiteralPath $fallback) { return $fallback }
  throw "Nao consegui localizar npm(.cmd)."
}

function RunNpm([string[]]$npmArgs, [string]$cwd) {
  if (-not $npmArgs -or $npmArgs.Count -eq 0) { throw "RunNpm recebeu args vazios." }
  $npm = ResolveNpmCmd
  $old = Get-Location
  try {
    Set-Location $cwd
    $out = & $npm @npmArgs 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw ("Command failed: npm " + ($npmArgs -join " ") + "`n" + $out) }
    return $out.TrimEnd()
  } finally { Set-Location $old }
}

function ExtractBraceBlock([string]$text, [int]$startIdx) {
  $open = $text.IndexOf("{", $startIdx)
  if ($open -lt 0) { return $null }
  $depth = 0
  for ($i=$open; $i -lt $text.Length; $i++) {
    $ch = $text[$i]
    if ($ch -eq "{") { $depth++ }
    elseif ($ch -eq "}") {
      $depth--
      if ($depth -eq 0) {
        return [pscustomobject]@{ Open=$open; Close=$i; Block=$text.Substring($open, ($i-$open+1)) }
      }
    }
  }
  return $null
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$root  = (Resolve-Path ".").Path

if (-not (Test-Path -LiteralPath (Join-Path $root "package.json"))) { throw "Rode na raiz do repo (package.json)." }

$reportsDir = Join-Path $root "reports"
$backupDir  = Join-Path $root "tools\_patch_backup"
EnsureDir $reportsDir
EnsureDir $backupDir

$reportPath = Join-Path $reportsDir ("{0}-cv-hotfix-b7i5-fix-b7i-runner-args-var.md" -f $stamp)
$r = New-Object System.Collections.Generic.List[string]

AddLine $r "# CV HOTFIX B7I5 — Fix runner do B7I (trocar `$args` por `$cmdArgs`)"
AddLine $r ""
AddLine $r ("- Stamp: " + $stamp)
AddLine $r ("- Root: " + $root)
AddLine $r ("- npm(cmd): " + (ResolveNpmCmd))
AddLine $r ""

# alvo
$b7iRel = "tools\cv-step-b7i-portals-curated-everywhere-v0_1.ps1"
$b7iAbs = Join-Path $root $b7iRel
if (-not (Test-Path -LiteralPath $b7iAbs)) { throw "Missing: $b7iRel" }

AddLine $r "## DIAG"
AddLine $r ""
AddLine $r ("- B7I: " + $b7iRel)
AddLine $r ""

$raw = Get-Content -LiteralPath $b7iAbs -Raw
$patched = $raw

# patch: dentro dos blocos de função RunCmd/RunNpm/Run* que tenham "Command failed"
$needles = @("function RunCmd","function RunNpm","function Run")
$hits = New-Object System.Collections.Generic.List[int]

foreach ($n in $needles) {
  $idx = 0
  while ($true) {
    $pos = $patched.IndexOf($n, $idx, [StringComparison]::OrdinalIgnoreCase)
    if ($pos -lt 0) { break }
    $hits.Add($pos) | Out-Null
    $idx = $pos + 1
  }
}

# Também garante pegar o bloco onde aparece "Command failed:"
$cf = $patched.IndexOf("Command failed:", [StringComparison]::OrdinalIgnoreCase)
if ($cf -ge 0) {
  $fs = $patched.LastIndexOf("function", $cf, [StringComparison]::OrdinalIgnoreCase)
  if ($fs -ge 0) { $hits.Add($fs) | Out-Null }
}

$hits = $hits | Sort-Object -Unique
$replacedAny = $false

foreach ($start in $hits) {
  $blk = ExtractBraceBlock $patched $start
  if (-not $blk) { continue }
  $blockText = $blk.Block

  # só mexe se tiver $args dentro
  if ($blockText -notmatch '(?i)\$args\b') { continue }

  $newBlock = [regex]::Replace($blockText, '(?i)(?<![\w])\$args(?![\w])', '$cmdArgs')
  if ($newBlock -ne $blockText) {
    $patched = $patched.Substring(0, $blk.Open) + $newBlock + $patched.Substring($blk.Close+1)
    $replacedAny = $true
  }
}

AddLine $r "## PATCH"
AddLine $r ""

if ($replacedAny -and ($patched -ne $raw)) {
  $bk = BackupFile $b7iAbs $backupDir $stamp
  WriteUtf8NoBom $b7iAbs $patched
  AddLine $r ("[OK] patched: " + $b7iRel)
  AddLine $r ("- backup: " + $bk.Substring($root.Length+1))
} else {
  AddLine $r "[WARN] nao encontrei blocos com `$args` para trocar (ou ja estava OK)."
}
AddLine $r ""

AddLine $r "## RUN (B7I)"
AddLine $r ""

if ($SkipRun) {
  AddLine $r "[SKIP] -SkipRun informado."
} else {
  try {
    $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
    AddLine $r ("[RUN] " + $pwsh + " -NoProfile -ExecutionPolicy Bypass -File " + $b7iRel)
    $out = & $pwsh -NoProfile -ExecutionPolicy Bypass -File $b7iAbs 2>&1 | Out-String
    AddLine $r $out.TrimEnd()
  } catch {
    AddLine $r ("[ERR] B7I falhou: " + $_.Exception.Message)
    AddLine $r (($_ | Out-String).TrimEnd())
  }
}
AddLine $r ""

AddLine $r "## VERIFY (lint/build)"
AddLine $r ""

if ($SkipVerify) {
  AddLine $r "[SKIP] -SkipVerify informado."
} else {
  AddLine $r "[RUN] npm run lint"
  AddLine $r (RunNpm @("run","lint") $root)
  AddLine $r ""
  AddLine $r "[RUN] npm run build"
  AddLine $r (RunNpm @("run","build") $root)
  AddLine $r ""
  AddLine $r "[OK] lint/build ok"
}

WriteUtf8NoBom $reportPath ($r -join "`n")
Write-Host ("OK: report -> " + $reportPath)
Write-Host "DONE."