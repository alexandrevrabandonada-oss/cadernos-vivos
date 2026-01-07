param([switch]$OpenReport)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$stamp = (Get-Date -Format "yyyyMMdd-HHmmss")
$step  = "cv-step-b6b1b-rewrite-domfilter-ultra-safe-v0_1"

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$bootstrap = Join-Path $PSScriptRoot "_bootstrap.ps1"
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

# --- rewrite ultra-safe (sem types/as/regex unicode)
$lines = @(
  '"use client";',
  '',
  'import { useEffect, useRef, useState } from "react";',
  '',
  'function foldText(input) {',
  '  const raw = (input == null ? "" : String(input));',
  '  const lower = raw.toLowerCase();',
  '  // remove acentos sem regex unicode (parser-safe)',
  '  try {',
  '    const n = lower.normalize("NFD");',
  '    let out = "";',
  '    for (let i = 0; i < n.length; i += 1) {',
  '      const c = n.charCodeAt(i);',
  '      if (c < 0x0300 || c > 0x036f) out += n[i];',
  '    }',
  '    return out;',
  '  } catch {',
  '    return lower;',
  '  }',
  '}',
  '',
  'function collectItems(root) {',
  '  const selectors = [".cv2-card", "[data-cv2-card]", "article", "li"];',
  '  const skip = "[data-cv2-filter-ui=\\"1\\"]";',
  '  for (const sel of selectors) {',
  '    const nodes = Array.from(root.querySelectorAll(sel));',
  '    const items = nodes.filter((n) => n instanceof HTMLElement);',
  '    const filtered = items.filter((el) => !el.closest(skip));',
  '    if (filtered.length > 0) return filtered;',
  '  }',
  '  return [];',
  '}',
  '',
  'export function Cv2DomFilterClient(props) {',
  '  const rootId = props && props.rootId ? String(props.rootId) : "";',
  '  const placeholder = props && props.placeholder ? String(props.placeholder) : "buscar...";',
  '',
  '  const [query, setQuery] = useState("");',
  '  const [stats, setStats] = useState({ total: 0, shown: 0 });',
  '  const itemsRef = useRef([]);',
  '',
  '  useEffect(() => {',
  '    const root = rootId ? document.getElementById(rootId) : null;',
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
  '    if (!items || items.length === 0) {',
  '      setStats({ total: 0, shown: 0 });',
  '      return;',
  '    }',
  '    const q = foldText(query.trim());',
  '    let shown = 0;',
  '    for (const el of items) {',
  '      const hay = foldText(el.textContent || "");',
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
  '          placeholder={placeholder}',
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

# --- report
$reportPath = Join-Path $reportsDir ($step + "-" + $stamp + ".md")
$rep = @()
$rep += "# CV — Step B6b1b: rewrite DOM filter (ultra-safe)"
$rep += ""
$rep += "- when: " + $stamp
$rep += "- file: " + (Rel $root $domPath)
$rep += "- backup: " + (Rel $root $bk)
$rep += ""
$rep += "## VERIFY"
$rep += "- tools/cv-verify.ps1"
WriteUtf8NoBomSafe $reportPath ($rep -join "`n")
Write-Host ("[REPORT] " + (Rel $root $reportPath))

# --- verify
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

Write-Host "[OK] B6b1b aplicado." -ForegroundColor Green
if ($OpenReport) { try { Invoke-Item $reportPath } catch {} }