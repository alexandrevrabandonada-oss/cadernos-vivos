param(
  [switch]$OpenReport
)

$ErrorActionPreference = "Stop"

function EnsureDirLocal([string]$p) {
  if ([string]::IsNullOrWhiteSpace($p)) { return }
  if (!(Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

function WriteUtf8NoBomLocal([string]$filePath, [string]$content) {
  $enc = New-Object System.Text.UTF8Encoding($false)
  EnsureDirLocal (Split-Path -Parent $filePath)
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

function EnsureImportAfterImports([string]$text, [string]$importLine) {
  if ($text -match [regex]::Escape($importLine)) { return $text }
  $lines = $text -split "`r?`n"
  $lastImport = -1
  for ($i=0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match "^\s*import\b") { $lastImport = $i }
  }
  if ($lastImport -ge 0) {
    $before = $lines[0..$lastImport]
    $after = @()
    if ($lastImport + 1 -le $lines.Length - 1) { $after = $lines[($lastImport+1)..($lines.Length-1)] }
    return (@($before + @($importLine) + $after) -join "`n")
  }
  return ($importLine + "`n" + $text)
}

function FindTagRange([string[]]$lines, [int]$startIdx, [string]$tagName) {
  # retorna @{ Start = x; End = y } ou $null
  if ($startIdx -lt 0) { return $null }
  $endIdx = -1
  for ($i=$startIdx; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match "/>\s*$") { $endIdx = $i; break }
    if ($lines[$i] -match "</\s*$tagName\s*>") { $endIdx = $i; break }
  }
  if ($endIdx -lt 0) { $endIdx = $startIdx }
  return @{ Start = $startIdx; End = $endIdx }
}

function InsertAfterRange([string]$text, [hashtable]$range, [string]$lineToInsert) {
  $lines = $text -split "`r?`n"
  # evita duplicar
  if ($text -match [regex]::Escape($lineToInsert.Trim())) { return $text }

  $idx = [int]$range.End
  $new = @()
  if ($idx -ge 0) { $new += $lines[0..$idx] }
  $new += $lineToInsert
  if ($idx + 1 -le $lines.Length - 1) { $new += $lines[($idx+1)..($lines.Length-1)] }
  return ($new -join "`n")
}

# -----------------------
# Root
# -----------------------
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
$step = "cv-step-b6f-v2-provas-grouped-stabilize-v0_1"

Write-Host ("== " + $step + " == " + $stamp)
Write-Host ("[DIAG] Root: " + $root)

# -----------------------
# Targets
# -----------------------
$compRel = "src\components\v2\Cv2ProvasGroupedClient.tsx"
$pageRel = "src\app\c\[slug]\v2\provas\page.tsx"
$cssRel  = "src\app\globals.css"

$comp = Join-Path $root $compRel
$page = Join-Path $root $pageRel
$css  = Join-Path $root $cssRel

if (!(Test-Path -LiteralPath $page)) { throw ("[STOP] target não encontrado: " + $pageRel) }
if (!(Test-Path -LiteralPath $css))  { throw ("[STOP] globals.css não encontrado: " + $cssRel) }

# -----------------------
# PATCH 1) Rewrite component (ultra-safe)
# -----------------------
EnsureDirLocal (Split-Path -Parent $comp)

$compBk = BackupFileLocal $root $comp

$compLines = @(
'"use client";',
'',
'import { useEffect, useMemo } from "react";',
'import { useSyncExternalStore } from "react";',
'',
'type LinkItem = { href: string; text: string; domain: string };',
'type Group = { domain: string; items: LinkItem[] };',
'',
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
'function safeHost(href: string): string {',
'  try {',
'    const u = new URL(href, window.location.href);',
'    const host = String(u.hostname || "").toLowerCase();',
'    if (!host) return "outros";',
'    return host.startsWith("www.") ? host.slice(4) : host;',
'  } catch {',
'    return "outros";',
'  }',
'}',
'',
'function normalizeText(input: unknown): string {',
'  const raw = (input == null ? "" : String(input));',
'  const trimmed = raw.trim();',
'  if (!trimmed) return "";',
'  // colapsa whitespace sem depender de regex unicode complexo',
'  return trimmed.split(/\\s+/g).join(" ");',
'}',
'',
'function escapeMdText(s: string): string {',
'  // sem regex: mais "tijolo-safe"',
'  return s.split("[").join("\\\\[").split("]").join("\\\\]");',
'}',
'',
'function copyText(text: string): void {',
'  try {',
'    if (navigator.clipboard && typeof navigator.clipboard.writeText === "function") {',
'      void navigator.clipboard.writeText(text);',
'      return;',
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
'    void document.execCommand("copy");',
'    document.body.removeChild(ta);',
'  } catch {',
'    // ignore',
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
'  useEffect(() => {',
'    let t: number | null = null;',
'    const schedule = () => {',
'      if (t != null) { window.clearTimeout(t); t = null; }',
'      t = window.setTimeout(() => { t = null; scanNow(); }, 50);',
'    };',
'    const scanNow = () => {',
'      try {',
'        const rootEl = document.getElementById(rootId);',
'        if (!rootEl) {',
'          store.set({ items: [], lastScan: Date.now(), error: "root_not_found" });',
'          return;',
'        }',
'        const base = (listSelector ? (rootEl.querySelector(listSelector) as HTMLElement | null) : null) || rootEl;',
'        const anchors = Array.from(base.querySelectorAll("a[href]")) as HTMLAnchorElement[];',
'        const items: LinkItem[] = [];',
'        for (const a of anchors) {',
'          if (a.closest("[data-cv2-filter-ui=\\"1\\"]")) continue;',
'          if (a.closest("[data-cv2-provas-tools=\\"1\\"]")) continue;',
'          if (a.closest("nav")) continue;',
'          const href = a.getAttribute("href") || "";',
'          if (!href) continue;',
'          const domAttr = (a.getAttribute("data-domain") || "").trim();',
'          const domain = domAttr ? domAttr : safeHost(href);',
'          const text = normalizeText(a.textContent) || href;',
'          const el = a as unknown as HTMLElement;',
'          if (el.closest("[hidden]")) continue;',
'          try {',
'            const cs = window.getComputedStyle(el);',
'            if (cs.display === "none" || cs.visibility === "hidden") continue;',
'          } catch {',
'            // ignore',
'          }',
'          items.push({ href, text, domain });',
'        }',
'        store.set({ items, lastScan: Date.now(), error: null });',
'      } catch {',
'        store.set({ items: [], lastScan: Date.now(), error: "scan_failed" });',
'      }',
'    };',
'',
'    schedule();',
'    const rootEl = document.getElementById(rootId);',
'    if (!rootEl) return () => { if (t != null) window.clearTimeout(t); };',
'',
'    const onAny = () => schedule();',
'    rootEl.addEventListener("input", onAny, true);',
'    rootEl.addEventListener("change", onAny, true);',
'    rootEl.addEventListener("click", onAny, true);',
'',
'    return () => {',
'      if (t != null) window.clearTimeout(t);',
'      rootEl.removeEventListener("input", onAny, true);',
'      rootEl.removeEventListener("change", onAny, true);',
'      rootEl.removeEventListener("click", onAny, true);',
'    };',
'  }, [rootId, listSelector]);',
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
'        <button',
'          type="button"',
'          className="cv2-chip"',
'          onClick={() => {',
'            const md: string[] = [];',
'            md.push("# Provas (por domínio)");',
'            md.push("");',
'            for (const g of groups) {',
'              md.push("## " + g.domain + " (" + g.items.length + ")");',
'              for (const it of g.items) {',
'                const safeText = escapeMdText(it.text);',
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
'',
'      <div style={{ marginTop: 10 }}>',
'        {groups.map((g) => {',
'          const isOpen = (snap.open && typeof snap.open[g.domain] === "boolean") ? snap.open[g.domain] : true;',
'          return (',
'            <details',
'              key={g.domain}',
'              open={isOpen}',
'              onToggle={(e) => {',
'                const d = e.currentTarget as HTMLDetailsElement;',
'                store.setOpen(g.domain, !!d.open);',
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
'}',
'',
'export default Cv2ProvasGroupedClient;'
)

WriteUtf8NoBomLocal $comp ($compLines -join "`n")
Write-Host ("[PATCH] wrote -> " + (RelLocal $root $comp))
if ($compBk) { Write-Host ("[BK] " + (RelLocal $root $compBk)) }

# -----------------------
# PATCH 2) Page: ensure import + ensure wrapper + ensure usage
# -----------------------
$pageRaw = Get-Content -Raw -LiteralPath $page
if ($null -eq $pageRaw -or $pageRaw.Trim().Length -eq 0) { throw "[STOP] page.tsx vazio" }

$pageBk = BackupFileLocal $root $page

# detect rootId from DomFilter usage (fallback)
$rootId = "cv2-provas-root"
$m = [regex]::Match($pageRaw, 'Cv2DomFilterClient[^>]*\brootId\s*=\s*["''](?<id>[^"''\s>]+)["'']', 'IgnoreCase')
if ($m.Success) { $rootId = $m.Groups["id"].Value }

$pagePatched = $pageRaw
$pagePatched = EnsureImportAfterImports $pagePatched 'import { Cv2ProvasGroupedClient } from "@/components/v2/Cv2ProvasGroupedClient";'

# ensure wrapper around ProvasV2
if ($pagePatched -notmatch 'data-cv2-provas-list\s*=\s*["'']1["'']') {
  $lines = $pagePatched -split "`r?`n"
  $start = -1
  for ($i=0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match "<\s*ProvasV2\b") { $start = $i; break }
  }
  if ($start -ge 0) {
    $end = $start
    for ($j=$start; $j -lt $lines.Length; $j++) {
      if ($lines[$j] -match "/>\s*$") { $end = $j; break }
      if ($lines[$j] -match "</\s*ProvasV2\s*>") { $end = $j; break }
    }
    $indent = ""
    if ($lines[$start] -match "^(\s+)") { $indent = $matches[1] }
    $openLine = $indent + '<div data-cv2-provas-list="1">'
    $closeLine = $indent + '</div>'

    $new = @()
    if ($start -gt 0) { $new += $lines[0..($start-1)] }
    $new += $openLine
    $new += $lines[$start..$end]
    $new += $closeLine
    if ($end + 1 -le $lines.Length - 1) { $new += $lines[($end+1)..($lines.Length-1)] }
    $pagePatched = ($new -join "`n")
  }
}

# ensure component is used (insert after DomFilter block)
if ($pagePatched -notmatch 'Cv2ProvasGroupedClient') {
  $lines = $pagePatched -split "`r?`n"
  $start = -1
  for ($i=0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match "<\s*Cv2DomFilterClient\b") { $start = $i; break }
  }
  if ($start -ge 0) {
    $range = FindTagRange $lines $start "Cv2DomFilterClient"
    $indent = ""
    if ($lines[$range.End] -match "^(\s+)") { $indent = $matches[1] }
    $insert = $indent + '<Cv2ProvasGroupedClient rootId="' + $rootId + '" listSelector={"[data-cv2-provas-list=\"1\"]"} />'
    $pagePatched = InsertAfterRange $pagePatched $range $insert
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
# PATCH 3) globals.css (additive)
# -----------------------
$cssRaw = Get-Content -Raw -LiteralPath $css
$marker = "/* CV2 Provas grouped */"
if ($cssRaw -notmatch [regex]::Escape($marker)) {
  $cssBk = BackupFileLocal $root $css
  $add = @(
    "",
    $marker,
    ".cv2-details { border-top: 1px solid var(--cv2-line, rgba(255,255,255,0.08)); padding-top: 8px; margin-top: 8px; }",
    ".cv2-summary { cursor: pointer; list-style: none; display: flex; align-items: center; gap: 8px; }",
    ".cv2-summary::-webkit-details-marker { display: none; }",
    ".cv2-list { margin: 8px 0 0 18px; padding: 0; }",
    ".cv2-li { margin: 6px 0; }",
    ".cv2-link { text-decoration: underline; text-underline-offset: 3px; }"
  ) -join "`n"
  WriteUtf8NoBomLocal $css ($cssRaw + $add)
  Write-Host ("[PATCH] css -> " + (RelLocal $root $css))
  if ($cssBk) { Write-Host ("[BK] " + (RelLocal $root $cssBk)) }
} else {
  Write-Host "[PATCH] globals.css: bloco já existe (skip)"
}

# -----------------------
# REPORT
# -----------------------
EnsureDirLocal (Join-Path $root "reports")
$reportPath = Join-Path $root ("reports\" + $step + "-" + $stamp + ".md")

$rep = @()
$rep += "# CV — B6f: Stabilize Provas V2 grouped panel"
$rep += ""
$rep += "- when: $stamp"
$rep += "- component: $compRel"
$rep += "- page: $pageRel"
$rep += "- css: $cssRel"
$rep += ""
$rep += "## O que muda"
$rep += "- Reescreve Cv2ProvasGroupedClient.tsx (parser-safe) com named + default export."
$rep += "- Garante import + uso do componente na page.tsx (sem 'importado e não usado')."
$rep += '- Garante wrapper data-cv2-provas-list="1" ao redor do ProvasV2.'
$rep += "- Adiciona CSS mínimo para details/summary (aditivo)."
$rep += ""
$rep += "## VERIFY"
$rep += "- tools/cv-verify.ps1"

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

Write-Host "[OK] B6f aplicado."

if ($OpenReport) {
  try { Invoke-Item $reportPath } catch { }
}