param([switch]$OpenReport)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# --- bootstrap
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$bootstrap = Join-Path $PSScriptRoot "_bootstrap.ps1"
if (Test-Path -LiteralPath $bootstrap) { . $bootstrap }

function EnsureDirSafe([string]$p) {
  if (Get-Command EnsureDir -ErrorAction SilentlyContinue) { EnsureDir $p; return }
  if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}
function WriteUtf8NoBomSafe([string]$p, [string]$content) {
  if (Get-Command WriteUtf8NoBom -ErrorAction SilentlyContinue) { WriteUtf8NoBom $p $content; return }
  [IO.File]::WriteAllText($p, $content, [Text.UTF8Encoding]::new($false))
}
function BackupFileSafe([string]$p) {
  if (Get-Command BackupFile -ErrorAction SilentlyContinue) { return (BackupFile $p) }
  $bkDir = Join-Path $root "tools\_patch_backup"
  EnsureDirSafe $bkDir
  $stamp = (Get-Date -Format "yyyyMMdd-HHmmss")
  $bk = Join-Path $bkDir ($stamp + "-" + (Split-Path -Leaf $p) + ".bak")
  Copy-Item -LiteralPath $p -Destination $bk -Force
  return $bk
}

$stamp = (Get-Date -Format "yyyyMMdd-HHmmss")
$step  = "cv-step-b6c1-fix-domfilter-lint-store-v0_1"

Write-Host ("== " + $step + " == " + $stamp) -ForegroundColor Cyan
Write-Host ("[DIAG] Root: " + $root)

EnsureDirSafe (Join-Path $root "reports")
EnsureDirSafe (Join-Path $root "tools\_patch_backup")

$compRel = "src\components\v2\Cv2DomFilterClient.tsx"
$comp = Join-Path $root $compRel
if (-not (Test-Path -LiteralPath $comp)) { throw ("[STOP] nao achei: " + $compRel) }

$bk = BackupFileSafe $comp

$ts = @(
'"use client";',
'',
'import { useEffect, useMemo, useState, useSyncExternalStore } from "react";',
'',
'type Stats = { total: number; shown: number };',
'type Unsub = () => void;',
'type Listener = () => void;',
'type StatsBus = {',
'  getSnapshot: () => Stats;',
'  subscribe: (l: Listener) => Unsub;',
'  publish: (s: Stats) => void;',
'};',
'',
'function createStatsBus(initial: Stats): StatsBus {',
'  let snap = initial;',
'  const listeners = new Set<Listener>();',
'  return {',
'    getSnapshot: () => snap,',
'    subscribe: (l) => {',
'      listeners.add(l);',
'      return () => { listeners.delete(l); };',
'    },',
'    publish: (s) => {',
'      snap = s;',
'      for (const l of listeners) l();',
'    },',
'  };',
'}',
'',
'function foldText(input: unknown): string {',
'  const raw = input == null ? "" : String(input);',
'  const lower = raw.toLowerCase();',
'  try {',
'    return lower.normalize("NFD").replace(/[\\u0300-\\u036f]/g, "");',
'  } catch {',
'    return lower;',
'  }',
'}',
'',
'async function copyToClipboard(text: string): Promise<boolean> {',
'  try {',
'    if (navigator.clipboard && typeof navigator.clipboard.writeText === "function") {',
'      await navigator.clipboard.writeText(text);',
'      return true;',
'    }',
'  } catch {',
'    // ignore',
'  }',
'  try {',
'    const ta = document.createElement("textarea");',
'    ta.value = text;',
'    ta.setAttribute("readonly", "");',
'    ta.style.position = "fixed";',
'    ta.style.left = "-9999px";',
'    ta.style.top = "0";',
'    document.body.appendChild(ta);',
'    ta.select();',
'    const ok = document.execCommand("copy");',
'    document.body.removeChild(ta);',
'    return ok;',
'  } catch {',
'    return false;',
'  }',
'}',
'',
'function uniqByRef<T extends object>(arr: T[]): T[] {',
'  const seen = new Set<T>();',
'  const out: T[] = [];',
'  for (const x of arr) {',
'    if (!seen.has(x)) {',
'      seen.add(x);',
'      out.push(x);',
'    }',
'  }',
'  return out;',
'}',
'',
'function findItemRoot(a: HTMLAnchorElement, scope: HTMLElement): HTMLElement {',
'  const li = a.closest("li");',
'  if (li && scope.contains(li)) return li as HTMLElement;',
'  const art = a.closest("article");',
'  if (art && scope.contains(art)) return art as HTMLElement;',
'  const sec = a.closest("section");',
'  if (sec && scope.contains(sec)) return sec as HTMLElement;',
'  const div = a.closest("div");',
'  if (div && scope.contains(div)) return div as HTMLElement;',
'  return a;',
'}',
'',
'function getScope(rootId: string): HTMLElement | null {',
'  const el = document.getElementById(rootId);',
'  return el ? (el as HTMLElement) : null;',
'}',
'',
'export function Cv2DomFilterClient(props: {',
'  rootId: string;',
'  label?: string;',
'  placeholder?: string;',
'}) {',
'  const [q, setQ] = useState<string>("");',
'  const [toast, setToast] = useState<string>("");',
'',
'  const bus = useMemo(() => createStatsBus({ total: 0, shown: 0 }), []);',
'  const stats = useSyncExternalStore(bus.subscribe, bus.getSnapshot, bus.getSnapshot);',
'',
'  const label = props.label || "Filtrar provas";',
'  const placeholder = props.placeholder || "Digite para filtrar…";',
'  const qFold = useMemo(() => foldText(q).trim(), [q]);',
'',
'  useEffect(() => {',
'    const scope = getScope(props.rootId);',
'    if (!scope) {',
'      bus.publish({ total: 0, shown: 0 });',
'      return;',
'    }',
'',
'    const skip = "[data-cv2-filter-ui=1]";',
'',
'    const anchors = Array.from(scope.querySelectorAll<HTMLAnchorElement>("a[href]"));',
'    const roots = anchors.map((a) => findItemRoot(a, scope));',
'    const items = uniqByRef(roots).filter((el) => !el.closest(skip));',
'',
'    let shown = 0;',
'    for (const el of items) {',
'      const hay = foldText(el.textContent || "");',
'      const ok = qFold.length === 0 ? true : hay.includes(qFold);',
'      if (ok) el.removeAttribute("hidden");',
'      if (!ok) el.setAttribute("hidden", "");',
'      if (ok) shown += 1;',
'    }',
'',
'    bus.publish({ total: items.length, shown });',
'  }, [props.rootId, qFold, bus]);',
'',
'  function collectVisibleLinks(): Array<{ href: string; text: string }> {',
'    const scope = getScope(props.rootId);',
'    if (!scope) return [];',
'    const links: Array<{ href: string; text: string }> = [];',
'    const seen = new Set<string>();',
'    const skip = "[data-cv2-filter-ui=1]";',
'    const anchors = Array.from(scope.querySelectorAll<HTMLAnchorElement>("a[href]"));',
'    for (const a of anchors) {',
'      if (a.closest(skip)) continue;',
'      const item = findItemRoot(a, scope);',
'      if (item.hasAttribute("hidden")) continue;',
'      const href = a.getAttribute("href") || "";',
'      if (!href || href.startsWith("#")) continue;',
'      if (seen.has(href)) continue;',
'      seen.add(href);',
'      const text = (a.textContent || "").replace(/\\s+/g, " ").trim();',
'      links.push({ href, text });',
'    }',
'    return links;',
'  }',
'',
'  async function doCopy(kind: "plain" | "md") {',
'    const links = collectVisibleLinks();',
'    const text = kind === "plain"',
'      ? links.map((l) => l.href).join("\\n")',
'      : links.map((l) => "- [" + (l.text || l.href) + "](" + l.href + ")").join("\\n");',
'    const ok = await copyToClipboard(text);',
'    setToast(ok ? "Copiado!" : "Falhou ao copiar");',
'    window.setTimeout(() => setToast(""), 1200);',
'  }',
'',
'  return (',
'    <div className="cv2-domfilter" data-cv2-filter-ui="1">', 
'      <div className="cv2-domfilter__row">', 
'        <label className="cv2-domfilter__label">', 
'          <span className="cv2-domfilter__labelText">{label}</span>', 
'          <input', 
'            className="cv2-domfilter__input"', 
'            value={q}', 
'            onChange={(e) => setQ(e.target.value)}', 
'            placeholder={placeholder}', 
'            aria-label={label}', 
'          />', 
'        </label>', 
'        <button type="button" className="cv2-domfilter__btn" onClick={() => setQ("")} disabled={q.length === 0}>', 
'          Limpar', 
'        </button>', 
'        <button type="button" className="cv2-domfilter__btn" onClick={() => void doCopy("plain")}>', 
'          Copiar links', 
'        </button>', 
'        <button type="button" className="cv2-domfilter__btn" onClick={() => void doCopy("md")}>', 
'          Copiar MD', 
'        </button>', 
'      </div>', 
'      <div className="cv2-domfilter__meta" aria-live="polite">', 
'        <span className="cv2-domfilter__count">{stats.shown}/{stats.total}</span>', 
'        {toast ? <span className="cv2-domfilter__toast">{toast}</span> : null}', 
'      </div>', 
'    </div>',
'  );',
'}'
)

WriteUtf8NoBomSafe $comp ($ts -join "`n")
Write-Host ("[PATCH] wrote -> " + $compRel)
Write-Host ("[BK] tools/_patch_backup/" + (Split-Path -Leaf $bk))

# --- REPORT
$reportPath = Join-Path $root ("reports\" + $step + "-" + $stamp + ".md")
$rep = @()
$rep += "# CV — Step B6c1: Fix domfilter lint (external store)"
$rep += ""
$rep += "- when: " + $stamp
$rep += "- file: " + $compRel
$rep += "- backup: tools/_patch_backup/" + (Split-Path -Leaf $bk)
$rep += ""
$rep += "## ACTIONS"
$rep += "- Removed setState inside useEffect by using useSyncExternalStore + bus.publish()."
$rep += "- Removed unused eslint-disable directives."
$rep += ""
$rep += "## VERIFY"
$rep += "- tools/cv-verify.ps1"
WriteUtf8NoBomSafe $reportPath ($rep -join "`n")
Write-Host ("[REPORT] reports/" + (Split-Path -Leaf $reportPath))

# --- VERIFY
$verify = Join-Path $root "tools\cv-verify.ps1"
if (Test-Path -LiteralPath $verify) {
  Write-Host "[RUN] tools/cv-verify.ps1"
  & pwsh -NoProfile -ExecutionPolicy Bypass -File $verify
} else {
  Write-Host "[RUN] npm run lint"
  & npm run lint
  Write-Host "[RUN] npm run build"
  & npm run build
}

Write-Host "[OK] B6c1 aplicado." -ForegroundColor Green
if ($OpenReport) { try { Invoke-Item $reportPath } catch {} }