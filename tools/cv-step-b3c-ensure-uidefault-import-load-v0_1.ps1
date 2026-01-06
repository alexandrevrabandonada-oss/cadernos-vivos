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

$root = FindRepoRoot (Get-Location).Path
$reportsDir = Join-Path $root 'reports'
$backupDir  = Join-Path $root 'tools\_patch_backup'
EnsureDir $reportsDir
EnsureDir $backupDir

$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$reportPath = Join-Path $reportsDir ('cv-step-b3c-ensure-uidefault-import-load-' + $ts + '.md')

$loadPath = Join-Path $root 'src\lib\v2\load.ts'
if (-not (Test-Path -LiteralPath $loadPath)) { throw ('Arquivo não encontrado: ' + $loadPath) }

$raw = ReadUtf8 $loadPath
$bk = BackupFile $loadPath $backupDir

$actions = @()

# Só faz algo se UiDefault for referenciado no arquivo
$usesUiDefault = ($raw -match '\bUiDefault\b')
if (-not $usesUiDefault) {
  $actions += 'UiDefault não é usado no arquivo (nada a fazer).'
} else {
  # Já existe UiDefault em alguma linha import?
  $hasUiDefaultInImport = $false
  foreach ($line in ($raw -split "`n", 0, 'SimpleMatch')) {
    $t = $line.TrimStart()
    if ($t.StartsWith('import ') -and ($t -match '\bUiDefault\b')) { $hasUiDefaultInImport = $true; break }
  }

  if ($hasUiDefaultInImport) {
    $actions += 'UiDefault já está importado (nada a fazer).'
  } else {
    $lines = @($raw -split "`n", 0, 'SimpleMatch')

    # Procura uma linha que importe de "./types"
    $idxTypes = -1
    for ($i = 0; $i -lt $lines.Length; $i++) {
      if ($lines[$i] -match 'from\s+["'']\./types["''];\s*$') { $idxTypes = $i; break }
    }

    if ($idxTypes -ge 0) {
      $line = $lines[$idxTypes]

      # Tenta adicionar UiDefault dentro das chaves
      if ($line -match 'import\s+(type\s+)?{\s*([^}]*)\s*}\s*from\s*["'']\./types["''];\s*$') {
        $isType = $Matches[1]
        $inside = $Matches[2]
        $parts = @()
        foreach ($p in ($inside -split ',')) {
          $tt = $p.Trim()
          if ($tt) { $parts += $tt }
        }
        if (-not ($parts -contains 'UiDefault')) { $parts += 'UiDefault' }
        $newInside = ($parts | Select-Object -Unique) -join ', '
        if ($isType) {
          $lines[$idxTypes] = ('import type { ' + $newInside + ' } from "./types";')
        } else {
          # se já era import normal, mantém normal
          $lines[$idxTypes] = ('import { ' + $newInside + ' } from "./types";')
        }
        $actions += 'Adicionou UiDefault ao import existente de "./types".'
      } else {
        # Linha estranha: insere import type separado após bloco de imports
        $actions += 'Import de "./types" existe mas formato inesperado; inseriu import type separado.'
        $idxLastImport = -1
        for ($i = 0; $i -lt $lines.Length; $i++) {
          $t = $lines[$i].TrimStart()
          if ($t.StartsWith('import ')) { $idxLastImport = $i }
          elseif ($idxLastImport -ge 0 -and $t -ne '' -and -not $t.StartsWith('//')) { break }
        }
        if ($idxLastImport -lt 0) { $idxLastImport = -1 }
        $before = @()
        $after = @()
        if ($idxLastImport -ge 0) {
          $before = @($lines[0..$idxLastImport])
          if (($idxLastImport+1) -le ($lines.Length-1)) { $after = @($lines[($idxLastImport+1)..($lines.Length-1)]) }
        } else {
          $after = $lines
        }
        $lines = @()
        $lines += $before
        $lines += 'import type { UiDefault } from "./types";'
        $lines += $after
      }
    } else {
      # Não tem import de types: insere import type após bloco de imports
      $idxLastImport = -1
      for ($i = 0; $i -lt $lines.Length; $i++) {
        $t = $lines[$i].TrimStart()
        if ($t.StartsWith('import ')) { $idxLastImport = $i }
        elseif ($idxLastImport -ge 0 -and $t -ne '' -and -not $t.StartsWith('//')) { break }
      }
      if ($idxLastImport -lt 0) { $idxLastImport = -1 }

      $before = @()
      $after = @()
      if ($idxLastImport -ge 0) {
        $before = @($lines[0..$idxLastImport])
        if (($idxLastImport+1) -le ($lines.Length-1)) { $after = @($lines[($idxLastImport+1)..($lines.Length-1)]) }
      } else {
        $after = $lines
      }

      $lines = @()
      $lines += $before
      $lines += 'import type { UiDefault } from "./types";'
      $lines += $after
      $actions += 'Inseriu import type { UiDefault } from "./types".'
    }

    $raw = ($lines -join "`n")
  }
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
$rep += '# CV — Step B3c: Ensure UiDefault import in load.ts'
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
  $rep += '- ✅ Tudo verde. Próximo tijolo: B4 (refatorar Hub/Pages V2 para usar o motor seguro).'
} else {
  $rep += '- ⚠️ Verify falhou. Corrigir o erro apontado e re-rodar.'
}

WriteUtf8NoBom $reportPath ($rep -join "`n")
Write-Host ('[OK] Report -> ' + $reportPath)
if ($OpenReport) { try { Start-Process $reportPath | Out-Null } catch {} }