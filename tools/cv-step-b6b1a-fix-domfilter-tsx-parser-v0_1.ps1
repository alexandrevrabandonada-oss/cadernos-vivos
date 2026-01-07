param(
  [switch]$OpenReport
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$stamp = (Get-Date -Format "yyyyMMdd-HHmmss")
$step  = "cv-step-b6b1a-fix-domfilter-tsx-parser-v0_1"

# Root robusto
$root = $null
if ($PSScriptRoot -and $PSScriptRoot.Trim().Length -gt 0) {
  $root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
} else {
  $root = (Get-Location).Path
}

$bootstrap = Join-Path $root "tools\_bootstrap.ps1"
if (Test-Path -LiteralPath $bootstrap) { . $bootstrap }

function EnsureDirLocal([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}
function Rel([string]$base, [string]$full) {
  try { return [System.IO.Path]::GetRelativePath($base, $full) } catch { return $full }
}
function WriteUtf8NoBomSafe([string]$p, [string]$content) {
  if (Get-Command WriteUtf8NoBom -ErrorAction SilentlyContinue) { WriteUtf8NoBom $p $content; return }
  [IO.File]::WriteAllText($p, $content, [Text.UTF8Encoding]::new($false))
}
function BackupFileSafe([string]$p) {
  if (Get-Command BackupFile -ErrorAction SilentlyContinue) { return (BackupFile $p) }
  $bkDir = Join-Path $root "tools\_patch_backup"
  EnsureDirLocal $bkDir
  $leaf = Split-Path -Leaf $p
  $dest = Join-Path $bkDir ($stamp + "-" + $leaf + ".bak")
  Copy-Item -LiteralPath $p -Destination $dest -Force
  return $dest
}

Write-Host ("== " + $step + " == " + $stamp) -ForegroundColor Cyan
Write-Host ("[DIAG] Root: " + $root)

$reportsDir = Join-Path $root "reports"
EnsureDirLocal $reportsDir
EnsureDirLocal (Join-Path $root "tools\_patch_backup")

$domPath = Join-Path $root "src\components\v2\Cv2DomFilterClient.tsx"
if (-not (Test-Path -LiteralPath $domPath)) { throw ("[STOP] nao achei: " + (Rel $root $domPath)) }

$bk = BackupFileSafe $domPath

# Reescreve o arquivo evitando generics <T> (que em TSX pode virar JSX) e evitando chamadas quebradas
$lines = @(
  '"use client";',
  '',
  'import { useEffect, useRef, useState } from "react";',
  '',
  'type Props = {',
  '  rootId: string;',
  '  placeholder?: string;',
  '};',
  '',
  'type Stats = { total: number; shown: number };',
  '',
  'function foldText(input: string): string {',
  '  const raw = (input ?? "").toString();',
  '  try {',
  '    return raw',
  '      .normalize("NFD")',
  '      .replace(/[\u0300-\u036f]/g, "")',
  '      .toLowerCase();',
  '  } catch {',
  '    return raw.toLowerCase();',
  '  }',
  '}',
  '',
  'function collectItems(root: HTMLElement): HTMLElement[] {',
  '  const selectors = [".cv2-card", "[data-cv2-card]", "article", "li"];',
  '  for (const sel of selectors) {',
  '    const nodes = Array.from(root.querySelectorAll(sel));',
  '    const els = nodes.filter((n) => n instanceof HTMLElement) as HTMLElement[];',
  '    const filtered = els.filter((el) => !el.closest("[data-cv2-filter-ui=\\"1\\"]"));',
  '    if (filtered.length > 0) return filtered;',
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
  '    if (!root) {',
  '      itemsRef.current = [];',
  '      setStats({ total: 0, shown: 0 });',
  '      return;',
  '    }',
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
  '  const canClear = query.trim().length > 0;',
  '',
  '  return (',
  '    <div',
  '      data-cv2-filter-ui="1"',
  '      style={{ display: "flex", gap: 10, alignItems: "center", flexWrap: "wrap", margin: "10px 0 14px" }}',
  '    >',
  '      <label style={{ display: "flex", alignItems: "center", gap: 8 }}>',
  '        <span className="cv2-muted" style={{ fontSize: 12 }}>filtrar</span>',
  '        <input',
  '          type="search"',
  '          value={query}',
  '          onChange={(e) => setQuery(e.target.value)}',
  '          onKeyDown={(e) => { if (e.key === "Escape") setQuery(""); }}',
  '          placeholder={placeholder ?? "buscar..."}',
  '          style={{',
  '            padding: "10px 12px",',
  '            borderRadius: 12,',
  '            border: "1px solid var(--cv2-line, rgba(255,255,255,.10))",',
  '            background: "rgba(0,0,0,.22)",',
  '            color: "inherit",',
  '            outline: "none",',
  '            minWidth: 220,',
  '          }}',
  '        />',
  '      </label>',
  '',
  '      {canClear ? (',
  '        <button type="button" onClick={() => setQuery("")} className="cv2-chip" style={{ cursor: "pointer" }}>',
  '          limpar',
  '        </button>',
  '      ) : null}',
  '',
  '      <span className="cv2-muted" style={{ fontSize: 12 }}>{stats.shown}/{stats.total}</span>',
  '    </div>',
  '  );',
  '}',
  ''
)

WriteUtf8NoBomSafe $domPath ($lines -join "`n")
Write-Host ("[PATCH] wrote -> " + (Rel $root $domPath))
Write-Host ("[BK] " + (Rel $root $bk))

# Report
$reportPath = Join-Path $reportsDir ($step + "-" + $stamp + ".md")
$rep = @()
$rep += "# CV — Step B6b1a: Fix TSX parser (Cv2DomFilterClient)"
$rep += ""
$rep += "- when: " + $stamp
$rep += "- file: " + (Rel $root $domPath)
$rep += "- backup: " + (Rel $root $bk)
$rep += ""
$rep += "## VERIFY"
$rep += "- tools/cv-verify.ps1"
WriteUtf8NoBomSafe $reportPath ($rep -join "`n")
Write-Host ("[REPORT] " + (Rel $root $reportPath))

# Verify
$verify = Join-Path $root "tools\cv-verify.ps1"
if (Test-Path -LiteralPath $verify) {
  Write-Host ("[RUN] " + (Rel $root $verify))
  & pwsh -NoProfile -ExecutionPolicy Bypass -File $verify
} else {
  Write-Host "[RUN] npm run lint"
  & npm run lint
  Write-Host "[RUN] npm run build"
  & npm run build
}

Write-Host "[OK] B6b1a aplicado." -ForegroundColor Green
if ($OpenReport) { try { Invoke-Item $reportPath } catch {} }