param(
  [switch]$OpenReport
)

$ErrorActionPreference = "Stop"

# -----------------------
# Root + bootstrap (robusto)
# -----------------------
$here = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($here)) { $here = (Get-Location).Path }

$root = $null
try { $root = (Resolve-Path (Join-Path $here "..")).Path } catch { $root = $null }
if ([string]::IsNullOrWhiteSpace($root) -or !(Test-Path -LiteralPath (Join-Path $root "package.json"))) {
  $root = (Get-Location).Path
}

$bootstrap = Join-Path $root "tools\_bootstrap.ps1"
if (!(Test-Path -LiteralPath $bootstrap)) {
  $bootstrap = Join-Path $here "_bootstrap.ps1"
}
if (Test-Path -LiteralPath $bootstrap) {
  . $bootstrap
} else {
  function EnsureDir([string]$p) { if ($p -and !(Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
  function WriteUtf8NoBom([string]$p, [string]$c) { $enc = New-Object System.Text.UTF8Encoding($false); [IO.File]::WriteAllText($p,$c,$enc) }
  function BackupFile([string]$p) {
    $stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
    $bkDir = Join-Path $root "tools\_patch_backup"
    EnsureDir $bkDir
    $leaf = Split-Path -Leaf $p
    $dest = Join-Path $bkDir ($stamp + "-" + $leaf + ".bak")
    Copy-Item -LiteralPath $p -Destination $dest -Force
    return $dest
  }
  function NewReport([string]$name, [string]$content) {
    $stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
    $repDir = Join-Path $root "reports"
    EnsureDir $repDir
    $p = Join-Path $repDir ($name + "-" + $stamp + ".md")
    WriteUtf8NoBom $p $content
    return $p
  }
  function Run([string]$file, [string[]]$args) {
    & $file @args
    if ($LASTEXITCODE -ne 0) { throw ("[STOP] falhou (exit " + $LASTEXITCODE + "): " + $file + " " + ($args -join " ")) }
  }
}

$stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
$step = "cv-step-b6e1-fix-provas-grouped-parser-v0_1"
Write-Host ("== " + $step + " == " + $stamp)
Write-Host ("[DIAG] Root: " + $root)

EnsureDir (Join-Path $root "tools\_patch_backup")
EnsureDir (Join-Path $root "reports")

# -----------------------
# Helpers (in-file) - SEM regex perigoso
# -----------------------
function InsertImportAfterLastImport([string]$text, [string]$importLine) {
  if ($text.Contains($importLine)) { return $text }
  $lines = $text -split "`r?`n"
  $last = -1
  for ($i=0; $i -lt $lines.Length; $i++) {
    $t = $lines[$i].TrimStart()
    if ($t.StartsWith("import ")) { $last = $i }
  }
  if ($last -ge 0) {
    $out = @()
    if ($last -ge 0) { $out += $lines[0..$last] }
    $out += $importLine
    if ($last + 1 -le $lines.Length - 1) { $out += $lines[($last+1)..($lines.Length-1)] }
    return ($out -join "`n")
  }
  return ($importLine + "`n" + $text)
}

function InsertLineAfterFirstContains([string]$text, [string]$needle, [string]$lineToInsert) {
  $lines = $text -split "`r?`n"
  for ($i=0; $i -lt $lines.Length; $i++) {
    if ($lines[$i].Contains($needle)) {
      # evita duplicar
      for ($j=0; $j -lt $lines.Length; $j++) {
        if ($lines[$j].Contains($lineToInsert.Trim())) { return $text }
      }
      $indent = ""
      $m = [regex]::Match($lines[$i], "^(\s+)")
      if ($m.Success) { $indent = $m.Groups[1].Value }
      $out = @()
      if ($i -ge 0) { $out += $lines[0..$i] }
      $out += ($indent + $lineToInsert)
      if ($i + 1 -le $lines.Length - 1) { $out += $lines[($i+1)..($lines.Length-1)] }
      return ($out -join "`n")
    }
  }
  return $text
}

# -----------------------
# Targets
# -----------------------
$compRel = "src\components\v2\Cv2ProvasGroupedClient.tsx"
$pageRel = "src\app\c\[slug]\v2\provas\page.tsx"

$comp = Join-Path $root $compRel
$page = Join-Path $root $pageRel

if (!(Test-Path -LiteralPath $page)) { throw ("[STOP] target não encontrado: " + $pageRel) }

# -----------------------
# PATCH 1) Rewrite component (parser-safe)
# -----------------------
if (Test-Path -LiteralPath $comp) { $bkComp = BackupFile $comp } else { EnsureDir (Split-Path -Parent $comp) }

$lines = @(
'"use client";',
'',
'import { useEffect, useMemo, useRef, useSyncExternalStore } from "react";',
'',
'type LinkItem = { href: string; text: string; domain: string };',
'type Snapshot = { items: LinkItem[]; open: Record<string, boolean>; lastScan: number; error: string | null };',
'',
'function createStore() {',
'  let snap: Snapshot = { items: [], open: {}, lastScan: 0, error: null };',
'  const listeners: Set<() => void> = new Set();',
'  const emit = () => { for (const fn of Array.from(listeners)) fn(); };',
'  return {',
'    getSnapshot: () => snap,',
'    subscribe: (fn: () => void) => { listeners.add(fn); return () => listeners.delete(fn); },',
'    set: (patch: Partial<Snapshot>) => { snap = { ...snap, ...patch }; emit(); },',
'    toggleOpen: (key: string) => {',
'      const next: Record<string, boolean> = { ...(snap.open || {}) };',
'      next[key] = !(next[key] === false) ? false : true;',
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
'  const raw = input == null ? "" : String(input);',
'  let out = raw.replaceAll("\r", " ").replaceAll("\n", " ").replaceAll("\t", " ");',
'  while (out.indexOf("  ") !== -1) out = out.replaceAll("  ", " ");',
'  return out.trim();',
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
'    document.execCommand("copy");',
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
'  const tRef = useRef<number | null>(null);',
'  const rootId = props.rootId;',
'  const listSelector = props.listSelector;',
'',
'  const groups = useMemo(() => {',
'    const by: Record<string, LinkItem[]> = {};',
'    for (const it of snap.items) {',
'      const key = it.domain || "outros";',
'      if (!by[key]) by[key] = [];',
'      by[key].push(it);',
'    }',
'    const keys = Object.keys(by).sort((a, b) => a.localeCompare(b));',
'    return keys.map((k) => ({ domain: k, items: by[k] }));',
'  }, [snap.items]);',
'',
'  const domainKeys = useMemo(() => groups.map((g) => g.domain), [groups]);',
'',
'  useEffect(() => {',
'    const scanNow = () => {',
'      try {',
'        const rootEl = document.getElementById(rootId);',
'        if (!rootEl) {',
'          store.set({ items: [], lastScan: Date.now(), error: "root_not_found" });',
'          return;',
'        }',
'        const scopeEl = listSelector ? rootEl.querySelector(listSelector) : null;',
'        const base: Element = scopeEl || rootEl;',
'        const anchors = Array.from(base.querySelectorAll("a[href]")) as HTMLAnchorElement[];',
'        const items: LinkItem[] = [];',
'        for (const a of anchors) {',
'          if (a.closest("[data-cv2-filter-ui]")) continue;',
'          if (a.closest("[data-cv2-provas-tools]")) continue;',
'          if (a.closest("nav")) continue;',
'          const href = a.getAttribute("href") || "";',
'          if (!href) continue;',
'          const text = normalizeText(a.textContent);',
'          const dom = normalizeText(a.getAttribute("data-domain"));',
'          const domain = dom.length ? dom : safeHost(href);',
'          try {',
'            const cs = window.getComputedStyle(a);',
'            if (cs.display === "none" || cs.visibility === "hidden") continue;',
'          } catch {',
'            // ignore',
'          }',
'          items.push({ href, text: text.length ? text : href, domain });',
'        }',
'        store.set({ items, lastScan: Date.now(), error: null });',
'      } catch {',
'        store.set({ items: [], lastScan: Date.now(), error: "scan_failed" });',
'      }',
'    };',
'',
'    const schedule = () => {',
'      if (tRef.current != null) { window.clearTimeout(tRef.current); tRef.current = null; }',
'      tRef.current = window.setTimeout(() => {',
'        tRef.current = null;',
'        scanNow();',
'      }, 60);',
'    };',
'',
'    schedule();',
'',
'    const rootEl = document.getElementById(rootId);',
'    if (!rootEl) return;',
'',
'    const onAny = () => schedule();',
'    rootEl.addEventListener("input", onAny, true);',
'    rootEl.addEventListener("change", onAny, true);',
'    rootEl.addEventListener("click", onAny, true);',
'',
'    return () => {',
'      rootEl.removeEventListener("input", onAny, true);',
'      rootEl.removeEventListener("change", onAny, true);',
'      rootEl.removeEventListener("click", onAny, true);',
'      if (tRef.current != null) { window.clearTimeout(tRef.current); tRef.current = null; }',
'    };',
'  }, [rootId, listSelector]);',
'',
'  if (snap.items.length === 0) return null;',
'',
'  const title = props.title || "Por domínio";',
'',
'  return (',
'    <div data-cv2-provas-tools className="cv2-card" style={{ marginTop: 12 }}>',
'      <div className="cv2-row" style={{ gap: 10, flexWrap: "wrap", alignItems: "center" }}>',
'        <div style={{ fontWeight: 700 }}>{title}</div>',
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
'                const safeText = it.text.split("]").join("\\\\]");',
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
'          const isOpen = snap.open[g.domain] !== false;',
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
'',
'      {snap.error ? <div className="cv2-muted" style={{ marginTop: 10, fontSize: 12 }}>scan: {snap.error}</div> : null}',
'    </div>',
'  );',
'}'
)

WriteUtf8NoBom $comp ($lines -join "`n")
Write-Host ("[PATCH] wrote -> " + $compRel)
if ($bkComp) { Write-Host ("[BK] " + $bkComp) }

# -----------------------
# PATCH 2) Ensure page uses component (no unused import)
# -----------------------
$pageRaw = Get-Content -Raw -LiteralPath $page
if ([string]::IsNullOrWhiteSpace($pageRaw)) { throw "[STOP] page.tsx vazio" }
$bkPage = BackupFile $page

$importLine = 'import { Cv2ProvasGroupedClient } from "@/components/v2/Cv2ProvasGroupedClient";'
$pagePatched = InsertImportAfterLastImport $pageRaw $importLine

# garante uso/ajusta listSelector para SEM aspas internas
if ($pagePatched -notmatch "<Cv2ProvasGroupedClient") {
  $insert = '<Cv2ProvasGroupedClient rootId="cv2-provas-root" listSelector="[data-cv2-provas-list]" />'
  $pagePatched = InsertLineAfterFirstContains $pagePatched "Cv2DomFilterClient" $insert
} else {
  # normaliza listSelector se veio quebrado
  $pagePatched = $pagePatched -replace 'listSelector\s*=\s*"[^"]*data-cv2-provas-list[^"]*"', 'listSelector="[data-cv2-provas-list]"'
}

# garante wrapper do list para o selector existir
if ($pagePatched -notmatch "data-cv2-provas-list") {
  $lines2 = $pagePatched -split "`r?`n"
  $idx = -1
  for ($i=0; $i -lt $lines2.Length; $i++) {
    if ($lines2[$i].Contains("<ProvasV2")) { $idx = $i; break }
  }
  if ($idx -ge 0) {
    $indent = ""
    $m2 = [regex]::Match($lines2[$idx], "^(\s+)")
    if ($m2.Success) { $indent = $m2.Groups[1].Value }
    $open = $indent + '<div data-cv2-provas-list>'
    $close = $indent + '</div>'
    $out2 = @()
    if ($idx -gt 0) { $out2 += $lines2[0..($idx-1)] }
    $out2 += $open
    $out2 += $lines2[$idx]
    $out2 += $close
    if ($idx + 1 -le $lines2.Length - 1) { $out2 += $lines2[($idx+1)..($lines2.Length-1)] }
    $pagePatched = ($out2 -join "`n")
  }
}

if ($pagePatched -ne $pageRaw) {
  WriteUtf8NoBom $page $pagePatched
  Write-Host ("[PATCH] wrote -> " + $pageRel)
  Write-Host ("[BK] " + $bkPage)
} else {
  Write-Host "[PATCH] page.tsx: no changes needed"
}

# -----------------------
# REPORT + VERIFY
# -----------------------
$rep = @()
$rep += "# CV — B6e1: Fix parser do agrupador + uso no page (sem unused)"
$rep += ""
$rep += ("- when: " + $stamp)
$rep += ("- component: " + $compRel)
$rep += ("- page: " + $pageRel)
$rep += ""
$rep += "## O que muda"
$rep += "- Reescreve Cv2ProvasGroupedClient.tsx em formato parser-safe (sem seletor com aspas internas)."
$rep += "- Page passa a usar o componente e normaliza listSelector para `[data-cv2-provas-list]`."
$rep += ""
$rep += "## VERIFY"
$rep += "- tools/cv-verify.ps1"

$reportPath = NewReport $step ($rep -join "`n")
Write-Host ("[REPORT] " + $reportPath)

$verify = Join-Path $root "tools\cv-verify.ps1"
if (Test-Path -LiteralPath $verify) {
  Write-Host ("[RUN] tools\cv-verify.ps1")
  & $verify
} else {
  Write-Host "[WARN] tools\cv-verify.ps1 não encontrado — pulei verify"
}

Write-Host "[OK] B6e1 aplicado."
if ($OpenReport) { try { Invoke-Item $reportPath } catch { } }