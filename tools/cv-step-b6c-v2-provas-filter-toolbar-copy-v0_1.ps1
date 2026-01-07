param([switch]$OpenReport)

$ErrorActionPreference = "Stop"

# --- bootstrap
$tools = $PSScriptRoot
$root = Resolve-Path (Join-Path $tools "..")
. (Join-Path $tools "_bootstrap.ps1")

$stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
Write-Host ("== cv-step-b6c-v2-provas-filter-toolbar-copy-v0_1 == " + $stamp)
Write-Host ("[DIAG] Root: " + $root)

# --- targets
$targetCompRel = "src\components\v2\Cv2DomFilterClient.tsx"
$targetCssRel  = "src\app\globals.css"

$targetComp = Join-Path $root $targetCompRel
$targetCss  = Join-Path $root $targetCssRel

if (!(Test-Path $targetComp)) { throw ("[STOP] target nao encontrado: " + $targetCompRel) }
if (!(Test-Path $targetCss))  { throw ("[STOP] target nao encontrado: " + $targetCssRel) }

# --- PATCH: component (rewrite stable)
BackupFile $targetComp | Out-Null

$lines = @(
'"use client";',
'',
'import { useEffect, useMemo, useRef, useState } from "react";',
'import type { ReactNode } from "react";',
'',
'type Stats = { total: number; shown: number };',
'',
'function foldText(input: unknown): string {',
'  const raw = input == null ? "" : String(input);',
'  const lower = raw.toLowerCase();',
'  try {',
'    // remove acentos de forma segura (sem regex unicode fancy)',
'    return lower.normalize("NFD").replace(/[\u0300-\u036f]/g, "");',
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
'function findScope(root: HTMLDivElement | null): HTMLElement | null {',
'  if (!root) return null;',
'  const parent = root.parentElement;',
'  if (!parent) return null;',
'  // 1) se tiver um escopo marcado, usa',
'  const marked = parent.querySelector<HTMLElement>("[data-cv2-filter-scope]");',
'  if (marked) return marked;',
'  // 2) senão tenta o próximo irmão (caso o filtro esteja “solto” acima da lista)',
'  const next = root.nextElementSibling as HTMLElement | null;',
'  if (next) return next;',
'  // 3) fallback: o pai (último recurso)',
'  return parent;',
'}',
'',
'function collectLinks(scope: HTMLElement | null): Array<{ href: string; text: string }> {',
'  if (!scope) return [];',
'  const anchors = Array.from(scope.querySelectorAll<HTMLAnchorElement>("a[href]"));',
'  const seen = new Set<string>();',
'  const out: Array<{ href: string; text: string }> = [];',
'  for (const a of anchors) {',
'    const href = a.getAttribute("href") || "";',
'    if (!href) continue;',
'    if (href.startsWith("#")) continue;',
'    if (seen.has(href)) continue;',
'    seen.add(href);',
'    const text = (a.textContent || "").trim();',
'    out.push({ href, text });',
'  }',
'  return out;',
'}',
'',
'function findItemRoot(anchor: HTMLAnchorElement, scope: HTMLElement): HTMLElement {',
'  const li = anchor.closest("li");',
'  if (li && scope.contains(li)) return li as HTMLElement;',
'  const art = anchor.closest("article");',
'  if (art && scope.contains(art)) return art as HTMLElement;',
'  const sec = anchor.closest("section");',
'  if (sec && scope.contains(sec)) return sec as HTMLElement;',
'  const div = anchor.closest("div");',
'  if (div && scope.contains(div)) return div as HTMLElement;',
'  return anchor;',
'}',
'',
'export default function Cv2DomFilterClient(props: {',
'  children?: ReactNode;',
'  label?: string;',
'  placeholder?: string;',
'}) {',
'  const rootRef = useRef<HTMLDivElement | null>(null);',
'  const contentRef = useRef<HTMLDivElement | null>(null);',
'  const [q, setQ] = useState<string>("");',
'  const [stats, setStats] = useState<Stats>({ total: 0, shown: 0 });',
'  const [toast, setToast] = useState<string>("");',
'',
'  const label = props.label || "Filtrar provas";',
'  const placeholder = props.placeholder || "Digite para filtrar…";',
'',
'  const qFold = useMemo(() => foldText(q).trim(), [q]);',
'',
'  useEffect(() => {',
'    const scope = contentRef.current || findScope(rootRef.current);',
'    if (!scope) return;',
'',
'    const anchors = Array.from(scope.querySelectorAll<HTMLAnchorElement>("a[href]"));',
'    const roots: HTMLElement[] = [];',
'    for (const a of anchors) {',
'      roots.push(findItemRoot(a, scope));',
'    }',
'',
'    // unique roots (por referência)',
'    const uniq: HTMLElement[] = [];',
'    const seen = new Set<HTMLElement>();',
'    for (const r of roots) {',
'      if (!seen.has(r)) {',
'        seen.add(r);',
'        uniq.push(r);',
'      }',
'    }',
'',
'    let shown = 0;',
'    for (const el of uniq) {',
'      const hay = foldText(el.textContent || "");',
'      const ok = qFold.length === 0 ? true : hay.includes(qFold);',
'      if (ok) {',
'        el.removeAttribute("hidden");',
'        shown += 1;',
'      } else {',
'        el.setAttribute("hidden", "");',
'      }',
'    }',
'    setStats({ total: uniq.length, shown });',
'  }, [qFold]);',
'',
'  async function doCopy(kind: "plain" | "md") {',
'    const scope = contentRef.current || findScope(rootRef.current);',
'    const links = collectLinks(scope);',
'    let text = "";',
'',
'    if (kind === "plain") {',
'      text = links.map((l) => l.href).join("\\n");',
'    } else {',
'      text = links',
'        .map((l) => {',
'          const t0 = l.text ? l.text : l.href;',
'          const t = t0.replace(/\\s+/g, " ").trim();',
'          return "- [" + t + "](" + l.href + ")";',
'        })',
'        .join("\\n");',
'    }',
'',
'    const ok = await copyToClipboard(text);',
'    setToast(ok ? "Copiado!" : "Falhou ao copiar");',
'    window.setTimeout(() => setToast(""), 1200);',
'  }',
'',
'  return (',
'    <div ref={rootRef} className="cv2-domfilter" data-cv2-filter-ui="1">', 
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
'        <button', 
'          type="button"', 
'          className="cv2-domfilter__btn"', 
'          onClick={() => setQ("")}', 
'          disabled={q.length === 0}', 
'        >', 
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
'      {props.children ? (', 
'        <div ref={contentRef} data-cv2-filter-scope>', 
'          {props.children}', 
'        </div>', 
'      ) : null}', 
'    </div>', 
'  );',
'}'
)

WriteUtf8NoBom $targetComp ($lines -join "`n")
Write-Host ("[PATCH] wrote -> " + (RelPath $root $targetComp))
Write-Host ("[BK] " + (RelPath $root (LastBackupPath)))

# --- PATCH: css (append only if missing)
$cssRaw = Get-Content -Raw -LiteralPath $targetCss
if ($cssRaw -notmatch "cv2-domfilter") {
  BackupFile $targetCss | Out-Null

  $cssAdd = @()
  $cssAdd += ""
  $cssAdd += "/* CV2 — dom filter toolbar */"
  $cssAdd += ".cv-v2 .cv2-domfilter{"
  $cssAdd += "  margin: 12px 0 16px;"
  $cssAdd += "  padding: 12px;"
  $cssAdd += "  border: 1px solid rgba(255,255,255,.08);"
  $cssAdd += "  background: var(--card);"
  $cssAdd += "  border-radius: 12px;"
  $cssAdd += "}"
  $cssAdd += ".cv-v2 .cv2-domfilter__row{"
  $cssAdd += "  display: flex;"
  $cssAdd += "  gap: 10px;"
  $cssAdd += "  align-items: end;"
  $cssAdd += "  flex-wrap: wrap;"
  $cssAdd += "}"
  $cssAdd += ".cv-v2 .cv2-domfilter__label{"
  $cssAdd += "  display: flex;"
  $cssAdd += "  flex-direction: column;"
  $cssAdd += "  gap: 6px;"
  $cssAdd += "  min-width: 240px;"
  $cssAdd += "  flex: 1 1 280px;"
  $cssAdd += "}"
  $cssAdd += ".cv-v2 .cv2-domfilter__labelText{"
  $cssAdd += "  font-size: 12px;"
  $cssAdd += "  opacity: .8;"
  $cssAdd += "}"
  $cssAdd += ".cv-v2 .cv2-domfilter__input{"
  $cssAdd += "  width: 100%;"
  $cssAdd += "  padding: 10px 12px;"
  $cssAdd += "  border-radius: 10px;"
  $cssAdd += "  border: 1px solid rgba(255,255,255,.10);"
  $cssAdd += "  background: rgba(0,0,0,.25);"
  $cssAdd += "  color: var(--fg);"
  $cssAdd += "  outline: none;"
  $cssAdd += "}"
  $cssAdd += ".cv-v2 .cv2-domfilter__btn{"
  $cssAdd += "  padding: 10px 12px;"
  $cssAdd += "  border-radius: 10px;"
  $cssAdd += "  border: 1px solid rgba(255,255,255,.10);"
  $cssAdd += "  background: rgba(255,255,255,.06);"
  $cssAdd += "  color: var(--fg);"
  $cssAdd += "  cursor: pointer;"
  $cssAdd += "}"
  $cssAdd += ".cv-v2 .cv2-domfilter__btn:disabled{"
  $cssAdd += "  opacity: .5;"
  $cssAdd += "  cursor: default;"
  $cssAdd += "}"
  $cssAdd += ".cv-v2 .cv2-domfilter__meta{"
  $cssAdd += "  margin-top: 8px;"
  $cssAdd += "  display: flex;"
  $cssAdd += "  gap: 10px;"
  $cssAdd += "  align-items: center;"
  $cssAdd += "  font-size: 12px;"
  $cssAdd += "  opacity: .85;"
  $cssAdd += "}"
  $cssAdd += ".cv-v2 .cv2-domfilter__toast{"
  $cssAdd += "  opacity: .9;"
  $cssAdd += "}"
  $cssAdd += ""

  WriteUtf8NoBom $targetCss ($cssRaw + ($cssAdd -join "`n"))
  Write-Host ("[PATCH] css -> " + (RelPath $root $targetCss))
  Write-Host ("[BK] " + (RelPath $root (LastBackupPath)))
} else {
  Write-Host "[OK] globals.css já tem cv2-domfilter — pulei patch CSS"
}

# --- REPORT
$rep = @()
$rep += "# CV — Step B6c: Provas V2 — DOM filter toolbar + copy"
$rep += ""
$rep += "- when: $stamp"
$rep += "- repo: $(RelPath $root $root)"
$rep += ""
$rep += "## ACTIONS"
$rep += "- Rewrote Cv2DomFilterClient.tsx (typed, stable; works wrapped or standalone)."
$rep += "- Added toolbar actions: Limpar / Copiar links / Copiar MD."
$rep += "- Optional CSS: appended cv2-domfilter styles in globals.css (only if missing)."
$rep += ""
$rep += "## BACKUPS"
$rep += "- " + (RelPath $root (FindNewestBackup "Cv2DomFilterClient.tsx"))
$rep += "- (css) only if patched"
$rep += ""
$rep += "## VERIFY"
$rep += "- rodar tools/cv-verify.ps1 (guard + lint + build)."

$reportPath = NewReport "cv-step-b6c-v2-provas-filter-toolbar-copy-v0_1" ($rep -join "`n")
Write-Host ("[REPORT] " + (RelPath $root $reportPath))

# --- VERIFY
$verify = Join-Path $root "tools\cv-verify.ps1"
if (Test-Path $verify) {
  Write-Host ("[RUN] " + (RelPath $root $verify))
  & $verify
} else {
  Write-Host "[WARN] tools/cv-verify.ps1 não encontrado — fallback lint+build"
  Exec "npm run lint"
  Exec "npm run build"
}

Write-Host "[OK] B6c aplicado."

if ($OpenReport) {
  try { Invoke-Item $reportPath } catch { }
}