param(
  [switch]$OpenReport,
  [switch]$NoVerify
)

$ErrorActionPreference = 'Stop'

# Preferir bootstrap do projeto (se existir)
$bootstrap = Join-Path $PSScriptRoot "_bootstrap.ps1"
if (Test-Path -LiteralPath $bootstrap) { . $bootstrap }

# Fallbacks mínimos (caso bootstrap não esteja carregado)
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

$root = FindRepoRoot (Get-Location).Path
$reportsDir = Join-Path $root 'reports'
$backupDir  = Join-Path $root 'tools\_patch_backup'
EnsureDir $reportsDir
EnsureDir $backupDir

$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$reportPath = Join-Path $reportsDir ('cv-step-b2a-fix-contract-lint-' + $ts + '.md')

$target = Join-Path $root 'src\lib\v2\contract.ts'
if (-not (Test-Path -LiteralPath $target)) { throw ('Arquivo não encontrado: ' + $target) }

$bk = BackupFile $target $backupDir

# Reescreve contract.ts (remove any + remove eslint-disable)
$lines = @(
  'import { z } from "zod";',
  '',
  'export type UiDefault = "v1" | "v2";',
  '',
  '// Aceita bem mais coisa (passthrough) porque cada caderno pode evoluir sem quebrar.',
  'export const MetaSchemaLoose = z.object({',
  '  title: z.string().optional(),',
  '  slug: z.string().optional(),',
  '  ui: z.unknown().optional(),',
  '}).passthrough();',
  '',
  'export type MetaLoose = z.infer<typeof MetaSchemaLoose>;',
  '',
  'export function safeJsonParse(text: string): unknown {',
  '  try {',
  '    return JSON.parse(text) as unknown;',
  '  } catch {',
  '    return null;',
  '  }',
  '}',
  '',
  'function isUiDefault(v: unknown): v is UiDefault {',
  '  return v === "v1" || v === "v2";',
  '}',
  '',
  '// meta.ui.default pode ser string OU function (legado).',
  'export function resolveUiDefault(uiDefault: unknown): UiDefault | undefined {',
  '  if (isUiDefault(uiDefault)) return uiDefault;',
  '',
  '  if (typeof uiDefault === "function") {',
  '    try {',
  '      const fn = uiDefault as unknown as (() => unknown);',
  '      const v = fn();',
  '      if (isUiDefault(v)) return v;',
  '    } catch {',
  '      return undefined;',
  '    }',
  '  }',
  '',
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
  '',
  '  // fallback mínimo (não quebra UI)',
  '  return {',
  '    slug: fallbackSlug,',
  '    title: fallbackSlug || "Caderno",',
  '    ui: { default: "v1" },',
  '  };',
  '}'
)

WriteUtf8NoBom $target ($lines -join "`n")

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
$rep += '# CV — Step B2a: Fix contract.ts lint (no any)'
$rep += ''
$rep += ('- when: ' + $ts)
$rep += ('- target: `' + (Rel $root $target) + '`')
$rep += ('- backup: `' + (Split-Path -Leaf $bk) + '`')
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
  $rep += '- ✅ Tudo verde. Pode commitar e aí eu mando o B3 (integrar parse/normalize com fallbacks reais no V2).'
} else {
  $rep += '- ⚠️ Verify falhou. Corrigir o erro apontado e re-rodar.'
}

WriteUtf8NoBom $reportPath ($rep -join "`n")
Write-Host ('[OK] Report -> ' + $reportPath)

if ($OpenReport) { try { Start-Process $reportPath | Out-Null } catch {} }