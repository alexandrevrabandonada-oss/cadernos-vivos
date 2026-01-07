param(
  [switch]$OpenReport
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$stamp = (Get-Date -Format 'yyyyMMdd-HHmmss')
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

$bootstrap = Join-Path $PSScriptRoot '_bootstrap.ps1'
if (-not (Test-Path $bootstrap)) { throw ('[STOP] bootstrap nao encontrado: ' + $bootstrap) }
. $bootstrap

Write-Host ('== cv-step-b6b-v2-provas-dom-filter-v0_1 == ' + (Get-Date -Format 'yyyyMMdd-HHmmss')) -ForegroundColor Cyan
Write-Host ('[DIAG] Root: ' + $root)

# --- write client component ---
$compRel = 'src\components\v2\Cv2DomFilterClient.tsx'
$comp = Join-Path $root $compRel
EnsureDir (Split-Path -Parent $comp)

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
  '  const candidates = [',
  '    ".cv2-card",',
  '    "[data-cv2-card]",',
  '    "article",',
  '    "li",',
  '  ];',
  '',
  '  for (const sel of candidates) {',
  '    const got = pick(sel);',
  '    if (got.length > 0) return got;',
  '  }',
  '',
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
  '    if (!root) {',
  '      itemsRef.current = [];',
  '      setStats({ total: 0, shown: 0 });',
  '      return;',
  '    }',
  '',
  '    const items = collectItems(root);',
  '    itemsRef.current = items;',
  '    setStats({ total: items.length, shown: items.length });',
  '  }, [rootId]);',
  '',
  '  useEffect(() => {',
  '    const items = itemsRef.current;',
  '    if (items.length === 0) {',
  '      setStats({ total: 0, shown: 0 });',
  '      return;',
  '    }',
  '',
  '    const q = foldText(query.trim());',
  '    let shown = 0;',
  '',
  '    for (const el of items) {',
  '      const hay = foldText(el.textContent ?? "");',
  '      const ok = q.length === 0 ? true : hay.includes(q);',
  '      el.hidden = !ok;',
  '      if (ok) shown += 1;',
  '    }',
  '',
  '    setStats({ total: items.length, shown });',
  '  }, [query]);',
  '',
  '  return (',
  '    <div',
  '      data-cv2-filter-ui="1"',
  '      style={{',
  '        display: "flex",',
  '        gap: "10px",',
  '        alignItems: "center",',
  '        flexWrap: "wrap",',
  '        margin: "12px 0 14px",',
  '        padding: "10px 12px",',
  '        borderRadius: "14px",',
  '        border: "1px solid rgba(255,255,255,0.10)",',
  '        background: "rgba(255,255,255,0.03)",',
  '        backdropFilter: "blur(6px)",',
  '      }}',
  '    >',
  '      <label style={{ opacity: 0.85, fontSize: 14 }}>Filtrar</label>',
  '      <input',
  '        type="search"',
  '        value={query}',
  '        onChange={(e) => setQuery(e.target.value)}',
  '        onKeyDown={(e) => {',
  '          if (e.key === "Escape") setQuery("");',
  '        }}',
  '        placeholder={placeholder ?? "Digite para filtrar..."}',
  '        style={{',
  '          minWidth: 220,',
  '          padding: "10px 12px",',
  '          borderRadius: 12,',
  '          border: "1px solid rgba(255,255,255,0.12)",',
  '          background: "var(--card)",',
  '          color: "var(--fg)",',
  '          outline: "none",',
  '        }}',
  '        aria-label="Filtrar itens da lista"',
  '      />',
  '      <button',
  '        type="button"',
  '        onClick={() => setQuery("")}',
  '        disabled={query.trim().length === 0}',
  '        style={{',
  '          padding: "10px 12px",',
  '          borderRadius: 12,',
  '          border: "1px solid rgba(255,255,255,0.12)",',
  '          background: "rgba(255,255,255,0.04)",',
  '          color: "var(--fg)",',
  '          opacity: query.trim().length === 0 ? 0.45 : 1,',
  '          cursor: query.trim().length === 0 ? "default" : "pointer",',
  '        }}',
  '      >',
  '        Limpar',
  '      </button>',
  '      <span aria-live="polite" style={{ opacity: 0.85, fontSize: 13 }}>',
  '        {stats.shown}/{stats.total}',
  '      </span>',
  '      <span style={{ opacity: 0.6, fontSize: 12 }}>(ESC limpa)</span>',
  '    </div>',
  '  );',
  '}'
)

WriteUtf8NoBom $comp ($compLines -join "`n")
Write-Host ('[PATCH] wrote -> ' + (Rel $root $comp))

# --- patch provas page to wrap ProvasV2 with filter UI ---
$targetRel = 'src\app\c\[slug]\v2\provas\page.tsx'
$target = Join-Path $root $targetRel
if (-not (Test-Path $target)) { throw ('[STOP] target nao encontrado: ' + $targetRel) }

BackupFile $target
$raw = Get-Content -Raw -LiteralPath $target
if ($null -eq $raw -or $raw.Trim().Length -eq 0) { throw ('[STOP] target vazio: ' + $targetRel) }

$changed = $false

# import
if ($raw -notmatch 'Cv2DomFilterClient') {
  $lines = $raw -split "`r?`n"
  $lastImport = -1
  for ($i = 0; $i -lt $lines.Length; $i++) {
    $t = $lines[$i].TrimStart()
    if ($t.StartsWith('import ')) { $lastImport = $i }
  }
  if ($lastImport -ge 0) {
    $before = @()
    $after = @()
    if ($lastImport -ge 0) { $before = $lines[0..$lastImport] }
    if ($lastImport + 1 -le $lines.Length - 1) { $after = $lines[($lastImport + 1)..($lines.Length - 1)] }
    $lines2 = @()
    $lines2 += $before
    $lines2 += 'import { Cv2DomFilterClient } from "@/components/v2/Cv2DomFilterClient";'
    $lines2 += $after
    $raw = ($lines2 -join "`n")
    $changed = $true
  }
}

# wrap ProvasV2 call
if ($raw -notmatch 'cv2-provas-root') {

  function GetIndent([string]$s, [int]$idx) {
    $nl = $s.LastIndexOf("`n", [Math]::Max(0, $idx))
    $start = 0
    if ($nl -ge 0) { $start = $nl + 1 }
    $seg = $s.Substring($start, $idx - $start)
    $m = [regex]::Match($seg, '^\s*')
    return $m.Value
  }

  function IndentBlock([string]$block, [string]$indent) {
    $ls = $block -split "`r?`n"
    $out = @()
    foreach ($l in $ls) {
      $out += ($indent + $l.Trim())
    }
    return ($out -join "`n")
  }

  $reSelf = [regex]::new('(?s)<ProvasV2\b[^>]*\/>')
  $m = $reSelf.Match($raw)
  if (-not $m.Success) {
    $rePair = [regex]::new('(?s)<ProvasV2\b[^>]*>.*?<\/ProvasV2>')
    $m = $rePair.Match($raw)
  }

  if ($m.Success) {
    $indent = GetIndent $raw $m.Index
    $indent2 = $indent + '  '
    $inner = IndentBlock $m.Value $indent2

    $wrap = @()
    $wrap += ($indent + '<div id="cv2-provas-root">')
    $wrap += ($indent2 + '<Cv2DomFilterClient rootId="cv2-provas-root" placeholder="Filtrar provas..." />')
    $wrap += $inner
    $wrap += ($indent + '</div>')
    $wrapText = ($wrap -join "`n")

    $raw = $raw.Substring(0, $m.Index) + $wrapText + $raw.Substring($m.Index + $m.Length)
    $changed = $true
  } else {
    Write-Host '[WARN] nao achei <ProvasV2 ...> no page.tsx; pulei wrap.' -ForegroundColor Yellow
  }
}

if ($changed) {
  WriteUtf8NoBom $target $raw
  Write-Host ('[PATCH] wrote -> ' + (Rel $root $target))
} else {
  Write-Host '[OK] nenhum change necessario (ja aplicado).' -ForegroundColor Green
}

# --- report ---
$rep = @()
$rep += '# CV — Step B6b: V2 Provas quick filter (DOM) (v0_1)'
$rep += ''
$rep += ('- when: ' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$rep += ('- repo: ' + $root)
$rep += ''
$rep += '## ACTIONS'
$rep += ('- wrote: ' + $compRel)
$rep += ('- patched: ' + $targetRel)
$rep += ''
$rep += '## VERIFY'
$rep += '- ran: tools/cv-verify.ps1 (or lint+build fallback)'
$rep += ''

$reportPath = NewReport 'cv-step-b6b-v2-provas-dom-filter-v0_1' ($rep -join "`n")

# --- verify ---
$verify = Join-Path $root 'tools\cv-verify.ps1'
$pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwsh) { $pwsh = (Get-Command powershell).Source }
$npm = (Get-Command npm -ErrorAction SilentlyContinue).Source
if (-not $npm) { $npm = 'npm' }

if (Test-Path $verify) {
  Run $pwsh @('-NoProfile','-ExecutionPolicy','Bypass','-File', $verify)
} else {
  Run $npm @('run','lint')
  Run $npm @('run','build')
}

if ($OpenReport) {
  Write-Host ('[OPEN] ' + $reportPath)
  ii $reportPath
}

Write-Host '[OK] B6b aplicado.' -ForegroundColor Green