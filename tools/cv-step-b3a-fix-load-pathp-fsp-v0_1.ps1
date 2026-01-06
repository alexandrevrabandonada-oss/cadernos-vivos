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
if (-not (Get-Command WriteUtf8NoBom -ErrorAction SilentlyContinue)) {
  function WriteUtf8NoBom([string]$p, [string]$content) { [IO.File]::WriteAllText($p, $content, [Text.UTF8Encoding]::new($false)) }
}
if (-not (Get-Command ReadUtf8 -ErrorAction SilentlyContinue)) {
  function ReadUtf8([string]$p) { return [IO.File]::ReadAllText($p, [Text.UTF8Encoding]::new($false)) }
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
function InsertAfterImports([string]$raw, [string[]]$insertLines) {
  $lines = $raw -split "`n", 0, 'SimpleMatch'
  $lastImport = -1
  for ($i = 0; $i -lt $lines.Length; $i++) {
    $t = $lines[$i].TrimStart()
    if ($t.StartsWith('import ')) { $lastImport = $i; continue }
    if ($lastImport -ge 0 -and $t -ne '' -and -not $t.StartsWith('//')) { break }
  }
  if ($lastImport -lt 0) {
    return (($insertLines + @('') + $lines) -join "`n")
  }
  $before = @($lines[0..$lastImport])
  $after = @()
  if (($lastImport+1) -le ($lines.Length-1)) { $after = @($lines[($lastImport+1)..($lines.Length-1)]) }
  return (($before + $insertLines + $after) -join "`n")
}

$root = FindRepoRoot (Get-Location).Path
$reportsDir = Join-Path $root 'reports'
$backupDir  = Join-Path $root 'tools\_patch_backup'
EnsureDir $reportsDir
EnsureDir $backupDir

$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$reportPath = Join-Path $reportsDir ('cv-step-b3a-fix-load-pathp-fsp-' + $ts + '.md')

$loadPath = Join-Path $root 'src\lib\v2\load.ts'
if (-not (Test-Path -LiteralPath $loadPath)) { throw ('Arquivo não encontrado: ' + $loadPath) }

$raw = ReadUtf8 $loadPath
$bk  = BackupFile $loadPath $backupDir

$actions = @()

# ----- Detect path imports -----
$pathImportLine = ($raw -split "`n" | Where-Object { $_ -match 'from\s+["''](node:path|path)["'']' }) | Select-Object -First 1
$pathAlias = $null
$pathJoinOnly = $false

if ($pathImportLine) {
  if ($pathImportLine -match 'import\s+\*\s+as\s+([A-Za-z_][A-Za-z0-9_]*)\s+from\s+["''](node:path|path)["'']') { $pathAlias = $Matches[1] }
  elseif ($pathImportLine -match 'import\s+([A-Za-z_][A-Za-z0-9_]*)\s+from\s+["''](node:path|path)["'']') { $pathAlias = $Matches[1] }
  elseif ($pathImportLine -match 'import\s*{[^}]*\bjoin\b[^}]*}\s*from\s*["''](node:path|path)["'']') { $pathJoinOnly = $true }
}

# ----- Detect fs/promises imports -----
$fsImportLine = ($raw -split "`n" | Where-Object { $_ -match 'from\s+["''](node:fs/promises|fs/promises)["'']' }) | Select-Object -First 1
$fsAlias = $null
$fsHasReadFile = $false
$fsReadFileName = 'readFile'

if ($fsImportLine) {
  if ($fsImportLine -match 'import\s+\*\s+as\s+([A-Za-z_][A-Za-z0-9_]*)\s+from\s+["''](node:fs/promises|fs/promises)["'']') { $fsAlias = $Matches[1] }
  elseif ($fsImportLine -match 'import\s*{[^}]*\breadFile\b[^}]*}\s*from\s*["''](node:fs/promises|fs/promises)["'']') { $fsHasReadFile = $true }
  elseif ($fsImportLine -match 'import\s*{[^}]*\breadFile\s+as\s+([A-Za-z_][A-Za-z0-9_]*)[^}]*}\s*from\s*["''](node:fs/promises|fs/promises)["'']') {
    $fsHasReadFile = $true
    $fsReadFileName = $Matches[1]
  }
}

# ----- Fix pathP usage -----
if ($raw -match '\bpathP\.') {
  if ($pathJoinOnly) {
    $raw = $raw.Replace('pathP.join', 'join')
    $actions += 'Replaced pathP.join -> join (named import).'
  } elseif ($pathAlias) {
    $raw = $raw.Replace('pathP.', ($pathAlias + '.'))
    $actions += ('Replaced pathP. -> ' + $pathAlias + '. (existing import).')
  } else {
    # no import at all -> add one
    if (-not ($raw -match 'from\s+["''](node:path|path)["'']')) {
      $raw = InsertAfterImports $raw @('import * as pathP from "node:path";')
      $actions += 'Inserted import: pathP from node:path.'
    } else {
      # module imported but cannot detect alias -> safest: use "path" (common) and ensure import
      if (-not ($raw -match '\bimport\s+([A-Za-z_][A-Za-z0-9_]*)\s+from\s+["''](node:path|path)["'']')) {
        $raw = InsertAfterImports $raw @('import * as path from "node:path";')
        $actions += 'Inserted import: path from node:path.'
      }
      $raw = $raw.Replace('pathP.', 'path.')
      $actions += 'Replaced pathP. -> path.'
    }
  }
}

# ----- Fix fsP usage -----
if ($raw -match '\bfsP\.') {
  if ($fsAlias) {
    $raw = $raw.Replace('fsP.', ($fsAlias + '.'))
    $actions += ('Replaced fsP. -> ' + $fsAlias + '. (existing import).')
  } elseif ($fsHasReadFile) {
    $raw = $raw.Replace('fsP.readFile', $fsReadFileName)
    $actions += ('Replaced fsP.readFile -> ' + $fsReadFileName + ' (named import).')
  } else {
    # no import at all -> add one
    if (-not ($raw -match 'from\s+["''](node:fs/promises|fs/promises)["'']')) {
      $raw = InsertAfterImports $raw @('import * as fsP from "node:fs/promises";')
      $actions += 'Inserted import: fsP from node:fs/promises.'
    } else {
      # module imported but can't detect readFile -> add named import readFile as cvReadFile (avoid conflicts)
      $raw = InsertAfterImports $raw @('import { readFile as cvReadFile } from "node:fs/promises";')
      $raw = $raw.Replace('fsP.readFile', 'cvReadFile')
      $actions += 'Inserted import: readFile as cvReadFile; replaced fsP.readFile -> cvReadFile.'
    }
  }
}

WriteUtf8NoBom $loadPath $raw

# ----- VERIFY -----
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

# ----- REPORT -----
$rep = @()
$rep += '# CV — Step B3a: Fix load.ts pathP/fsP references'
$rep += ''
$rep += ('- when: ' + $ts)
$rep += ('- file: `' + (Rel $root $loadPath) + '`')
$rep += ('- backup: `' + (Split-Path -Leaf $bk) + '`')
$rep += ''
$rep += '## ACTIONS'
if ($actions.Count -gt 0) { foreach ($a in $actions) { $rep += ('- ' + $a) } } else { $rep += '- (no changes needed)' }
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
  $rep += '- ✅ Tudo verde. Próximo tijolo: **B4 refatorar Hub/Pages V2 para usar cvReadMetaLoose/cvReadOptionalCadernoText**.'
} else {
  $rep += '- ⚠️ Verify falhou. Corrigir o erro apontado e re-rodar.'
}

WriteUtf8NoBom $reportPath ($rep -join "`n")
Write-Host ('[OK] Report -> ' + $reportPath)
if ($OpenReport) { try { Start-Process $reportPath | Out-Null } catch {} }