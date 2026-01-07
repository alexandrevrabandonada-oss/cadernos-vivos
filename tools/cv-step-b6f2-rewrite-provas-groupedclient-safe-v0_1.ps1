param([switch]$OpenReport)

$ErrorActionPreference = "Stop"

function EnsureDirLocal([string]$p) {
  if ([string]::IsNullOrWhiteSpace($p)) { return }
  if (!(Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}
function WriteUtf8NoBomLocal([string]$filePath, [string]$content) {
  $enc = New-Object System.Text.UTF8Encoding($false)
  $dir = Split-Path -Parent $filePath
  if ($dir) { EnsureDirLocal $dir }
  [IO.File]::WriteAllText($filePath, $content, $enc)
}
function BackupFileLocal([string]$root, [string]$filePath) {
  if (!(Test-Path -LiteralPath $filePath)) { return $null }
  $stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
  $bkDir = Join-Path $root "tools\_patch_backup"
  EnsureDirLocal $bkDir
  $leaf = Split-Path -Leaf $filePath
  $dest = Join-Path $bkDir ($stamp + "-" + $leaf + ".bak")
  Copy-Item -LiteralPath $filePath -Destination $dest -Force
  return $dest
}
function RelLocal([string]$root, [string]$fullPath) {
  try {
    $rp = (Resolve-Path -LiteralPath $fullPath).Path
    $rr = $root.TrimEnd("\","/")
    if ($rp.StartsWith($rr)) { return $rp.Substring($rr.Length).TrimStart("\","/") }
    return $rp
  } catch { return $fullPath }
}
function EnsureImportAfterImportsLocal([string]$text, [string]$importLine) {
  if ($text -match [regex]::Escape($importLine)) { return $text }
  $lines = $text -split "`r?`n"
  $lastImport = -1
  for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match "^\s*import\b") { $lastImport = $i }
  }
  if ($lastImport -ge 0) {
    $before = $lines[0..$lastImport]
    $after  = @()
    if ($lastImport + 1 -le $lines.Length - 1) { $after = $lines[($lastImport+1)..($lines.Length-1)] }
    $newLines = @()
    $newLines += $before
    $newLines += $importLine
    $newLines += $after
    return ($newLines -join "`n")
  }
  return ($importLine + "`n" + $text)
}
function InsertLineAfterFirstMatchLocal([string]$text, [string]$pattern, [string]$lineToInsert) {
  $lines = $text -split "`r?`n"
  for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match $pattern) {
      if ($text -match [regex]::Escape($lineToInsert)) { return $text }
      $indent = ""
      if ($lines[$i] -match "^(\s+)") { $indent = $matches[1] }
      $new = @()
      if ($i -ge 0) { $new += $lines[0..$i] }
      $new += ($indent + $lineToInsert)
      if ($i + 1 -le $lines.Length - 1) { $new += $lines[($i+1)..($lines.Length-1)] }
      return ($new -join "`n")
    }
  }
  return $text
}

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
$step = "cv-step-b6f2-rewrite-provas-groupedclient-safe-v0_1"

Write-Host ("== " + $step + " == " + $stamp)
Write-Host ("[DIAG] Root: " + $root)

# targets
$compRel = "src\components\v2\Cv2ProvasGroupedClient.tsx"
$comp = Join-Path $root $compRel
$pageRel = "src\app\c\[slug]\v2\provas\page.tsx"
$page = Join-Path $root $pageRel
$cssRel = "src\app\globals.css"
$css = Join-Path $root $cssRel

if (!(Test-Path -LiteralPath $page)) { throw ("[STOP] page não encontrada: " + $pageRel) }
if (!(Test-Path -LiteralPath $css))  { throw ("[STOP] globals.css não encontrado: " + $cssRel) }

EnsureDirLocal (Split-Path -Parent $comp)

# -----------------------
# PATCH 1) rewrite component (parser-safe)
# -----------------------
$bk1 = BackupFileLocal $root $comp

$lines = @(
  '"use client";',
  '',
  'import { useEffect, useMemo, useRef } from "react";',
  'import { useSyncExternalStore } from "react";',
  '',
  'type LinkItem = { href: string; text: string; domain: string };',
  'type Group = { domain: string; items: LinkItem[] };',
  'type Snapshot = {',
  '  items: LinkItem[];',
  '  open: Record<string, boolean>;',
  '  lastScan: number;',
  '  error: string | null;',
  '};',
  '',
  'function createStore() {',
  '  let snap: Snapshot = { items: [], open: {}, lastScan: 0, error: null };',
  '  const listeners = new Set<() => void>();',
  '  const emit = () => { for (const fn of Array.from(listeners)) fn(); };',
  '  return {',
  '    getSnapshot: () => snap,',
  '    subscribe: (fn: () => void) => { listeners.add(fn); return () => listeners.delete(fn); },',
  '    set: (patch: Partial<Snapshot>) => { snap = { ...snap, ...patch }; emit(); },',
  '    setOpen: (key: string, isOpen: boolean) => {',
  '      const next: Record<string, boolean> = { ...(snap.open || {}) };',
  '      next[key] = isOpen;',
  '      snap = { ...snap, open: next };',
  '      emit();',
  '    },',
  '    setAllOpen: (isOpen: boolean, keys: string[]) => {',
  '      const next: Record<string, boolean> = { ...(snap.open || {}) };',
  '      for (const k of keys) next[k] = isOpen;',
  '      snap = { ...snap, open: next };',
  '      emit();',
  '    },',
  '  };',
  '}',
  '',
  'const store = createStore();',
  '',
  'function normalizeText(input: unknown): string {',
  '  const raw = (input == null ? "" : String(input));',
  '  let out = "";',
  '  let prevSpace = false;',
  '  for (let i = 0; i < raw.length; i++) {',
  '    const ch = raw[i];',
  '    const isSpace = (ch <= " ") || (ch === "\\u00A0");',
  '    if (isSpace) {',
  '      if (!prevSpace) { out += " "; prevSpace = true; }',
  '    } else {',
  '      out += ch;',
  '      prevSpace = false;',
  '    }',
  '  }',
  '  return out.trim();',
  '}',
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
  'function escapeMdText(text: string): string {',
  '  // escapa só o que quebra link-text (])',
  '  return text.split("]").join("\\\\]");',
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
  '      const rootEl = document.getElementById(props.rootId);',
  '      if (!rootEl) {',
  '        store.set({ items: [], lastScan: Date.now(), error: "root_not_found" });',
  '        return;',
  '      }',
  '      const scope = props.listSelector ? (rootEl.querySelector(props.listSelector) as HTMLElement | null) : null;',
  '      const base = scope || rootEl;',
  '      const anchors = Array.from(base.querySelectorAll("a[href]")) as HTMLAnchorElement[];',
  '      const items: LinkItem[] = [];',
  '      for (const a of anchors) {',
  '        if (a.closest(''[data-cv2-filter-ui="1"]'')) continue;',
  '        if (a.closest(''[data-cv2-provas-tools="1"]'')) continue;',
  '        if (a.closest("nav")) continue;',
  '        const href = a.getAttribute("href") || "";',
  '        if (!href) continue;',
  '        const el = a as unknown as HTMLElement;',
  '        if (el.closest("[hidden]")) continue;',
  '        try {',
  '          const cs = window.getComputedStyle(el);',
  '          if (cs.display === "none" || cs.visibility === "hidden") continue;',
  '        } catch {',
  '          // ignore',
  '        }',
  '        const txt = normalizeText(a.textContent || "");',
  '        const domAttr = normalizeText(a.getAttribute("data-domain") || "");',
  '        const domain = domAttr.length ? domAttr : safeHost(href);',
  '        items.push({ href, text: (txt.length ? txt : href), domain });',
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
  '    }, 60);',
  '  }',
  '',
  '  useEffect(() => {',
  '    scheduleScan();',
  '    const rootEl = document.getElementById(props.rootId);',
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
  '  }, [props.rootId, props.listSelector]);',
  '',
  '  const headerTitle = props.title || "Por domínio";',
  '',
  '  return (',
  '    <div data-cv2-provas-tools="1" className="cv2-card" style={{ marginTop: 12 }}>',
  '      <div className="cv2-row" style={{ gap: 10, flexWrap: "wrap", alignItems: "center" }}>',
  '        <div style={{ fontWeight: 700 }}>{headerTitle}</div>',
  '        <div className="cv2-muted" style={{ fontSize: 12 }}>{snap.items.length} links</div>',
  '        <div style={{ marginLeft: "auto" }} />',
  '        <button type="button" className="cv2-chip" onClick={() => store.setAllOpen(true, domainKeys)}>Expandir</button>',
  '        <button type="button" className="cv2-chip" onClick={() => store.setAllOpen(false, domainKeys)}>Colapsar</button>',
  '        <button type="button" className="cv2-chip" onClick={() => {',
  '          const md: string[] = [];',
  '          md.push("# Provas (por domínio)");',
  '          md.push("");',
  '          for (const g of groups) {',
  '            md.push("## " + g.domain + " (" + g.items.length + ")");',
  '            for (const it of g.items) {',
  '              md.push("- [" + escapeMdText(it.text) + "](" + it.href + ")");',
  '            }',
  '            md.push("");',
  '          }',
  '          copyText(md.join("\\n"));',
  '        }}>Copiar (MD)</button>',
  '      </div>',
  '',
  '      <div style={{ marginTop: 10 }}>',
  '        {groups.map((g) => {',
  '          const isOpen = (snap.open && typeof snap.open[g.domain] === "boolean") ? snap.open[g.domain] : true;',
  '          return (',
  '            <details',
  '              key={g.domain}',
  '              open={isOpen}',
  '              onToggle={(e) => {',
  '                const det = e.currentTarget as HTMLDetailsElement;',
  '                store.setOpen(g.domain, det.open);',
  '              }}',
  '              className="cv2-details"',
  '            >',
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
  '',
  '      {snap.error ? <div className="cv2-muted" style={{ marginTop: 10, fontSize: 12 }}>scan: {snap.error}</div> : null}',
  '    </div>',
  '  );',
  '}'
)

WriteUtf8NoBomLocal $comp ($lines -join "`n")
Write-Host ("[PATCH] wrote -> " + (RelLocal $root $comp))
if ($bk1) { Write-Host ("[BK] " + (RelLocal $root $bk1)) }

# -----------------------
# PATCH 2) page.tsx: ensure import + usage + wrapper
# -----------------------
$pageRaw = Get-Content -Raw -LiteralPath $page
if ($null -eq $pageRaw -or $pageRaw.Trim().Length -eq 0) { throw "[STOP] page.tsx vazio" }

$pageBk = BackupFileLocal $root $page

# ensure import
$pagePatched = $pageRaw
$pagePatched = EnsureImportAfterImportsLocal $pagePatched 'import { Cv2ProvasGroupedClient } from "@/components/v2/Cv2ProvasGroupedClient";'

# detect rootId used by DomFilter
$rootId = "cv2-provas-root"
$m = [regex]::Match($pagePatched, 'Cv2DomFilterClient[^>]*\brootId\s*=\s*["''](?<id>[^"'']+)["'']', 'IgnoreCase')
if ($m.Success) { $rootId = $m.Groups["id"].Value }

# insert component after DomFilter
if ($pagePatched -notmatch 'Cv2ProvasGroupedClient') {
  $insert = '<Cv2ProvasGroupedClient rootId="' + $rootId + '" listSelector=''[data-cv2-provas-list="1"]'' />'
  $pagePatched = InsertLineAfterFirstMatchLocal $pagePatched 'Cv2DomFilterClient' $insert
}

# ensure wrapper around ProvasV2
if ($pagePatched -notmatch 'data-cv2-provas-list\s*=\s*["'']1["'']') {
  $lines2 = $pagePatched -split "`r?`n"
  $idx = -1
  for ($i = 0; $i -lt $lines2.Length; $i++) {
    if ($lines2[$i] -match "<\s*ProvasV2\b") { $idx = $i; break }
  }
  if ($idx -ge 0) {
    $indent = ""
    if ($lines2[$idx] -match "^(\s+)") { $indent = $matches[1] }
    $openLine = ($indent + '<div data-cv2-provas-list="1">')
    $closeLine = ($indent + '</div>')
    $nl = @()
    if ($idx -gt 0) { $nl += $lines2[0..($idx-1)] }
    $nl += $openLine
    $nl += $lines2[$idx]
    $nl += $closeLine
    if ($idx + 1 -le $lines2.Length - 1) { $nl += $lines2[($idx+1)..($lines2.Length-1)] }
    $pagePatched = ($nl -join "`n")
  }
}

if ($pagePatched -ne $pageRaw) {
  WriteUtf8NoBomLocal $page $pagePatched
  Write-Host ("[PATCH] wrote -> " + (RelLocal $root $page))
  if ($pageBk) { Write-Host ("[BK] " + (RelLocal $root $pageBk)) }
} else {
  Write-Host "[PATCH] page.tsx: no changes needed"
}

# -----------------------
# REPORT
# -----------------------
EnsureDirLocal (Join-Path $root "reports")
$reportRel = "reports\" + $step + "-" + $stamp + ".md"
$reportPath = Join-Path $root $reportRel

$rep = @()
$rep += "# CV — B6f2: rewrite seguro do ProvasGroupedClient + injeção na page"
$rep += ""
$rep += ("- when: " + $stamp)
$rep += ("- component: " + $compRel)
$rep += ("- page: " + $pageRel)
$rep += ""
$rep += "## O que muda"
$rep += "- Reescreve Cv2ProvasGroupedClient.tsx (parser-safe) com painel por domínio + Copiar (MD)."
$rep += "- Injeta uso do componente em /v2/provas/page.tsx e garante wrapper data-cv2-provas-list=""1""."
$rep += ""
$rep += "## VERIFY"
$rep += "- Rodar tools/cv-verify.ps1"

WriteUtf8NoBomLocal $reportPath ($rep -join "`n")
Write-Host ("[REPORT] " + (RelLocal $root $reportPath))

# -----------------------
# VERIFY
# -----------------------
$verify = Join-Path $root "tools\cv-verify.ps1"
if (Test-Path -LiteralPath $verify) {
  Write-Host ("[RUN] " + (RelLocal $root $verify))
  & $verify
} else {
  Write-Host "[WARN] tools\cv-verify.ps1 não encontrado — pulei verify"
}

Write-Host "[OK] B6f2 aplicado."

if ($OpenReport) {
  try { Invoke-Item $reportPath } catch { }
}