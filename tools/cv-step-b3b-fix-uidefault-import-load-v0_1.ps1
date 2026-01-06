param(
  [switch]$OpenReport,
  [switch]$NoVerify
)

$ErrorActionPreference = 'Stop'

$bootstrap = Join-Path $PSScriptRoot "_bootstrap.ps1"
if (Test-Path -LiteralPath $bootstrap) { . $bootstrap }

if (-not (Get-Command EnsureDir -ErrorAction SilentlyContinue)) {
  function EnsureDir([string]$p) { if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
}
if (-not (Get-Command ReadUtf8 -ErrorAction SilentlyContinue)) {
  function ReadUtf8([string]$p) { return [IO.File]::ReadAllText($p, [Text.UTF8Encoding]::new($false)) }
}
if (-not (Get-Command WriteUtf8NoBom -ErrorAction SilentlyContinue)) {
  function WriteUtf8NoBom([string]$p, [string]$content) { [IO.File]::WriteAllText($p, $content, [Text.UTF8Encoding]::new($false)) }
}
if (-not (Get-Command BackupFile -ErrorAction SilentlyContinue)) {
  function BackupFile([string]$filePath, [string]$backupDir) {
    EnsureDir $backupDir
    $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
    $name = Split-Path -Leaf $filePath
    $dest = Join-Path $backupDir ($ts + '-' + $name + '.bak')
    Copy-Item -LiteralPath $filePath -Destination $dest -Force
    return $dest
  }
}

function FindRepoRoot([string]$start) {
  $cur = (Resolve-Path -LiteralPath $start).Path
  while ($true) {
    if (Test-Path -LiteralPath (Join-Path $cur 'package.json')) { return $cur }
    $parent = Split-Path -Parent $cur
    if ($parent -eq $cur -or [string]::IsNullOrWhiteSpace($parent)) { break }
    $cur = $parent
  }
  throw 'Não achei package.json. Rode na raiz do repo.'
}

function Rel([string]$base, [string]$full) {
  try { $b = (Resolve-Path -LiteralPath $base).Path.TrimEnd('\') } catch { $b = $base.TrimEnd('\') }
  try { $f = (Resolve-Path -LiteralPath $full).Path } catch { $f = $full }
  if ($f.StartsWith($b)) { return $f.Substring($b.Length).TrimStart('\') }
  return $f
}

function InsertAfterImports([string]$raw, [string]$lineToInsert) {
  $lines = $raw -split "`n", 0, 'SimpleMatch'
  $lastImport = -1
  for ($i = 0; $i -lt $lines.Length; $i++) {
    $t = $lines[$i].TrimStart()
    if ($t.StartsWith('import ')) { $lastImport = $i; continue }
    if ($lastImport -ge 0 -and $t -ne '' -and -not $t.StartsWith('//')) { break }
  }
  if ($lastImport -lt 0) {
    return (($lineToInsert + "`n" + $raw))
  }
  $before = @($lines[0..$lastImport])
  $after = @()
  if (($lastImport + 1) -le ($lines.Length - 1)) { $after = @($lines[($lastImport+1)..($lines.Length-1)]) }
  return (($before + @($lineToInsert) + $after) -join "`n")
}

$root = FindRepoRoot (Get-Location).Path
$reportsDir = Join-Path $root 'reports'
$backupDir  = Join-Path $root 'tools\_patch_backup'
EnsureDir $reportsDir
EnsureDir $backupDir

$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$reportPath = Join-Path $reportsDir ('cv-step-b3b-fix-uidefault-import-load-' + $ts + '.md')

$loadPath = Join-Path $root 'src\lib\v2\load.ts'
if (-not (Test-Path -LiteralPath $loadPath)) { throw ('Arquivo não encontrado: ' + $loadPath) }

$raw = ReadUtf8 $loadPath
$bk = BackupFile $loadPath $backupDir

$actions = @()

$usesUiDefault = ($raw.IndexOf('UiDefault', [StringComparison]::Ordinal) -ge 0)
$hasUiDefaultImport = ($raw -match 'from\s+["'']\./types["''];' -and $raw -match '\bUiDefault\b')

if ($usesUiDefault -and -not $hasUiDefaultImport) {

  # tenta achar um import existente de ./types e editar (sem criar import duplicado)
  $lines = $raw -split "`n", 0, 'SimpleMatch'
  $idxTypes = -1
  for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match 'from\s+["'']\./types["''];\s*$') { $idxTypes = $i; break }
  }

  if ($idxTypes -ge 0) {
    $line = $lines[$idxTypes]

    # casos: import type { A, B } from "./types";
    if ($line -match 'import\s+type\s*{\s*([^}]*)\s*}\s*from\s*["'']\./types["''];') {
      $inside = $Matches[1]
      if ($inside -notmatch '\bUiDefault\b') {
        $parts = @()
        foreach ($p in ($inside -split ',')) {
          $t = $p.Trim()
          if ($t) { $parts += $t }
        }
        $parts += 'UiDefault'
        $newInside = ($parts | Select-Object -Unique) -join ', '
        $lines[$idxTypes] = ('import type { ' + $newInside + ' } from "./types";')
        $actions += 'Added UiDefault to existing import type {...} from "./types".'
      }
    }
    # caso: import { A, B } from "./types";
    elseif ($line -match 'import\s*{\s*([^}]*)\s*}\s*from\s*["'']\./types["''];') {
      $inside = $Matches[1]
      if ($inside -notmatch '\bUiDefault\b') {
        $parts = @()
        foreach ($p in ($inside -split ',')) {
          $t = $p.Trim()
          if ($t) { $parts += $t }
        }
        $parts += 'UiDefault'
        $newInside = ($parts | Select-Object -Unique) -join ', '
        $lines[$idxTypes] = ('import { ' + $newInside + ' } from "./types";')
        $actions += 'Added UiDefault to existing import {...} from "./types".'
      }
    }
    else {
      # linha estranha, insere um import type separado (último recurso)
      $raw = InsertAfterImports $raw 'import type { UiDefault } from "./types";'
      $actions += 'Inserted import type UiDefault from "./types" (fallback).'
      $lines = $null
    }

    if ($lines) { $raw = ($lines -join "`n") }
  } else {
    $raw = InsertAfterImports $raw 'import type { UiDefault } from "./types";'
    $actions += 'Inserted import type UiDefault from "./types".'
  }
} else {
  $actions += 'No change (UiDefault not used or already imported).'
}

WriteUtf8NoBom $loadPath $raw

# VERIFY
$verifyExit = 0
$verifyOut = ''
if (-not $NoVerify) {
  $verifyPath = Join-Path $root 'tools\cv-verify.ps1'
  if (Test-Path -LiteralPath $verifyPath) {
    $verifyOut = (& pwsh -NoProfile -ExecutionPolicy Bypass -File $verifyPath 2>&1 | Out-String)
    $verifyExit = $LASTEXITCODE
  } else {
    $verifyOut = 'tools/cv-verify.ps1 não encontrado (pulando)'
    $verifyExit = 0
  }
}

# REPORT
$rep = @()
$rep += '# CV — Step B3b: Fix UiDefault import in load.ts'
$rep += ''
$rep += ('- when: ' + $ts)
$rep += ('- file: `' + (Rel $root $loadPath) + '`')
$rep += ('- backup: `' + (Split-Path -Leaf $bk) + '`')
$rep += ''
$rep += '## ACTIONS'
foreach ($a in $actions) { $rep += ('- ' + $a) }
$rep += ''
$rep += '## VERIFY'
$rep += ('- exit: **' + $verifyExit + '**')
$rep += ''
$rep += '```'
$rep += ($verifyOut.TrimEnd())
$rep += '```'
$rep += ''
$rep += '## NEXT'
if ($verifyExit -eq 0) {
  $rep += '- ✅ Tudo verde. Próximo tijolo: B4 (refatorar Hub/Pages V2 para usar o motor seguro e reduzir duplicação de fs/readFile).'
} else {
  $rep += '- ⚠️ Verify falhou. Corrigir o erro apontado e re-rodar.'
}

WriteUtf8NoBom $reportPath ($rep -join "`n")
Write-Host ('[OK] Report -> ' + $reportPath)
if ($OpenReport) { try { Start-Process $reportPath | Out-Null } catch {} }