param(
  [switch]$OpenReport,
  [switch]$NoVerify
)

$ErrorActionPreference = 'Stop'

# --- Bootstrap (preferencial) ---
$bootstrap = Join-Path $PSScriptRoot "_bootstrap.ps1"
if (Test-Path -LiteralPath $bootstrap) {
  . $bootstrap
}

# --- Fallbacks mínimos (se não existir bootstrap) ---
if (-not (Get-Command EnsureDir -ErrorAction SilentlyContinue)) {
  function EnsureDir([string]$p) {
    if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
  }
}
if (-not (Get-Command WriteUtf8NoBom -ErrorAction SilentlyContinue)) {
  function WriteUtf8NoBom([string]$p, [string]$content) {
    [IO.File]::WriteAllText($p, $content, [Text.UTF8Encoding]::new($false))
  }
}
if (-not (Get-Command ReadUtf8 -ErrorAction SilentlyContinue)) {
  function ReadUtf8([string]$p) {
    return [IO.File]::ReadAllText($p, [Text.UTF8Encoding]::new($false))
  }
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
$reportPath = Join-Path $reportsDir ('cv-step-b2-v2-contract-zod-' + $ts + '.md')

$contractPath = Join-Path $root 'src\lib\v2\contract.ts'
$indexPath    = Join-Path $root 'src\lib\v2\index.ts'

# --- PATCH: create contract.ts (additivo) ---
EnsureDir (Split-Path -Parent $contractPath)

$contractLines = @(
  'import { z } from "zod";',
  '',
  'export type UiDefault = "v1" | "v2";',
  '',
  '// Aceita bem mais coisa (passthrough) porque cada caderno pode evoluir sem quebrar.',
  'export const MetaSchemaLoose = z.object({',
  '  title: z.string().optional(),',
  '  slug: z.string().optional(),',
  '  ui: z.any().optional(),',
  '}).passthrough();',
  '',
  'export type MetaLoose = z.infer<typeof MetaSchemaLoose>;',
  '',
  'export function safeJsonParse(text: string): unknown {',
  '  try { return JSON.parse(text); } catch { return null; }',
  '}',
  '',
  '// meta.ui.default pode ser string OU function (legado).',
  'export function resolveUiDefault(uiDefault: unknown): UiDefault | undefined {',
  '  if (uiDefault === "v1" || uiDefault === "v2") return uiDefault;',
  '  if (typeof uiDefault === "function") {',
  '    try {',
  '      // eslint-disable-next-line @typescript-eslint/no-unsafe-call',
  '      const v = (uiDefault as any)();',
  '      if (v === "v1" || v === "v2") return v;',
  '    } catch {',
  '      return undefined;',
  '    }',
  '  }',
  '  return undefined;',
  '}',
  '',
  'export function parseMetaLoose(input: unknown, fallbackSlug?: string): MetaLoose {',
  '  const res = MetaSchemaLoose.safeParse(input);',
  '  if (res.success) {',
  '    const m: MetaLoose = res.data;',
  '    if (fallbackSlug && !m.slug) return { ...m, slug: fallbackSlug };',
  '    return m;',
  '  }',
  '  // fallback mínimo (não quebra UI)',
  '  return {',
  '    slug: fallbackSlug,',
  '    title: fallbackSlug || "Caderno",',
  '    ui: { default: "v1" },',
  '  };',
  '}'
)

WriteUtf8NoBom $contractPath ($contractLines -join "`n")

# --- PATCH: reexport no index.ts (com backup se mexer) ---
$indexChanged = $false
$indexBackup = $null
if (Test-Path -LiteralPath $indexPath) {
  $raw = ReadUtf8 $indexPath
  if ($raw.IndexOf('export * from "./contract"', [StringComparison]::OrdinalIgnoreCase) -lt 0) {
    $indexBackup = BackupFile $indexPath $backupDir
    $nl = "`n"
    if (-not $raw.EndsWith($nl)) { $raw += $nl }
    $raw += 'export * from "./contract";' + $nl
    WriteUtf8NoBom $indexPath $raw
    $indexChanged = $true
  }
} else {
  # se não existir, cria um index.ts mínimo
  EnsureDir (Split-Path -Parent $indexPath)
  $indexLines = @(
    'export * from "./types";',
    'export * from "./normalize";',
    'export * from "./load";',
    'export * from "./contract";'
  )
  WriteUtf8NoBom $indexPath ($indexLines -join "`n")
  $indexChanged = $true
}

# --- VERIFY ---
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

# --- REPORT ---
$rep = @()
$rep += '# CV — Step B2: V2 Contract (Zod) v0.1'
$rep += ''
$rep += ('- when: ' + $ts)
$rep += ('- wrote: `' + (Rel $root $contractPath) + '`')
$rep += ('- index.ts changed: **' + ($(if ($indexChanged) { 'YES' } else { 'NO' })) + '**')
if ($indexBackup) { $rep += ('- index.ts backup: `' + (Split-Path -Leaf $indexBackup) + '`') }
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
  $rep += '- ✅ Agora já temos contrato v0.1 no V2. Próximo tijolo: **B3 integrar parse/normalize com fallbacks reais** no load/normalize (sem tocar V1).'
} else {
  $rep += '- ⚠️ Verify falhou. Corrigir o erro apontado e re-rodar.'
}

WriteUtf8NoBom $reportPath ($rep -join "`n")
Write-Host ('[OK] Report -> ' + $reportPath)

if ($OpenReport) {
  try { Start-Process $reportPath | Out-Null } catch {}
}