param([switch]$OpenReport)

$ErrorActionPreference = 'Stop'

# -----------------------
# Local helpers (standalone)
# -----------------------
function EnsureDirLocal([string]$p) {
  if ([string]::IsNullOrWhiteSpace($p)) { return }
  if (!(Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

function WriteUtf8NoBomLocal([string]$path, [string]$content) {
  if ([string]::IsNullOrWhiteSpace($path)) { throw '[STOP] WriteUtf8NoBomLocal: path vazio' }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [IO.File]::WriteAllText($path, $content, $enc)
}

function BackupFileLocal([string]$root, [string]$filePath) {
  $stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
  $bkDir = Join-Path $root 'tools\_patch_backup'
  EnsureDirLocal $bkDir
  $leaf = Split-Path -Leaf $filePath
  $dest = Join-Path $bkDir ($stamp + '-' + $leaf + '.bak')
  Copy-Item -LiteralPath $filePath -Destination $dest -Force
  return $dest
}

function RelLocal([string]$root, [string]$fullPath) {
  try {
    $rp = (Resolve-Path -LiteralPath $fullPath).Path
    $rr = $root.TrimEnd('\','/')
    if ($rp.StartsWith($rr)) {
      return $rp.Substring($rr.Length).TrimStart('\','/')
    }
    return $rp
  } catch {
    return $fullPath
  }
}

function EnsureImportAfterImportsLocal([string]$text, [string]$importLine) {
  if ($text.Contains($importLine)) { return $text }

  $lines = $text -split "`r?`n"
  $lastImport = -1
  for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match '^\s*import\b') { $lastImport = $i }
  }

  if ($lastImport -ge 0) {
    $newLines = @()
    if ($lastImport -ge 0) { $newLines += $lines[0..$lastImport] }
    $newLines += $importLine
    if ($lastImport + 1 -le $lines.Length - 1) { $newLines += $lines[($lastImport+1)..($lines.Length-1)] }
    return ($newLines -join "`n")
  }

  return ($importLine + "`n" + $text)
}

function InsertLineAfterFirstMatchLocal([string]$text, [string]$pattern, [string]$lineToInsert) {
  $lines = $text -split "`r?`n"
  for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match $pattern) {
      # evita duplicar
      if (($i + 1) -lt $lines.Length -and $lines[$i+1].Contains($lineToInsert.Trim())) { return $text }
      $indent = ''
      if ($lines[$i] -match '^(\s+)') { $indent = $matches[1] }

      $new = @()
      if ($i -ge 0) { $new += $lines[0..$i] }
      $new += ($indent + $lineToInsert)
      if ($i + 1 -le $lines.Length - 1) { $new += $lines[($i+1)..($lines.Length-1)] }
      return ($new -join "`n")
    }
  }
  return $text
}

function DetectRepoRootLocal() {
  $here = $PSScriptRoot
  if ([string]::IsNullOrWhiteSpace($here)) { $here = (Get-Location).Path }

  # Caso 1: rodando no root (package.json aqui)
  if (Test-Path -LiteralPath (Join-Path $here 'package.json')) {
    return (Resolve-Path -LiteralPath $here).Path
  }

  # Caso 2: rodando dentro de tools (package.json em ..)
  $up = Join-Path $here '..'
  if (Test-Path -LiteralPath (Join-Path $up 'package.json')) {
    return (Resolve-Path -LiteralPath $up).Path
  }

  # fallback
  return (Resolve-Path -LiteralPath $here).Path
}

# -----------------------
# Root
# -----------------------
$root = DetectRepoRootLocal
$stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
$step = 'cv-step-b6e-v2-provas-domain-sections-mdcopy-v0_1'
Write-Host ('== ' + $step + ' == ' + $stamp)
Write-Host ('[DIAG] Root: ' + $root)

EnsureDirLocal (Join-Path $root 'reports')

# -----------------------
# Targets
# -----------------------
$pageRel = 'src\app\c\[slug]\v2\provas\page.tsx'
$page = Join-Path $root $pageRel
if (!(Test-Path -LiteralPath $page)) { throw ('[STOP] target nao encontrado: ' + $pageRel) }

$compRel = 'src\components\v2\Cv2ProvasGroupedClient.tsx'
$comp = Join-Path $root $compRel

$cssRel = 'src\app\globals.css'
$css = Join-Path $root $cssRel
if (!(Test-Path -LiteralPath $css)) { throw ('[STOP] globals.css nao encontrado: ' + $cssRel) }

# -----------------------
# PATCH 1) Create component
# -----------------------
EnsureDirLocal (Split-Path -Parent $comp)

$compLines = @(
  '"use client";',
  '',
  'import { useEffect, useMemo, useRef } from "react";',
  'import { useSyncExternalStore } from "react";',
  '',
  'type LinkItem = { href: string; text: string; domain: string };',
  'type Group = { domain: string; items: LinkItem[] };',
  '',
  'type Snapshot = {',
  '  items: LinkItem[];',
  '  mode: "grouped" | "off";',
  '  open: Record<string, boolean>;',
  '  lastScan: number;',
  '  error: string | null;',
  '};',
  '',
  'function createStore() {',
  '  let snap: Snapshot = { items: [], mode: "grouped", open: {}, lastScan: 0, error: null };',
  '  const listeners = new Set<() => void>();',
  '  const emit = () => { for (const fn of Array.from(listeners)) fn(); };',
  '  return {',
  '    getSnapshot: () => snap,',
  '    subscribe: (fn: () => void) => { listeners.add(fn); return () => listeners.delete(fn); },',
  '    set: (patch: Partial<Snapshot>) => { snap = { ...snap, ...patch }; emit(); },',
  '    toggleOpen: (key: string) => {',
  '      const next = { ...(snap.open || {}) };',
  '      next[key] = !next[key];',
  '      snap = { ...snap, open: next };',
  '      emit();',
  '    },',
  '    setAllOpen: (open: boolean, keys: string[]) => {',
  '      const next: Record<string, boolean> = { ...(snap.open || {}) };',
  '      for (const k of keys) next[k] = open;',
  '      snap = { ...snap, open: next };',
  '      emit();',
  '    },',
  '  };',
  '}',
  '',
  'const store = createStore();',
  '',
  'function safeHost(href: string): string {',
  '  try {',
  '    const u = new URL(href, window.location.href);',
  '    const host = (u.hostname || "").toLowerCase();',
  '    if (!host) return "outros";',
  '    return host.startsWith("www.") ? host.slice(4) : host;',
  '  } catch {',
  '    return "outros";',
  '  }',
  '}',
  '',
  'function normalizeText(input: unknown): string {',
  '  const raw = (input == null ? "" : String(input));',
  '  return raw.replace(/\\s+/g, " ").trim();',
  '}',
  '',
  'function copyText(text: string): boolean {',
  '  try {',
  '    if (navigator.clipboard && typeof navigator.clipboard.writeText === "function") {',
  '      void navigator.clipboard.writeText(text);',
  '      return true;',
  '    }',
  '  } catch {',
  '    // ignore',
  '  }',
  '  try {',
  '    const ta = document.createElement("textarea");',
  '    ta.value = text;',
  '    ta.style.position = "fixed";',
  '    ta.style.opacity = "0";',
  '    document.body.appendChild(ta);',
  '    ta.focus();',
  '    ta.select();',
  '    const ok = document.execCommand("copy");',
  '    document.body.removeChild(ta);',
  '    return ok;',
  '  } catch {',
  '    return false;',
  '  }',
  '}',
  '',
  'export type Cv2ProvasGroupedClientProps = {',
  '  rootId: string;',
  '  listSelector?: string;',
  '  title?: string;',
  '};',
  '',
  'export function Cv2ProvasGroupedClient(props: Cv2ProvasGroupedClientProps) {',
  '  const snap = useSyncExternalStore(store.subscribe, store.getSnapshot, store.getSnapshot);',
  '  const rootId = props.rootId;',
  '  const listSelector = props.listSelector;',
  '  const scheduledRef = useRef<number | null>(null);',
  '',
  '  const groups: Group[] = useMemo(() => {',
  '    const by: Record<string, LinkItem[]> = {};',
  '    for (const it of snap.items) {',
  '      const key = it.domain || "outros";',
  '      if (!by[key]) by[key] = [];',
  '      by[key].push(it);',
  '    }',
  '    const domains = Object.keys(by).sort((a, b) => a.localeCompare(b));',
  '    return domains.map((d) => ({ domain: d, items: by[d] }));',
  '  }, [snap.items]);',
  '',
  '  const domainKeys = useMemo(() => groups.map((g) => g.domain), [groups]);',
  '',
  '  function scanNow() {',
  '    try {',
  '      const rootEl = document.getElementById(rootId);',
  '      if (!rootEl) {',
  '        store.set({ items: [], lastScan: Date.now(), error: "root_not_found" });',
  '        return;',
  '      }',
  '      const scope = listSelector ? (rootEl.querySelector(listSelector) as HTMLElement | null) : null;',
  '      const base = scope || rootEl;',
  '      const anchors = Array.from(base.querySelectorAll("a[href]")) as HTMLAnchorElement[];',
  '      const items: LinkItem[] = [];',
  '      for (const a of anchors) {',
  '        if (a.closest("[data-cv2-filter-ui=\\"1\\"]")) continue;',
  '        if (a.closest("[data-cv2-provas-tools=\\"1\\"]")) continue;',
  '        if (a.closest("nav")) continue;',
  '        const href = a.getAttribute("href") || "";',
  '        if (!href) continue;',
  '        const text = normalizeText(a.textContent);',
  '        const dom = (a.getAttribute("data-domain") || "").trim();',
  '        const domain = dom.length ? dom : safeHost(href);',
  '        const el = a as unknown as HTMLElement;',
  '        if (el.closest("[hidden]")) continue;',
  '        try {',
  '          const cs = window.getComputedStyle(el);',
  '          if (cs.display === "none" || cs.visibility === "hidden") continue;',
  '        } catch {',
  '          // ignore',
  '        }',
  '        items.push({ href, text: text || href, domain });',
  '      }',
  '      store.set({ items, lastScan: Date.now(), error: null });',
  '    } catch {',
  '      store.set({ items: [], lastScan: Date.now(), error: "scan_failed" });',
  '    }',
  '  }',
  '',
  '  function scheduleScan() {',
  '    if (scheduledRef.current != null) {',
  '      window.clearTimeout(scheduledRef.current);',
  '      scheduledRef.current = null;',
  '    }',
  '    scheduledRef.current = window.setTimeout(() => {',
  '      scheduledRef.current = null;',
  '      scanNow();',
  '    }, 50);',
  '  }',
  '',
  '  useEffect(() => {',
  '    scheduleScan();',
  '    const rootEl = document.getElementById(rootId);',
  '    if (!rootEl) return;',
  '    const onAny = () => scheduleScan();',
  '    rootEl.addEventListener("input", onAny, true);',
  '    rootEl.addEventListener("change", onAny, true);',
  '    rootEl.addEventListener("click", onAny, true);',
  '    return () => {',
  '      rootEl.removeEventListener("input", onAny, true);',
  '      rootEl.removeEventListener("change", onAny, true);',
  '      rootEl.removeEventListener("click", onAny, true);',
  '    };',
  '  }, [rootId, listSelector]);',
  '',
  '  if (snap.mode === "off") return null;',
  '',
  '  const headerTitle = props.title || "Por dominio";',
  '',
  '  return (',
  '    <div data-cv2-provas-tools="1" className="cv2-card" style={{ marginTop: 12 }}>',
  '      <div className="cv2-row" style={{ gap: 10, flexWrap: "wrap", alignItems: "center" }}>',
  '        <div style={{ fontWeight: 700 }}>{headerTitle}</div>',
  '        <div className="cv2-muted" style={{ fontSize: 12 }}>{snap.items.length} links</div>',
  '        <div style={{ marginLeft: "auto" }} />',
  '        <button type="button" className="cv2-chip" onClick={() => store.setAllOpen(true, domainKeys)}>Expandir</button>',
  '        <button type="button" className="cv2-chip" onClick={() => store.setAllOpen(false, domainKeys)}>Colapsar</button>',
  '        <button',
  '          type="button"',
  '          className="cv2-chip"',
  '          onClick={() => {',
  '            const md: string[] = [];',
  '            md.push("# Provas (por dominio)");',
  '            md.push("");',
  '            for (const g of groups) {',
  '              md.push("## " + g.domain + " (" + g.items.length + ")");',
  '              for (const it of g.items) {',
  '                const safeText = it.text.replace(/\\]/g, "\\\\]");',
  '                md.push("- [" + safeText + "](" + it.href + ")");',
  '              }',
  '              md.push("");',
  '            }',
  '            copyText(md.join("\\n"));',
  '          }}',
  '        >',
  '          Copiar (MD)',
  '        </button>',
  '      </div>',
  '      <div style={{ marginTop: 10 }}>',
  '        {groups.map((g) => {',
  '          const isOpen = (snap.open && typeof snap.open[g.domain] === "boolean") ? snap.open[g.domain] : true;',
  '          return (',
  '            <details key={g.domain} open={isOpen} onToggle={() => store.toggleOpen(g.domain)} className="cv2-details">',
  '              <summary className="cv2-summary">',
  '                <span style={{ fontWeight: 650 }}>{g.domain}</span>',
  '                <span className="cv2-muted" style={{ marginLeft: 8, fontSize: 12 }}>{g.items.length}</span>',
  '              </summary>',
  '              <ul className="cv2-list">',
  '                {g.items.map((it) => (',
  '                  <li key={it.href} className="cv2-li">',
  '                    <a className="cv2-link" href={it.href} target="_blank" rel="noreferrer">{it.text}</a>',
  '                  </li>',
  '                ))}',
  '              </ul>',
  '            </details>',
  '          );',
  '        })}',
  '      </div>',
  '      {snap.error ? <div className="cv2-muted" style={{ marginTop: 10, fontSize: 12 }}>scan: {snap.error}</div> : null}',
  '    </div>',
  '  );',
  '}'
)

WriteUtf8NoBomLocal $comp ($compLines -join "`n")
Write-Host ('[PATCH] wrote -> ' + (RelLocal $root $comp))

# -----------------------
# PATCH 2) Provas page
# -----------------------
$pageRaw = Get-Content -Raw -LiteralPath $page
if ($null -eq $pageRaw -or $pageRaw.Trim().Length -eq 0) { throw '[STOP] page.tsx vazio' }

$pageBk = BackupFileLocal $root $page

$pagePatched = $pageRaw
$pagePatched = EnsureImportAfterImportsLocal $pagePatched 'import { Cv2ProvasGroupedClient } from "@/components/v2/Cv2ProvasGroupedClient";'

$rootId = 'cv2-provas-root'
$m = [regex]::Match($pagePatched, 'Cv2DomFilterClient[^>]*rootId\s*=\s*"(?<id>[^"]+)"', 'IgnoreCase')
if ($m.Success) { $rootId = $m.Groups['id'].Value }

if ($pagePatched -notmatch 'Cv2ProvasGroupedClient') {
  $insert = '<Cv2ProvasGroupedClient rootId="' + $rootId + '" listSelector="[data-cv2-provas-list=\"1\"]" />'
  $pagePatched = InsertLineAfterFirstMatchLocal $pagePatched 'Cv2DomFilterClient' $insert
}

if ($pagePatched -notmatch 'data-cv2-provas-list="1"') {
  $lines = $pagePatched -split "`r?`n"
  $idx = -1
  for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match '<\s*ProvasV2\b') { $idx = $i; break }
  }
  if ($idx -ge 0) {
    $indent = ''
    if ($lines[$idx] -match '^(\s+)') { $indent = $matches[1] }
    $openLine = ($indent + '<div data-cv2-provas-list="1">')
    $closeLine = ($indent + '</div>')

    $newLines = @()
    if ($idx -gt 0) { $newLines += $lines[0..($idx-1)] }
    $newLines += $openLine
    $newLines += $lines[$idx]
    $newLines += $closeLine
    if ($idx + 1 -le $lines.Length - 1) { $newLines += $lines[($idx+1)..($lines.Length-1)] }
    $pagePatched = ($newLines -join "`n")
  }
}

if ($pagePatched -ne $pageRaw) {
  WriteUtf8NoBomLocal $page $pagePatched
  Write-Host ('[PATCH] wrote -> ' + (RelLocal $root $page))
  Write-Host ('[BK] ' + (RelLocal $root $pageBk))
} else {
  Write-Host '[PATCH] page.tsx: no changes needed'
}

# -----------------------
# PATCH 3) globals.css (additive)
# -----------------------
$cssRaw = Get-Content -Raw -LiteralPath $css
$marker = '/* CV2 Provas grouped */'
if ($cssRaw -notmatch [regex]::Escape($marker)) {
  $cssBk = BackupFileLocal $root $css
  $cssAdd = @(
    '',
    $marker,
    '.cv2-details { border-top: 1px solid var(--cv2-line, rgba(255,255,255,0.08)); padding-top: 8px; margin-top: 8px; }',
    '.cv2-summary { cursor: pointer; list-style: none; display: flex; align-items: center; gap: 8px; }',
    '.cv2-summary::-webkit-details-marker { display: none; }',
    '.cv2-list { margin: 8px 0 0 18px; padding: 0; }',
    '.cv2-li { margin: 6px 0; }',
    '.cv2-link { text-decoration: underline; text-underline-offset: 3px; }'
  ) -join "`n"
  WriteUtf8NoBomLocal $css ($cssRaw + $cssAdd)
  Write-Host ('[PATCH] css -> ' + (RelLocal $root $css))
  Write-Host ('[BK] ' + (RelLocal $root $cssBk))
} else {
  Write-Host '[PATCH] globals.css: bloco ja existe (skip)'
}

# -----------------------
# REPORT + VERIFY
# -----------------------
$reportPath = Join-Path $root ('reports\' + $step + '-' + $stamp + '.md')
$rep = @()
$rep += '# CV — B6e: Provas V2 por dominio + Copiar Markdown'
$rep += ''
$rep += ('- when: ' + $stamp)
$rep += ('- component: ' + $compRel)
$rep += ('- page: ' + $pageRel)
$rep += ''
$rep += '## VERIFY'
$rep += '- tools\cv-verify.ps1'
WriteUtf8NoBomLocal $reportPath ($rep -join "`n")
Write-Host ('[REPORT] ' + (RelLocal $root $reportPath))

$verify = Join-Path $root 'tools\cv-verify.ps1'
if (Test-Path -LiteralPath $verify) {
  Write-Host ('[RUN] ' + (RelLocal $root $verify))
  & $verify
} else {
  Write-Host '[WARN] tools\cv-verify.ps1 nao encontrado — pulei verify'
}

Write-Host '[OK] B6e aplicado.'

if ($OpenReport) {
  try { Invoke-Item $reportPath } catch { }
}