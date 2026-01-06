param(
  [switch]$OpenReport,
  [switch]$NoVerify
)

$ErrorActionPreference = 'Stop'

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

# bootstrap (se existir)
$bootstrap = Join-Path $root 'tools\_bootstrap.ps1'
if (Test-Path -LiteralPath $bootstrap) { . $bootstrap }

# fallbacks mínimos
if (-not (Get-Command EnsureDir -ErrorAction SilentlyContinue)) {
  function EnsureDir([string]$p) { if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
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

function InsertAfterImports([string]$raw, [string]$lineToInsert) {
  if ($raw.Contains($lineToInsert)) { return $raw }

  $lines = @($raw -split "`n", 0, 'SimpleMatch')
  $lastImport = -1
  for ($i = 0; $i -lt $lines.Length; $i++) {
    $t = $lines[$i].TrimStart()
    if ($t.StartsWith('import ')) { $lastImport = $i; continue }
    if ($lastImport -ge 0 -and $t -ne '' -and -not $t.StartsWith('//')) { break }
  }

  if ($lastImport -lt 0) {
    return ($lineToInsert + "`n" + $raw)
  }

  $before = @($lines[0..$lastImport])
  $after = @()
  if (($lastImport + 1) -le ($lines.Length - 1)) { $after = @($lines[($lastImport+1)..($lines.Length-1)]) }
  return (($before + @($lineToInsert) + $after) -join "`n")
}

function RemoveNameFromBraceImportLine([string]$line, [string]$name) {
  $t = $line.TrimStart()
  if (-not $t.StartsWith('import {')) { return $line }
  if (-not $line.Contains($name)) { return $line }

  $idxOpen = $line.IndexOf('{')
  $idxClose = $line.IndexOf('}')
  if ($idxOpen -lt 0 -or $idxClose -lt 0 -or $idxClose -le $idxOpen) { return $line }

  $inside = $line.Substring($idxOpen + 1, $idxClose - $idxOpen - 1)
  $parts = @()
  foreach ($p in ($inside -split ',')) {
    $pp = $p.Trim()
    if ($pp) { $parts += $pp }
  }

  $kept = @()
  foreach ($p in $parts) {
    if ($p -eq $name) { continue }
    if ($p.StartsWith($name + ' as ')) { continue }
    $kept += $p
  }

  if ($kept.Count -eq $parts.Count) { return $line }
  if ($kept.Count -eq 0) { return '' }

  return ($line.Substring(0, $idxOpen+1) + ' ' + ($kept -join ', ') + ' ' + $line.Substring($idxClose))
}

function EnsureGenerateMetadata([string]$raw) {
  if ($raw -match 'export\s+async\s+function\s+generateMetadata') { return $raw }

  $idx = $raw.IndexOf('export default')
  if ($idx -lt 0) { return $raw }

  $blockLines = @(
    '',
    'export async function generateMetadata({ params }: { params: { slug: string } }): Promise<Metadata> {',
    '  const meta = await cvReadMetaLoose(params.slug);',
    '  const title = (typeof meta.title === "string" && meta.title.trim().length) ? meta.title.trim() : params.slug;',
    '  const m = meta as unknown as Record<string, unknown>;',
    '  const rawDesc = (typeof m["description"] === "string") ? (m["description"] as string) : "";',
    '  const description = rawDesc.trim().length ? rawDesc.trim() : undefined;',
    '  return {',
    '    title: title + " • Cadernos Vivos",',
    '    description,',
    '  };',
    '}',
    ''
  )
  $block = ($blockLines -join "`n")
  return ($raw.Substring(0, $idx) + $block + $raw.Substring($idx))
}

# paths
$target = Join-Path $root 'src\app\c\[slug]\v2\trilhas\page.tsx'
if (-not (Test-Path -LiteralPath $target)) { throw ('target não encontrado: ' + $target) }

$reportsDir = Join-Path $root 'reports'
$backupDir  = Join-Path $root 'tools\_patch_backup'
EnsureDir $reportsDir
EnsureDir $backupDir

$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$reportPath = Join-Path $reportsDir ('cv-step-b4f-refactor-v2-trilhas-motor-' + $ts + '.md')

$raw = [IO.File]::ReadAllText($target, [Text.UTF8Encoding]::new($false))
$bk = BackupFile $target $backupDir
$actions = New-Object System.Collections.Generic.List[string]

# 1) getCaderno -> loadCadernoV2 (só se existir)
if ($raw -match '\bgetCaderno\b') {
  $lines = @($raw -split "`n", 0, 'SimpleMatch')
  for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i].Contains('getCaderno')) {
      $newLine = RemoveNameFromBraceImportLine $lines[$i] 'getCaderno'
      if ($newLine -ne $lines[$i]) { $lines[$i] = $newLine }
    }
  }
  $raw = (($lines | Where-Object { $_ -ne '' }) -join "`n")
  $raw = [regex]::Replace($raw, '\bgetCaderno\b', 'loadCadernoV2')
  $actions.Add('Replaced getCaderno -> loadCadernoV2 (import + calls).')
}

# 2) import do motor
if ($raw -match '\bloadCadernoV2\b') {
  $raw = InsertAfterImports $raw 'import { loadCadernoV2 } from "@/lib/v2";'
  $actions.Add('Ensured import loadCadernoV2 from "@/lib/v2".')
}

# 3) metadata
$raw = InsertAfterImports $raw 'import type { Metadata } from "next";'
$raw = InsertAfterImports $raw 'import { cvReadMetaLoose } from "@/lib/v2/load";'

$raw2 = EnsureGenerateMetadata $raw
if ($raw2 -ne $raw) {
  $raw = $raw2
  $actions.Add('Added generateMetadata() using cvReadMetaLoose.')
}

WriteUtf8NoBom $target $raw

# VERIFY
$verifyExit = 0
$verifyOut = ''
if (-not $NoVerify) {
  $verify = Join-Path $root 'tools\cv-verify.ps1'
  if (Test-Path -LiteralPath $verify) {
    $verifyOut = (& pwsh -NoProfile -ExecutionPolicy Bypass -File $verify 2>&1 | Out-String)
    $verifyExit = $LASTEXITCODE
  } else {
    $verifyOut = 'tools/cv-verify.ps1 não encontrado (pulando)'
    $verifyExit = 0
  }
}

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add('# CV — Step B4f: Refactor V2 Trilhas to use safe motor')
$rep.Add('')
$rep.Add('- when: ' + $ts)
$rep.Add('- target: ' + (Rel $root $target))
$rep.Add('- backup: ' + (Split-Path -Leaf $bk))
$rep.Add('')
$rep.Add('## ACTIONS')
if ($actions.Count -eq 0) { $rep.Add('- (no changes)') } else { foreach ($a in $actions) { $rep.Add('- ' + $a) } }
$rep.Add('')
$rep.Add('## VERIFY')
$rep.Add('- exit: ' + $verifyExit)
$rep.Add('')
$rep.Add('--- VERIFY OUTPUT START ---')
foreach ($ln in ($verifyOut -split "`r?`n")) { $rep.Add($ln) }
$rep.Add('--- VERIFY OUTPUT END ---')
$rep.Add('')
$rep.Add('## NEXT')
if ($verifyExit -eq 0) {
  $rep.Add('- OK. Bloco B4 completo. Próximo: varrer outros arquivos V2 por getCaderno e fechar commit.')
} else {
  $rep.Add('- Verify falhou. Corrigir e re-rodar.')
}

WriteUtf8NoBom $reportPath ($rep -join "`n")
Write-Host ('[OK] Report -> ' + $reportPath)
if ($OpenReport) { try { Start-Process $reportPath | Out-Null } catch {} }