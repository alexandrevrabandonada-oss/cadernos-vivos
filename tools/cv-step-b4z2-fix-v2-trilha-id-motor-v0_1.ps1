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

function EnsureDir([string]$p) { if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function WriteUtf8NoBom([string]$p, [string]$content) { [IO.File]::WriteAllText($p, $content, [Text.UTF8Encoding]::new($false)) }

function BackupFile([string]$filePath, [string]$backupDir) {
  EnsureDir $backupDir
  $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
  $name = Split-Path -Leaf $filePath
  $dest = Join-Path $backupDir ($ts + '-' + $name + '.bak')
  Copy-Item -LiteralPath $filePath -Destination $dest -Force
  return $dest
}

function Rel([string]$base, [string]$full) {
  try { $b = (Resolve-Path -LiteralPath $base).Path.TrimEnd('\') } catch { $b = $base.TrimEnd('\') }
  try { $f = (Resolve-Path -LiteralPath $full).Path } catch { $f = $full }
  if ($f.StartsWith($b)) { return $f.Substring($b.Length).TrimStart('\') }
  return $f
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

  if ($lastImport -lt 0) { return ($lineToInsert + "`n" + $raw) }

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

$root = FindRepoRoot (Get-Location).Path

$target = Join-Path $root 'src\app\c\[slug]\v2\trilhas\[id]\page.tsx'
if (-not (Test-Path -LiteralPath $target)) { throw ('target não encontrado: ' + $target) }

$reportsDir = Join-Path $root 'reports'
$backupDir  = Join-Path $root 'tools\_patch_backup'
EnsureDir $reportsDir
EnsureDir $backupDir

$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$reportPath = Join-Path $reportsDir ('cv-step-b4z2-fix-v2-trilha-id-motor-' + $ts + '.md')

$raw0 = [IO.File]::ReadAllText($target, [Text.UTF8Encoding]::new($false))
$bk = BackupFile $target $backupDir

$actions = New-Object System.Collections.Generic.List[string]
$raw = $raw0

# remove import { getCaderno }...
if ($raw -match '\bgetCaderno\b') {
  $lines = @($raw -split "`n", 0, 'SimpleMatch')
  $changedImport = $false
  for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i].Contains('getCaderno') -and $lines[$i].TrimStart().StartsWith('import {')) {
      $newLine = RemoveNameFromBraceImportLine $lines[$i] 'getCaderno'
      if ($newLine -ne $lines[$i]) {
        $lines[$i] = $newLine
        $changedImport = $true
      }
    }
  }
  if ($changedImport) { $actions.Add('Removed getCaderno from brace import(s).') }
  $raw = (($lines | Where-Object { $_ -ne '' }) -join "`n")

  # replace tokens getCaderno -> loadCadernoV2 (types + calls)
  $raw2 = [regex]::Replace($raw, '\bgetCaderno\b', 'loadCadernoV2')
  if ($raw2 -ne $raw) {
    $raw = $raw2
    $actions.Add('Replaced getCaderno -> loadCadernoV2 (types + calls).')
  }
}

# ensure imports for motor + metadata
if ($raw -match '\bloadCadernoV2\b') {
  $raw = InsertAfterImports $raw 'import { loadCadernoV2 } from "@/lib/v2";'
  $actions.Add('Ensured import loadCadernoV2 from "@/lib/v2".')
}

$raw = InsertAfterImports $raw 'import type { Metadata } from "next";'
$raw = InsertAfterImports $raw 'import { cvReadMetaLoose } from "@/lib/v2/load";'

$raw3 = EnsureGenerateMetadata $raw
if ($raw3 -ne $raw) {
  $raw = $raw3
  $actions.Add('Added generateMetadata() using cvReadMetaLoose.')
}

WriteUtf8NoBom $target $raw

# verify
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

# report (sem code fence)
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add('# CV — Step B4z2: Fix V2 trilhas/[id] to use safe motor')
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
  $rep.Add('- Re-run B4z audit. Expected: zero getCaderno hits in V2 scope.')
} else {
  $rep.Add('- Verify falhou. Corrigir e re-rodar.')
}

WriteUtf8NoBom $reportPath ($rep -join "`n")
Write-Host ('[OK] Report -> ' + $reportPath)
if ($OpenReport) { try { Start-Process $reportPath | Out-Null } catch {} }