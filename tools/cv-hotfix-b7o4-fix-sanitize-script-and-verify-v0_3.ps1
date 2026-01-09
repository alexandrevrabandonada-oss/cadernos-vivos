# tools/cv-hotfix-b7o4-fix-sanitize-script-and-verify-v0_3.ps1
# Fix: $args é variável automática. Runner de npm tem que usar outro nome (ex.: $npmArgs).
# DIAG -> PATCH -> VERIFY -> REPORT

param(
  [switch]$SkipVerify
)

$ErrorActionPreference = 'Stop'

function NewUtf8NoBomEncoding() { New-Object System.Text.UTF8Encoding($false) }

function EnsureDir([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) { [IO.Directory]::CreateDirectory($p) | Out-Null }
}

function WriteUtf8NoBom([string]$path, [string]$content) {
  $enc = NewUtf8NoBomEncoding
  [IO.File]::WriteAllText($path, $content, $enc)
}

function BackupFile([string]$absPath, [string]$backupRoot, [string]$stamp) {
  EnsureDir $backupRoot
  $name = Split-Path -Leaf $absPath
  $dstDir = Join-Path $backupRoot $stamp
  EnsureDir $dstDir
  $dst = Join-Path $dstDir ($name + '.' + $stamp + '.bak')
  Copy-Item -LiteralPath $absPath -Destination $dst -Force
  return $dst
}

function AddLine([System.Collections.Generic.List[string]]$r, [string]$s='') {
  $r.Add($s) | Out-Null
}

function ResolveNpmCmd() {
  $c1 = Get-Command npm.cmd -ErrorAction SilentlyContinue
  if ($c1 -and (Test-Path -LiteralPath $c1.Source)) { return $c1.Source }

  $c2 = Get-Command npm -ErrorAction SilentlyContinue
  if ($c2 -and (Test-Path -LiteralPath $c2.Source)) {
    if ($c2.Source.ToLower().EndsWith('.ps1')) {
      $try = [IO.Path]::ChangeExtension($c2.Source, '.cmd')
      if (Test-Path -LiteralPath $try) { return $try }
    }
    return $c2.Source
  }

  $fallback = Join-Path ${env:ProgramFiles} 'nodejs\npm.cmd'
  if (Test-Path -LiteralPath $fallback) { return $fallback }

  throw 'Nao consegui localizar npm(.cmd).'
}

function RunNpm([string[]]$npmArgs, [string]$cwd) {
  if (-not $npmArgs -or $npmArgs.Count -eq 0) {
    throw 'RunNpm recebeu args vazios (isso nao pode acontecer).'
  }

  $npm = ResolveNpmCmd
  $old = Get-Location
  try {
    Set-Location $cwd
    $out = & $npm @npmArgs 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
      throw ("Command failed: npm " + ($npmArgs -join ' ') + "`n" + $out)
    }
    return $out.TrimEnd()
  } finally {
    Set-Location $old
  }
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$root = (Resolve-Path '.').Path

if (-not (Test-Path -LiteralPath (Join-Path $root 'package.json'))) {
  throw ('Rode na raiz do repo (onde tem package.json). Root atual: ' + $root)
}

$reportsDir = Join-Path $root 'reports'
$backupDir  = Join-Path $root 'tools\_patch_backup'
EnsureDir $reportsDir
EnsureDir $backupDir

$reportPath = Join-Path $reportsDir ("{0}-cv-hotfix-b7o4-fix-sanitize-script-and-verify-v0_3.md" -f $stamp)

$r = New-Object System.Collections.Generic.List[string]
AddLine $r '# CV HOTFIX B7O4 v0_3 — Fix runner npm ($args) + patch B7O3 + verify'
AddLine $r ''
AddLine $r ('- Stamp: ' + $stamp)
AddLine $r ('- Root: ' + $root)
AddLine $r ''

AddLine $r '## DIAG'
AddLine $r ''
$npmResolved = ResolveNpmCmd
AddLine $r ('- npm resolved: ' + $npmResolved)
AddLine $r ''

# PATCH: corrigir B7O3 .Replace($c,"")
$b7o3Rel = 'tools\cv-hotfix-b7o3-core-highlights-sanitize-inject.ps1'
$b7o3Abs = Join-Path $root $b7o3Rel

AddLine $r '## PATCH — Corrigir B7O3 (.Replace char)'
AddLine $r ''

if (-not (Test-Path -LiteralPath $b7o3Abs)) {
  AddLine $r ('[ERR] Missing: ' + $b7o3Rel)
  WriteUtf8NoBom $reportPath ($r -join "`n")
  throw ('Missing: ' + $b7o3Rel)
}

$raw = Get-Content -LiteralPath $b7o3Abs -Raw
$new = $raw

$new = [regex]::Replace($new, '\.Replace\(\$c,\s*""\)', '.Replace([string]$c, "")')
$new = [regex]::Replace($new, "\.Replace\(\$c,\s*''\)", '.Replace([string]$c, "")')

if ($new -ne $raw) {
  $bk = BackupFile $b7o3Abs $backupDir $stamp
  WriteUtf8NoBom $b7o3Abs $new
  AddLine $r ('[OK] Patch aplicado em ' + $b7o3Rel)
  AddLine $r ('- Backup: ' + $bk.Substring($root.Length+1))
} else {
  AddLine $r '[OK] Sem mudancas — B7O3 parece ja corrigido.'
}

AddLine $r ''

# VERIFY 1: rodar B7O3
AddLine $r '## VERIFY 1 — Rodar B7O3'
AddLine $r ''

$pwsh = (Get-Command pwsh -ErrorAction Stop).Source
AddLine $r ('[RUN] ' + $pwsh + ' -NoProfile -ExecutionPolicy Bypass -File ' + $b7o3Rel + ' -CleanNext')
$out0 = & $pwsh -NoProfile -ExecutionPolicy Bypass -File $b7o3Abs -CleanNext 2>&1 | Out-String
AddLine $r $out0.TrimEnd()
AddLine $r ''
AddLine $r '[OK] B7O3 rodou.'
AddLine $r ''

# VERIFY 2: lint/build
AddLine $r '## VERIFY 2 — npm run lint / build'
AddLine $r ''

if ($SkipVerify) {
  AddLine $r '[SKIP] -SkipVerify informado.'
} else {
  AddLine $r '[RUN] npm run lint'
  $o1 = RunNpm @('run','lint') $root
  AddLine $r $o1
  AddLine $r ''

  AddLine $r '[RUN] npm run build'
  $o2 = RunNpm @('run','build') $root
  AddLine $r $o2
  AddLine $r ''
  AddLine $r '[OK] lint/build OK'
}

WriteUtf8NoBom $reportPath ($r -join "`n")
Write-Host ('OK: report -> ' + $reportPath)
Write-Host 'DONE.'