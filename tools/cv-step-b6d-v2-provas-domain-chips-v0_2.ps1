param([switch]$OpenReport)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# --- Root do repo (tools/..)
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path

# --- bootstrap (se existir)
$boot = Join-Path $PSScriptRoot "_bootstrap.ps1"
if (Test-Path -LiteralPath $boot) { . $boot }

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
$step  = "cv-step-b6d-v2-provas-domain-chips-v0_2"

Write-Host ("== " + $step + " == " + $stamp) -ForegroundColor Cyan
Write-Host ("[DIAG] Root: " + $root)

EnsureDirSafe (Join-Path $root "reports")
EnsureDirSafe (Join-Path $root "tools\_patch_backup")

# -----------------------
# PATCH: componente (reescreve inteiro, idempotente e lint-safe)
# -----------------------
$compRel = "src\components\v2\Cv2DomFilterClient.tsx"
$comp = Join-Path $root $compRel
if (-not (Test-Path -LiteralPath $comp)) { throw ("[STOP] nao achei: " + $compRel) }

$bkComp = BackupFileSafe $comp

$ts = @(
'"use client";',
'',
'import { useEffect, useMemo, useState, useSyncExternalStore } from "react";',
'',
'type DomainRow = { domain: string; total: number; shown: number };',
'type Snapshot = { total: number; shown: number; domains: DomainRow[] };',
'',
'type Listener = () => void;',
'type Unsub = () => void;',
'',
'function createStore(initial: Snapshot) {',
'  let snap: Snapshot = initial;',
'  const listeners = new Set<Listener>();',
'  return {',
'    getSnapshot: () => snap,',
'    subscribe: (l: Listener): Unsub => {',
'      listeners.add(l);',
'      return () => { listeners.delete(l); };',
'    },',
'    publish: (next: Snapshot) => {',
'      snap = next;',
'      for (const l of listeners) l();',
'    },',
'  };',
'}',
'',
'const store = createStore({ total: 0, shown: 0, domains: [] });',
'',
'function foldText(input: unknown): string {',
'  const raw = input == null ? "" : String(input);',
'  const lower = raw.toLowerCase();',
'  try {',
'    return lower.normalize("NFD").replace(/[\u0300-\u036f]/g, "");',
'  } catch {',
'    return lower;',
'  }',
'}',
'',
'function safeHost(href: string): string {',
'  try {',
'    const base = typeof window !== "undefined" ? window.location.href : "http://localhost";',
'    const u = new URL(href, base);',
'    return u.hostname || "";',
'  } catch {',
'    return "";',
'  }',
'}',
'',
'function depthOf(el: Element): number {',
'  let d = 0;',
'  let cur: Element | null = el;',
'  while (cur) { d += 1; cur = cur.parentElement; }',
'  return d;',
'}',
'',
'function uniqOuterMost(list: Element[]): Element[] {',
'  const byDepth = list.slice().sort((a, b) => depthOf(a) - depthOf(b));',
'  const out: Element[] = [];',
'  for (const el of byDepth) {',
'    if (out.some((p) => p.contains(el))) continue;',
'    out.push(el);',
'  }',
'  return out;',
'}',
'',
'function pickItems(root: HTMLElement, skipSelector: string, forcedSelector?: string): Element[] {',
'  const candidates = forcedSelector',
'    ? [forcedSelector]',
'    : [',
'        "[data-cv2-item=1]",',
'        "[data-cv2-proof=1]",',
'        "[data-cv2-prova=1]",',
'        "article",',
'        "li",',
'        ".cv2-card",',
'      ];',
'',
'  for (const sel of candidates) {',
'    const raw = Array.from(root.querySelectorAll(sel));',
'    const filtered = raw',
'      .filter((el) => !el.closest(skipSelector))',
'      .filter((el) => !!el.querySelector("a[href]"));',
'    if (filtered.length > 0) return uniqOuterMost(filtered);',
'  }',
'  return [];',
'}',
'',
'async function copyText(text: string): Promise<boolean> {',
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
'    ta.setAttribute("readonly", "true");',
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
'export type Cv2DomFilterClientProps = {',
'  rootId: string;',
'  itemSelector?: string;',
'  skipSelector?: string;',
'  placeholder?: string;',
'  copyLabel?: string;',
'  chipsLabel?: string;',
'};',
'',
'export default function Cv2DomFilterClient(props: Cv2DomFilterClientProps) {',
'  const [q, setQ] = useState<string>("");',
'  const [domain, setDomain] = useState<string>("");',
'  const [toast, setToast] = useState<string>("");',
'',
'  const snap = useSyncExternalStore(store.subscribe, store.getSnapshot, store.getSnapshot);',
'  const qFold = useMemo(() => foldText(q).trim(), [q]);',
'  const activeDomain = useMemo(() => domain.trim(), [domain]);',
'',
'  const skipSelector = props.skipSelector || "[data-cv2-filter-ui=1]";',
'',
'  useEffect(() => {',
'    const root = document.getElementById(props.rootId) as HTMLElement | null;',
'    if (!root) { store.publish({ total: 0, shown: 0, domains: [] }); return; }',
'',
'    const items = pickItems(root, skipSelector, props.itemSelector);',
'    const domainTotals = new Map<string, { total: number; shown: number }>();',
'    let shown = 0;',
'',
'    for (const el of items) {',
'      const text = foldText(el.textContent || "");',
'      const okText = qFold.length === 0 ? true : text.includes(qFold);',
'',
'      const a = el.querySelector("a[href]") as HTMLAnchorElement | null;',
'      const href = a ? (a.href || a.getAttribute("href") || "") : "";',
'      const host = href ? safeHost(href) : "";',
'',
'      if (!domainTotals.has(host)) domainTotals.set(host, { total: 0, shown: 0 });',
'      domainTotals.get(host)!.total += 1;',
'',
'      const okDomain = activeDomain.length === 0 ? true : host === activeDomain;',
'      const ok = okText && okDomain;',
'',
'      if (ok) { el.removeAttribute("hidden"); shown += 1; domainTotals.get(host)!.shown += 1; }',
'      if (!ok) { el.setAttribute("hidden", ""); }',
'    }',
'',
'    const domains: DomainRow[] = Array.from(domainTotals.entries())',
'      .map(([d, c]) => ({ domain: d, total: c.total, shown: c.shown }))',
'      .filter((r) => r.domain && r.total > 0)',
'      .sort((a, b) => (b.total - a.total) || a.domain.localeCompare(b.domain));',
'',
'    store.publish({ total: items.length, shown, domains });',
'  }, [props.rootId, props.itemSelector, props.skipSelector, qFold, activeDomain]);',
'',
'  function collectVisibleLinks(): Array<{ href: string; text: string }> {',
'    const root = document.getElementById(props.rootId) as HTMLElement | null;',
'    if (!root) return [];',
'    const items = pickItems(root, skipSelector, props.itemSelector);',
'    const out: Array<{ href: string; text: string }> = [];',
'    const seen = new Set<string>();',
'    for (const el of items) {',
'      if (el.hasAttribute("hidden")) continue;',
'      const a = el.querySelector("a[href]") as HTMLAnchorElement | null;',
'      if (!a) continue;',
'      const href = a.href || a.getAttribute("href") || "";',
'      if (!href || href.startsWith("#")) continue;',
'      if (seen.has(href)) continue;',
'      seen.add(href);',
'      const text = (a.textContent || el.textContent || "").replace(/\s+/g, " ").trim().slice(0, 200);',
'      out.push({ href, text });',
'    }',
'    return out;',
'  }',
'',
'  async function onCopy(kind: "plain" | "md") {',
'    const links = collectVisibleLinks();',
'    const text = kind === "plain"',
'      ? links.map((l) => l.href).join("\n")',
'      : links.map((l) => "- [" + (l.text || l.href) + "](" + l.href + ")").join("\n");',
'    if (!text) return;',
'    const ok = await copyText(text);',
'    setToast(ok ? "Copiado!" : "Falhou ao copiar");',
'    window.setTimeout(() => setToast(""), 1200);',
'  }',
'',
'  return (',
'    <div className="cv2-filter" data-cv2-filter-ui="1">',
'      <div className="cv2-filter__row">',
'        <label className="cv2-filter__label" htmlFor={props.rootId + "__q"}>Filtrar</label>',
'        <input',
'          id={props.rootId + "__q"}',
'          className="cv2-filter__input"',
'          value={q}',
'          onChange={(e) => setQ(e.target.value)}',
'          placeholder={props.placeholder || "busca rápida..."}',
'        />',
'        <button type="button" className="cv2-filter__btn" onClick={() => setQ("")} disabled={q.length === 0}>Limpar</button>',
'        <button type="button" className="cv2-filter__btn" onClick={() => void onCopy("plain")}>{props.copyLabel || "Copiar links"}</button>',
'        <button type="button" className="cv2-filter__btn" onClick={() => void onCopy("md")}>Copiar MD</button>',
'        <div className="cv2-filter__stats" aria-live="polite">{snap.shown}/{snap.total}</div>',
'      </div>',
'',
'      {snap.domains.length > 0 ? (',
'        <div className="cv2-filter__chips" role="list" aria-label={props.chipsLabel || "Domínios"}>',
'          <button type="button" className={"cv2-chip" + (domain === "" ? " is-active" : "")} onClick={() => setDomain("")}>',
'            <span className="cv2-chip__text">Tudo</span>',
'            <span className="cv2-chip__count">{snap.shown}</span>',
'          </button>',
'          {snap.domains.slice(0, 14).map((d) => (',
'            <button',
'              key={d.domain}',
'              type="button"',
'              className={"cv2-chip" + (domain === d.domain ? " is-active" : "")}',
'              onClick={() => setDomain(d.domain)}',
'              title={d.shown + "/" + d.total}',
'            >',
'              <span className="cv2-chip__text">{d.domain}</span>',
'              <span className="cv2-chip__count">{d.shown}</span>',
'            </button>',
'          ))}',
'          {toast ? <span className="cv2-filter__toast">{toast}</span> : null}',
'        </div>',
'      ) : null}',
'    </div>',
'  );',
'}'
)

WriteUtf8NoBomSafe $comp ($ts -join "`n")
Write-Host ("[PATCH] wrote -> " + $compRel)
Write-Host ("[BK] tools/_patch_backup/" + (Split-Path -Leaf $bkComp))

# -----------------------
# PATCH: CSS (append idempotente)
# -----------------------
$cssRel = "src\app\globals.css"
$css = Join-Path $root $cssRel
if (Test-Path -LiteralPath $css) {
  $rawCss = Get-Content -Raw -LiteralPath $css
  $marker = "/* cv2-domain-chips */"
  if ($rawCss -notmatch [regex]::Escape($marker)) {
    $bkCss = BackupFileSafe $css
    $add = @(
      '',
      $marker,
      '.cv-v2 .cv2-filter {',
      '  margin: 0 0 12px;',
      '  padding: 10px 12px;',
      '  border: 1px solid rgba(255,255,255,0.10);',
      '  border-radius: 16px;',
      '  background: rgba(0,0,0,0.22);',
      '  backdrop-filter: blur(8px);',
      '}',
      '.cv-v2 .cv2-filter__row {',
      '  display: flex;',
      '  align-items: center;',
      '  gap: 10px;',
      '  flex-wrap: wrap;',
      '}',
      '.cv-v2 .cv2-filter__label {',
      '  font-size: 12px;',
      '  opacity: 0.80;',
      '  text-transform: uppercase;',
      '  letter-spacing: 0.08em;',
      '}',
      '.cv-v2 .cv2-filter__input {',
      '  flex: 1;',
      '  min-width: 180px;',
      '  padding: 10px 12px;',
      '  border-radius: 12px;',
      '  border: 1px solid rgba(255,255,255,0.12);',
      '  background: rgba(0,0,0,0.35);',
      '  color: inherit;',
      '}',
      '.cv-v2 .cv2-filter__btn {',
      '  padding: 10px 12px;',
      '  border-radius: 12px;',
      '  border: 1px solid rgba(255,255,255,0.12);',
      '  background: rgba(255,255,255,0.06);',
      '  color: inherit;',
      '  cursor: pointer;',
      '}',
      '.cv-v2 .cv2-filter__stats {',
      '  min-width: 72px;',
      '  text-align: right;',
      '  font-variant-numeric: tabular-nums;',
      '  opacity: 0.85;',
      '}',
      '.cv-v2 .cv2-filter__chips {',
      '  display: flex;',
      '  gap: 8px;',
      '  flex-wrap: wrap;',
      '  margin-top: 10px;',
      '  align-items: center;',
      '}',
      '.cv-v2 .cv2-chip {',
      '  display: inline-flex;',
      '  align-items: center;',
      '  gap: 8px;',
      '  padding: 8px 10px;',
      '  border-radius: 999px;',
      '  border: 1px solid rgba(255,255,255,0.12);',
      '  background: rgba(255,255,255,0.04);',
      '  color: inherit;',
      '  cursor: pointer;',
      '}',
      '.cv-v2 .cv2-chip.is-active {',
      '  background: rgba(255,255,255,0.10);',
      '  border-color: rgba(255,255,255,0.18);',
      '}',
      '.cv-v2 .cv2-chip__text {',
      '  max-width: 220px;',
      '  overflow: hidden;',
      '  text-overflow: ellipsis;',
      '  white-space: nowrap;',
      '}',
      '.cv-v2 .cv2-chip__count {',
      '  font-variant-numeric: tabular-nums;',
      '  padding: 2px 8px;',
      '  border-radius: 999px;',
      '  background: rgba(0,0,0,0.45);',
      '  border: 1px solid rgba(255,255,255,0.10);',
      '}',
      '.cv-v2 .cv2-filter__toast {',
      '  margin-left: 6px;',
      '  font-size: 12px;',
      '  opacity: 0.85;',
      '}'
    )
    WriteUtf8NoBomSafe $css ($rawCss.TrimEnd() + "`n" + ($add -join "`n") + "`n")
    Write-Host ("[PATCH] css -> " + $cssRel)
    Write-Host ("[BK] tools/_patch_backup/" + (Split-Path -Leaf $bkCss))
  } else {
    Write-Host ("[OK] css marker já existe -> " + $cssRel)
  }
} else {
  Write-Host "[WARN] globals.css não encontrado — pulei CSS"
}

# -----------------------
# REPORT (sem NewReport)
# -----------------------
$reportRel = ("reports\" + $step + "-" + $stamp + ".md")
$reportPath = Join-Path $root $reportRel

$rep = @()
$rep += "# CV — Step B6d: Domain chips + copy toolbar (Provas V2)"
$rep += ""
$rep += "- when: " + $stamp
$rep += "- component: " + $compRel
$rep += "- css: " + $cssRel
$rep += "- backup(comp): tools/_patch_backup/" + (Split-Path -Leaf $bkComp)
$rep += ""
$rep += "## O QUE MUDA"
$rep += "- Chips por domínio (hostname) com contagem (top 14)."
$rep += "- Busca rápida + stats + copiar links/MD."
$rep += "- Lint-safe: sem setState dentro do useEffect (store + useSyncExternalStore)."
$rep += ""
$rep += "## VERIFY"
$rep += "- tools/cv-verify.ps1"

WriteUtf8NoBomSafe $reportPath ($rep -join "`n")
Write-Host ("[REPORT] " + $reportRel)

# -----------------------
# VERIFY
# -----------------------
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

Write-Host "[OK] B6d aplicado." -ForegroundColor Green
if ($OpenReport) { try { Invoke-Item $reportPath } catch {} }