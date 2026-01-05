# CV — Hotfix V2 — Next params Promise + ReadingControls hydration stable + MapaDock props + V2Nav keys — v0_39
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

$toolsDir = if ($PSScriptRoot -and (Test-Path -LiteralPath $PSScriptRoot)) { $PSScriptRoot } else { Join-Path (Get-Location) "tools" }
$repo = (Resolve-Path (Join-Path $toolsDir "..")).Path
. (Join-Path $toolsDir "_bootstrap.ps1")

Write-Host ("[DIAG] Repo: " + $repo)

function PatchFile([string]$p, [scriptblock]$fn) {
  if (-not (Test-Path -LiteralPath $p)) { Write-Host ("[SKIP] missing: " + $p); return $false }
  $raw = Get-Content -LiteralPath $p -Raw
  if (-not $raw) { throw ("[STOP] arquivo vazio/ilegível: " + $p) }
  $next = & $fn $raw
  if ($null -eq $next) { Write-Host ("[SKIP] no-op: " + $p); return $false }
  if ($next -eq $raw) { Write-Host ("[OK] no change: " + $p); return $false }
  $bk = BackupFile $p
  WriteUtf8NoBom $p $next
  Write-Host ("[OK] patched: " + $p)
  if ($bk) { Write-Host ("[BK] " + $bk) }
  return $true
}

# ------------------------------------------------------------
# 1) ReadingControls — reescrever (hidratação estável sem setState em effect)
# ------------------------------------------------------------
$readingPath = Join-Path $repo "src\components\ReadingControls.tsx"
if (Test-Path -LiteralPath $readingPath) {
  $bk = BackupFile $readingPath

  $lines = @(
    '"use client";',
    '',
    'import React, { useEffect, useMemo, useRef, useSyncExternalStore, useState } from "react";',
    '',
    'type Prefs = { reading: boolean; scale: number };',
    'const KEY = "cv:prefs";',
    '',
    'const clamp = (n: number, a: number, b: number) => Math.max(a, Math.min(b, n));',
    '',
    'function parsePrefs(raw: string): Prefs {',
    '  const base: Prefs = { reading: false, scale: 1 };',
    '  if (!raw || typeof raw !== "string") return base;',
    '  try {',
    '    const obj = JSON.parse(raw) as unknown;',
    '    if (typeof obj !== "object" || obj === null) return base;',
    '    const r = obj as { reading?: unknown; scale?: unknown };',
    '    const reading = typeof r.reading === "boolean" ? r.reading : base.reading;',
    '    const scale = typeof r.scale === "number" ? clamp(r.scale, 0.8, 1.6) : base.scale;',
    '    return { reading, scale };',
    '  } catch {',
    '    return base;',
    '  }',
    '}',
    '',
    'function getPrefsRaw(): string {',
    '  if (typeof window === "undefined") return "";',
    '  try {',
    '    return window.localStorage.getItem(KEY) ?? "";',
    '  } catch {',
    '    return "";',
    '  }',
    '}',
    '',
    'function setPrefs(p: Prefs) {',
    '  if (typeof window === "undefined") return;',
    '  try {',
    '    window.localStorage.setItem(KEY, JSON.stringify(p));',
    '  } catch {',
    '    // noop',
    '  }',
    '  try {',
    '    window.dispatchEvent(new Event("cv:prefs"));',
    '  } catch {',
    '    // noop',
    '  }',
    '}',
    '',
    'function subscribePrefs(cb: () => void) {',
    '  if (typeof window === "undefined") return () => {};',
    '  const asAny = cb as unknown as EventListener;',
    '  window.addEventListener("storage", asAny);',
    '  window.addEventListener("cv:prefs", asAny);',
    '  return () => {',
    '    window.removeEventListener("storage", asAny);',
    '    window.removeEventListener("cv:prefs", asAny);',
    '  };',
    '}',
    '',
    'function getHydratedSnapshot(): boolean {',
    '  if (typeof window === "undefined") return false;',
    '  const w = window as unknown as { __cvHydrated?: boolean };',
    '  return w.__cvHydrated === true;',
    '}',
    '',
    'function subscribeHydrated(cb: () => void) {',
    '  if (typeof window === "undefined") return () => {};',
    '  const w = window as unknown as { __cvHydrated?: boolean };',
    '  if (w.__cvHydrated === true) return () => {};',
    '  const t = setTimeout(() => {',
    '    (window as unknown as { __cvHydrated?: boolean }).__cvHydrated = true;',
    '    cb();',
    '  }, 0);',
    '  return () => clearTimeout(t);',
    '}',
    '',
    'export default function ReadingControls() {',
    '  // SSR e primeiro render do client: false. Depois vira true via store externo (sem setState em effect).',
    '  const hydrated = useSyncExternalStore(subscribeHydrated, getHydratedSnapshot, () => false);',
    '',
    '  const raw = useSyncExternalStore(subscribePrefs, getPrefsRaw, () => "");',
    '  const prefs = useMemo(() => parsePrefs(raw), [raw]);',
    '',
    '  useEffect(() => {',
    '    if (!hydrated) return;',
    '    try {',
    '      document.documentElement.style.setProperty("--cv-scale", String(prefs.scale));',
    '    } catch {',
    '      // noop',
    '    }',
    '  }, [hydrated, prefs.scale]);',
    '',
    '  const canSpeak = hydrated && typeof window !== "undefined" && typeof (window as unknown as { speechSynthesis?: unknown }).speechSynthesis !== "undefined";',
    '  const utterRef = useRef<SpeechSynthesisUtterance | null>(null);',
    '  const [speaking, setSpeaking] = useState(false);',
    '',
    '  function getSpeakText(): string {',
    '    if (typeof document === "undefined") return "";',
    '    const root = (document.querySelector("[data-cv-content]") as HTMLElement | null) ?? (document.querySelector("main") as HTMLElement | null) ?? document.body;',
    '    const t = root?.innerText ?? root?.textContent ?? "";',
    '    return String(t).replace(/\\s+/g, " ").trim();',
    '  }',
    '',
    '  function onSpeak() {',
    '    if (!canSpeak) return;',
    '    try {',
    '      const ss = window.speechSynthesis;',
    '      if (!ss) return;',
    '      ss.cancel();',
    '      const txt = getSpeakText();',
    '      if (!txt) return;',
    '      const u = new SpeechSynthesisUtterance(txt);',
    '      utterRef.current = u;',
    '      u.onend = () => setSpeaking(false);',
    '      u.onerror = () => setSpeaking(false);',
    '      setSpeaking(true);',
    '      ss.speak(u);',
    '    } catch {',
    '      setSpeaking(false);',
    '    }',
    '  }',
    '',
    '  function onStop() {',
    '    if (!canSpeak) return;',
    '    try {',
    '      window.speechSynthesis.cancel();',
    '    } catch {',
    '      // noop',
    '    }',
    '    setSpeaking(false);',
    '  }',
    '',
    '  function bumpScale(delta: number) {',
    '    const next = clamp((prefs.scale ?? 1) + delta, 0.8, 1.6);',
    '    setPrefs({ reading: prefs.reading, scale: next });',
    '  }',
    '',
    '  const btnClass = "card px-3 py-2 hover:bg-white/10 transition";',
    '  const label = hydrated ? (canSpeak ? "Ouvir" : "Ouvir (indisponivel)") : "Ouvir";',
    '  const disabledSpeak = hydrated ? (!canSpeak) : true;',
    '',
    '  return (',
    '    <section className="card p-4 flex flex-wrap gap-2 items-center" aria-label="Controles de leitura">',
    '      <button type="button" className={btnClass} onClick={onSpeak} disabled={disabledSpeak} aria-label="Ouvir a pagina">',
    '        {label}',
    '      </button>',
    '      <button type="button" className={btnClass} onClick={onStop} disabled={!hydrated || !canSpeak || !speaking} aria-label="Parar leitura">',
    '        Parar',
    '      </button>',
    '',
    '      <div className="flex items-center gap-2 ml-auto">',
    '        <button type="button" className={btnClass} onClick={() => bumpScale(-0.1)} aria-label="Diminuir texto">A-</button>',
    '        <button type="button" className={btnClass} onClick={() => bumpScale(0.1)} aria-label="Aumentar texto">A+</button>',
    '        <span className="opacity-70 text-sm">{Math.round((prefs.scale ?? 1) * 100)}%</span>',
    '      </div>',
    '    </section>',
    '  );',
    '}'
  )

  EnsureDir (Split-Path -Parent $readingPath)
  WriteUtf8NoBom $readingPath ($lines -join "`n")
  Write-Host ("[OK] wrote: " + $readingPath)
  if ($bk) { Write-Host ("[BK] " + $bk) }
} else {
  Write-Host "[SKIP] ReadingControls.tsx nao existe — pulando."
}

# ------------------------------------------------------------
# 2) V2Nav — key unico (key + index)
# ------------------------------------------------------------
$v2NavPath = Join-Path $repo "src\components\v2\V2Nav.tsx"
PatchFile $v2NavPath {
  param($raw)
  $o = $raw

  if ($o -match '\.map\(\(it\)\s*=>') { $o = $o -replace '\.map\(\(it\)\s*=>', '.map((it, i) =>' }
  if ($o -match '\.map\(\(it\)\s*=>\s*\{') { $o = $o -replace '\.map\(\(it\)\s*=>\s*\{', '.map((it, i) => {' }

  if ($o -match 'key=\{it\.key\}') { $o = $o -replace 'key=\{it\.key\}', 'key={it.key + "-" + String(i)}' }

  return $o
} | Out-Null

# ------------------------------------------------------------
# 3) MapaV2 — garantir mapa={mapa} no MapaDockV2
# ------------------------------------------------------------
$mapaV2Path = Join-Path $repo "src\components\v2\MapaV2.tsx"
PatchFile $mapaV2Path {
  param($raw)
  $o = $raw

  if ($o -match '<MapaDockV2\s+slug=\{slug\}\s*/>') {
    $o = $o -replace '<MapaDockV2\s+slug=\{slug\}\s*/>', '<MapaDockV2 slug={slug} mapa={mapa} />'
  }

  return $o
} | Out-Null

# ------------------------------------------------------------
# 4) Next 16.1 — params Promise (best-effort) em pages V2
# ------------------------------------------------------------
$v2Root = Join-Path $repo "src\app\c\[slug]\v2"
if (Test-Path -LiteralPath $v2Root) {
  $pages = Get-ChildItem -LiteralPath $v2Root -Recurse -File -Filter "page.tsx"
  Write-Host ("[DIAG] V2 pages: " + $pages.Count)

  foreach ($f in $pages) {
    PatchFile $f.FullName {
      param($raw)
      $o = $raw

      if ($o -match 'props:\s*\{\s*params:\s*\{\s*slug:\s*string\s*\}\s*\}') {
        $o = $o -replace 'props:\s*\{\s*params:\s*\{\s*slug:\s*string\s*\}\s*\}', 'props: { params: Promise<{ slug: string }> }'
      }

      if ($o -match 'props\.params\.slug' -and ($o -notmatch '\(await props\.params\)\.slug')) {
        $o = $o.Replace('props.params.slug', '(await props.params).slug')
      }

      if ($o -match 'const\s+slug\s*=\s*params\.slug;' -and ($o -notmatch '\(await params\)\.slug')) {
        $o = $o -replace 'const\s+slug\s*=\s*params\.slug;', 'const slug = (await params).slug;'
      }

      return $o
    } | Out-Null
  }
} else {
  Write-Host "[SKIP] pasta V2 nao encontrada."
}

# ------------------------------------------------------------
# VERIFY
# ------------------------------------------------------------
RunPs1 (Join-Path $repo "tools\cv-verify.ps1")

# ------------------------------------------------------------
# REPORT (sem crases)
# ------------------------------------------------------------
$rep = @(
  '# CV — Hotfix v0_39 — Next params Promise + ReadingControls stable + V2Nav keys + MapaDock props',
  '',
  '## O que entrou',
  '- ReadingControls: hidrata sem setState em effect; usa store externo para hydrated; prefs via storage e evento cv:prefs.',
  '- V2Nav: key inclui index para evitar warning.',
  '- MapaV2: garante mapa={mapa} no MapaDockV2.',
  '- Pages V2: props.params.slug passa a usar await (Next 16.1 params Promise).',
  '',
  '## Verify',
  '- tools/cv-verify.ps1 (guard + lint + build)',
  ''
) -join "`n"

WriteReport "cv-hotfix-v2-nextparams-readingcontrols-v0_39.md" $rep | Out-Null
Write-Host "[OK] v0_39 aplicado e verificado."