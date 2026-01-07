param(
  [switch]$OpenReport
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$stamp = (Get-Date -Format 'yyyyMMdd-HHmmss')
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path

$bootstrap = Join-Path $PSScriptRoot '_bootstrap.ps1'
if (-not (Test-Path -LiteralPath $bootstrap)) { throw ('[STOP] bootstrap nao encontrado: ' + $bootstrap) }
. $bootstrap

function Rel([string]$base, [string]$full) {
  try { $b = (Resolve-Path -LiteralPath $base).Path.TrimEnd('\') } catch { $b = $base.TrimEnd('\') }
  try { $f = (Resolve-Path -LiteralPath $full).Path } catch { $f = $full }
  if ($f.StartsWith($b)) { return $f.Substring($b.Length).TrimStart('\') }
  return $f
}

function ReadFileUtf8([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) { return $null }
  return [IO.File]::ReadAllText($p, [Text.UTF8Encoding]::new($false))
}

function WriteFileUtf8NoBom([string]$p, [string]$content) {
  [IO.File]::WriteAllText($p, $content, [Text.UTF8Encoding]::new($false))
}

function BackupLiteral([string]$p) {
  $bkDir = Join-Path $root 'tools\_patch_backup'
  EnsureDir $bkDir
  $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
  $leaf = Split-Path -Leaf $p
  $dest = Join-Path $bkDir ($ts + '-' + $leaf + '.bak')
  Copy-Item -LiteralPath $p -Destination $dest -Force
  return $dest
}

Write-Host ('== cv-step-b6b-v2-provas-dom-filter-v0_3 == ' + $stamp) -ForegroundColor Cyan
Write-Host ('[DIAG] Root: ' + $root)

# --- ensure client component exists (idempotent) ---
$compRel = 'src\components\v2\Cv2DomFilterClient.tsx'
$comp = Join-Path $root $compRel
EnsureDir (Split-Path -Parent $comp)

if (-not (Test-Path -LiteralPath $comp)) {
  $compLines = @(
    '"use client";',
    '',
    'import React, { useEffect, useRef, useState } from "react";',
    '',
    'type Props = {',
    '  rootId: string;',
    '  placeholder?: string;',
    '};',
    '',
    'type Stats = { total: number; shown: number };',
    '',
    'function foldText(s: string): string {',
    '  return s',
    '    .normalize("NFD")',
    '    .replace(/[\u0300-\u036f]/g, "")',
    '    .toLowerCase();',
    '}',
    '',
    'function collectItems(root: HTMLElement): HTMLElement[] {',
    '  const pick = (sel: string): HTMLElement[] => {',
    '    const nodes = Array.from(root.querySelectorAll<HTMLElement>(sel));',
    '    return nodes.filter((el) => !el.closest("[data-cv2-filter-ui=\\"1\\"]"));',
    '  };',
    '',
    '  const candidates = [".cv2-card","[data-cv2-card]","article","li"];',
    '  for (const sel of candidates) {',
    '    const got = pick(sel);',
    '    if (got.length > 0) return got;',
    '  }',
    '  return [];',
    '}',
    '',
    'export function Cv2DomFilterClient({ rootId, placeholder }: Props) {',
    '  const [query, setQuery] = useState<string>("");',
    '  const [stats, setStats] = useState<Stats>({ total: 0, shown: 0 });',
    '  const itemsRef = useRef<HTMLElement[]>([]);',
    '',
    '  useEffect(() => {',
    '    const root = document.getElementById(rootId);',
    '    if (!root) { itemsRef.current = []; setStats({ total: 0, shown: 0 }); return; }',
    '    const items = collectItems(root);',
    '    itemsRef.current = items;',
    '    setStats({ total: items.length, shown: items.length });',
    '  }, [rootId]);',
    '',
    '  useEffect(() => {',
    '    const items = itemsRef.current;',
    '    if (items.length === 0) { setStats({ total: 0, shown: 0 }); return; }',
    '    const q = foldText(query.trim());',
    '    let shown = 0;',
    '    for (const el of items) {',
    '      const hay = foldText(el.textContent ?? "");',
    '      const ok = q.length === 0 ? true : hay.includes(q);',
    '      el.hidden = !ok;',
    '      if (ok) shown += 1;',
    '    }',
    '    setStats({ total: items.length, shown });',
    '  }, [query]);',
    '',
    '  return (',
    '    <div data-cv2-filter-ui="1" style={{',
    '      display: "flex", gap: "10px", alignItems: "center", flexWrap: "wrap",',
    '      margin: "12px 0 14px", padding: "10px 12px",',
    '      borderRadius: "14px", border: "1px solid rgba(255,255,255,0.10)",',
    '      background: "rgba(255,255,255,0.03)", backdropFilter: "blur(6px)"',
    '    }}>',
    '      <label style={{ opacity: 0.85, fontSize: 14 }}>Filtrar</label>',
    '      <input',
    '        type="search"',
    '        value={query}',
    '        onChange={(e) => setQuery(e.target.value)}',
    '        onKeyDown={(e) => { if (e.key === "Escape") setQuery(""); }}',
    '        placeholder={placeholder ?? "Digite para filtrar..."}',
    '        style={{ minWidth: 220, padding: "10px 12px", borderRadius: 12,',
    '          border: "1px solid rgba(255,255,255,0.12)",',
    '          background: "var(--card)", color: "var(--fg)", outline: "none" }}',
    '        aria-label="Filtrar itens da lista"',
    '      />',
    '      <button type="button" onClick={() => setQuery("")} disabled={query.trim().length === 0}',
    '        style={{ padding: "10px 12px", borderRadius: 12,',
    '          border: "1px solid rgba(255,255,255,0.12)",',
    '          background: "rgba(255,255,255,0.04)", color: "var(--fg)",',
    '          opacity: query.trim().length === 0 ? 0.45 : 1,',
    '          cursor: query.trim().length === 0 ? "default" : "pointer" }}>',
    '        Limpar',
    '      </button>',
    '      <span aria-live="polite" style={{ opacity: 0.85, fontSize: 13 }}>{stats.shown}/{stats.total}</span>',
    '      <span style={{ opacity: 0.6, fontSize: 12 }}>(ESC limpa)</span>',
    '    </div>',
    '  );',
    '}',
    ''
  )
  WriteFileUtf8NoBom $comp ($compLines -join "`n")
  Write-Host ('[PATCH] wrote -> ' + (Rel $root $comp))
} else {
  Write-Host ('[OK] exists -> ' + (Rel $root $comp))
}

# --- find provas page with LiteralPath-safe logic ---
$dirRel = 'src\app\c\[slug]\v2\provas'
$dir = Join-Path $root $dirRel
if (-not (Test-Path -LiteralPath $dir)) { throw ('[STOP] dir nao encontrado: ' + $dirRel) }

$page = $null
$candidates = @('page.tsx','page.ts','page.jsx','page.js')
foreach ($c in $candidates) {
  $p = Join-Path $dir $c
  if (Test-Path -LiteralPath $p) { $page = $p; break }
}
if (-not $page) {
  $found = Get-ChildItem -LiteralPath $dir -File -ErrorAction Stop | Where-Object { $_.Name -match '^page\.(tsx|ts|jsx|js)$' } | Select-Object -First 1
  if ($found) { $page = $found.FullName }
}
if (-not $page) { throw ('[STOP] page.* nao encontrado em: ' + $dirRel) }

Write-Host ('[DIAG] target -> ' + (Rel $root $page))

# --- patch page: import + wrap ProvasV2 ---
$raw = ReadFileUtf8 $page
if ($null -eq $raw -or $raw.Trim().Length -eq 0) { throw ('[STOP] target vazio: ' + (Rel $root $page)) }

$changed = $false

if ($raw -notmatch 'Cv2DomFilterClient') {
  $lines = $raw -split "`r?`n"
  $lastImport = -1
  for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i].TrimStart().StartsWith('import ')) { $lastImport = $i }
  }
  if ($lastImport -ge 0) {
    $before = $lines[0..$lastImport]
    $after = @()
    if ($lastImport + 1 -le $lines.Length - 1) { $after = $lines[($lastImport+1)..($lines.Length-1)] }
    $lines2 = @()
    $lines2 += $before
    $lines2 += 'import { Cv2DomFilterClient } from "@/components/v2/Cv2DomFilterClient";'
    $lines2 += $after
    $raw = ($lines2 -join "`n")
    $changed = $true
  }
}

if ($raw -notmatch 'cv2-provas-root') {
  $reSelf = [regex]::new('(?s)<ProvasV2\b[^>]*\/>')
  $m = $reSelf.Match($raw)
  if (-not $m.Success) {
    $rePair = [regex]::new('(?s)<ProvasV2\b[^>]*>.*?<\/ProvasV2>')
    $m = $rePair.Match($raw)
  }

  if ($m.Success) {
    $nl = $raw.LastIndexOf("`n", [Math]::Max(0, $m.Index))
    $start = 0
    if ($nl -ge 0) { $start = $nl + 1 }
    $seg = $raw.Substring($start, $m.Index - $start)
    $indent = ([regex]::Match($seg, '^\s*')).Value
    $indent2 = $indent + '  '

    $wrap = @()
    $wrap += ($indent + '<div id="cv2-provas-root">')
    $wrap += ($indent2 + '<Cv2DomFilterClient rootId="cv2-provas-root" placeholder="Filtrar provas..." />')
    $innerLines = $m.Value -split "`r?`n"
    foreach ($l in $innerLines) { $wrap += ($indent2 + $l.Trim()) }
    $wrap += ($indent + '</div>')

    $wrapText = ($wrap -join "`n")
    $raw = $raw.Substring(0, $m.Index) + $wrapText + $raw.Substring($m.Index + $m.Length)
    $changed = $true
  } else {
    Write-Host '[WARN] nao achei <ProvasV2 ...> para wrap; pulei.' -ForegroundColor Yellow
  }
}

if ($changed) {
  $bk = BackupLiteral $page
  WriteFileUtf8NoBom $page $raw
  Write-Host ('[PATCH] wrote -> ' + (Rel $root $page))
  Write-Host ('[BK] ' + (Rel $root $bk))
} else {
  Write-Host '[OK] page ja estava patchada.' -ForegroundColor Green
}

# --- report ---
$rep = @()
$rep += '# CV — Step B6b: V2 Provas quick filter (DOM) (v0_3)'
$rep += ''
$rep += ('- when: ' + $stamp)
$rep += ('- repo: ' + $root)
$rep += ('- target: ' + (Rel $root $page))
$rep += ''
$rep += '## ACTIONS'
$rep += ('- ensured: ' + $compRel)
$rep += ('- patched:  ' + (Rel $root $page))
$rep += ''
$rep += '## VERIFY'
$rep += '- ran: tools/cv-verify.ps1 (or lint+build fallback)'
$rep += ''

$reportPath = NewReport 'cv-step-b6b-v2-provas-dom-filter-v0_3' ($rep -join "`n")

# --- verify ---
$verify = Join-Path $root 'tools\cv-verify.ps1'
if (Test-Path -LiteralPath $verify) {
  & pwsh -NoProfile -ExecutionPolicy Bypass -File $verify
} else {
  & npm run lint
  & npm run build
}

Write-Host ('[OK] Report -> ' + $reportPath) -ForegroundColor Green
if ($OpenReport) { try { Invoke-Item $reportPath } catch {} }