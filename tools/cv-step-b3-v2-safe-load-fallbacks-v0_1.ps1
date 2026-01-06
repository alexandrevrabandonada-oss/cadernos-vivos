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

function InsertAfterImportBlock([string]$raw, [string[]]$insertLines) {
  $lines = $raw -split "`n", 0, 'SimpleMatch'
  $idx = 0

  # pula BOM/linhas vazias iniciais
  while ($idx -lt $lines.Length -and ($lines[$idx].Trim()) -eq '') { $idx++ }

  # bloco de imports
  $lastImport = -1
  for ($i = $idx; $i -lt $lines.Length; $i++) {
    $t = $lines[$i].TrimStart()
    if ($t.StartsWith('import ')) { $lastImport = $i; continue }
    if ($t -eq '') { continue }
    break
  }

  if ($lastImport -lt 0) {
    # sem imports, insere no topo
    $newLines = @()
    $newLines += $insertLines
    $newLines += ''
    $newLines += $lines
    return ($newLines -join "`n")
  }

  $before = @($lines[0..$lastImport])
  $after  = @()
  if (($lastImport + 1) -le ($lines.Length - 1)) { $after = @($lines[($lastImport+1)..($lines.Length-1)]) }

  $out = @()
  $out += $before
  $out += $insertLines
  $out += $after
  return ($out -join "`n")
}

$root = FindRepoRoot (Get-Location).Path
$reportsDir = Join-Path $root 'reports'
$backupDir  = Join-Path $root 'tools\_patch_backup'
EnsureDir $reportsDir
EnsureDir $backupDir

$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$reportPath = Join-Path $reportsDir ('cv-step-b3-v2-safe-load-fallbacks-' + $ts + '.md')

$loadPath = Join-Path $root 'src\lib\v2\load.ts'
$normPath = Join-Path $root 'src\lib\v2\normalize.ts'

if (-not (Test-Path -LiteralPath $loadPath)) { throw ('Arquivo não encontrado: ' + $loadPath) }
if (-not (Test-Path -LiteralPath $normPath)) { throw ('Arquivo não encontrado: ' + $normPath) }

$changed = @()

# -------------------------
# PATCH load.ts
# -------------------------
$loadRaw = ReadUtf8 $loadPath
$loadBk = $null

$needImportContract = ($loadRaw.IndexOf('from "./contract"', [StringComparison]::OrdinalIgnoreCase) -lt 0)
$needImportTypes    = ($loadRaw.IndexOf('from "./types"', [StringComparison]::OrdinalIgnoreCase) -lt 0)
$needImportFsP       = ($loadRaw.IndexOf('node:fs/promises', [StringComparison]::OrdinalIgnoreCase) -lt 0)
$needImportPathP     = ($loadRaw.IndexOf('node:path', [StringComparison]::OrdinalIgnoreCase) -lt 0)

$importLines = @()
if ($needImportContract) { $importLines += 'import { parseMetaLoose, resolveUiDefault, safeJsonParse } from "./contract";' }
if ($needImportTypes)    { $importLines += 'import type { UiDefault } from "./types";' }
if ($needImportFsP)      { $importLines += 'import * as fsP from "node:fs/promises";' }
if ($needImportPathP)    { $importLines += 'import * as pathP from "node:path";' }

$markerLoad = '// CV:B3 safe helpers'
$needBlockLoad = ($loadRaw.IndexOf($markerLoad, [StringComparison]::OrdinalIgnoreCase) -lt 0)

if ($importLines.Count -gt 0 -or $needBlockLoad) {
  $loadBk = BackupFile $loadPath $backupDir
  $newLoad = $loadRaw

  if ($importLines.Count -gt 0) {
    $newLoad = InsertAfterImportBlock $newLoad $importLines
  }

  if ($needBlockLoad) {
    $block = @(
      '',
      $markerLoad,
      'function cvAsRecord(v: unknown): Record<string, unknown> | null {',
      '  if (typeof v !== "object" || v === null) return null;',
      '  return v as Record<string, unknown>;',
      '}',
      '',
      'function cvCadernoRoot(slug: string): string {',
      '  return pathP.join(process.cwd(), "content", "cadernos", slug);',
      '}',
      '',
      'export async function cvReadMetaLoose(slug: string): Promise<import("./contract").MetaLoose> {',
      '  const root = cvCadernoRoot(slug);',
      '  const metaPath = pathP.join(root, "meta.json");',
      '  try {',
      '    const raw = await fsP.readFile(metaPath, "utf8");',
      '    return parseMetaLoose(safeJsonParse(raw), slug);',
      '  } catch {',
      '    return parseMetaLoose(null, slug);',
      '  }',
      '}',
      '',
      'export async function cvResolveUiDefaultForSlug(slug: string): Promise<UiDefault | undefined> {',
      '  const meta = await cvReadMetaLoose(slug);',
      '  const ui = cvAsRecord(meta.ui);',
      '  const uiDefault = ui ? ui["default"] : undefined;',
      '  return resolveUiDefault(uiDefault);',
      '}',
      '',
      'export async function cvReadOptionalTextAbs(absPath: string): Promise<string | null> {',
      '  try {',
      '    return await fsP.readFile(absPath, "utf8");',
      '  } catch {',
      '    return null;',
      '  }',
      '}',
      '',
      'export async function cvReadOptionalCadernoText(slug: string, relPath: string): Promise<string | null> {',
      '  const root = cvCadernoRoot(slug);',
      '  const abs = pathP.join(root, relPath);',
      '  return cvReadOptionalTextAbs(abs);',
      '}'
    )
    $newLoad = $newLoad.TrimEnd() + ($block -join "`n") + "`n"
  }

  WriteUtf8NoBom $loadPath $newLoad
  $changed += @{ file = (Rel $root $loadPath); backup = (Split-Path -Leaf $loadBk) }
}

# -------------------------
# PATCH normalize.ts
# -------------------------
$normRaw = ReadUtf8 $normPath
$normBk = $null

$markerNorm = '// CV:B3 normalize helpers'
$needBlockNorm = ($normRaw.IndexOf($markerNorm, [StringComparison]::OrdinalIgnoreCase) -lt 0)

if ($needBlockNorm) {
  $normBk = BackupFile $normPath $backupDir
  $newNorm = $normRaw.TrimEnd() + "`n" + (@(
    '',
    $markerNorm,
    'export function cvAsRecord(v: unknown): Record<string, unknown> | null {',
    '  if (typeof v !== "object" || v === null) return null;',
    '  return v as Record<string, unknown>;',
    '}',
    '',
    'export function cvAsArray(v: unknown): unknown[] {',
    '  return Array.isArray(v) ? v : [];',
    '}',
    '',
    'export function cvAsString(v: unknown, fallback = ""): string {',
    '  return typeof v === "string" ? v : fallback;',
    '}'
  ) -join "`n") + "`n"
  WriteUtf8NoBom $normPath $newNorm
  $changed += @{ file = (Rel $root $normPath); backup = (Split-Path -Leaf $normBk) }
}

# -------------------------
# VERIFY
# -------------------------
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

# -------------------------
# REPORT
# -------------------------
$rep = @()
$rep += '# CV — Step B3: V2 safe load + fallbacks (additive)'
$rep += ''
$rep += ('- when: ' + $ts)
$rep += ('- changed files: **' + $changed.Count + '**')
if ($changed.Count -gt 0) {
  $rep += ''
  $rep += '## PATCH'
  foreach ($c in $changed) {
    $rep += ('- ' + $c.file + ' (backup: ' + $c.backup + ')')
  }
}
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
  $rep += '- ✅ Tudo verde. Próximo tijolo: **B4 refatorar as pages V2** (começando pelo Hub) pra usar cvReadMetaLoose/cvReadOptionalCadernoText e parar de duplicar fs/readFile.'
} else {
  $rep += '- ⚠️ Verify falhou. Corrigir o erro apontado e re-rodar.'
}

WriteUtf8NoBom $reportPath ($rep -join "`n")
Write-Host ('[OK] Report -> ' + $reportPath)
if ($OpenReport) { try { Start-Process $reportPath | Out-Null } catch {} }