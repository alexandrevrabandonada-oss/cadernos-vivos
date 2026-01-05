# CV — Hotfix V2 — Mapa fios quentes + props + V2Nav keys + ReadingControls (no setState-in-effect) + Next params Promise — v0_38
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
# 1) ReadingControls — reescrever versão estável (sem setState em effect)
# ------------------------------------------------------------
$readingPath = Join-Path $repo "src\components\ReadingControls.tsx"
if (Test-Path -LiteralPath $readingPath) {
  $bk = BackupFile $readingPath

  $lines = @(
    '"use client";',
    '',
    'import React, { useMemo, useRef, useSyncExternalStore, useEffect, useState } from "react";',
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
    '  if (typeof window !== "undefined") {',
    '    const asAny = cb as unknown as EventListener;',
    '    window.addEventListener("storage", asAny);',
    '    window.addEventListener("cv:prefs", asAny);',
    '    return () => {',
    '      window.removeEventListener("storage", asAny);',
    '      window.removeEventListener("cv:prefs", asAny);',
    '    };',
    '  }',
    '  return () => {};',
    '}',
    '',
    'export default function ReadingControls() {',
    '  // hidratação estável: SSR retorna false; client troca para true após hydration sem setState/effect.',
    '  const hydrated = useSyncExternalStore(() => () => {}, () => true, () => false);',
    '',
    '  // prefs vêm do storage sem precisar setState em effect.',
    '  const raw = useSyncExternalStore(subscribePrefs, getPrefsRaw, () => "");',
    '  const prefs = useMemo(() => parsePrefs(raw), [raw]);',
    '',
    '  // aplica escala no DOM (efeito é OK; não mexe em state).',
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
    '  const label = canSpeak ? "Ouvir" : "Ouvir (indisponível)";',
    '',
    '  return (',
    '    <section className="card p-4 flex flex-wrap gap-2 items-center" aria-label="Controles de leitura">',
    '      <button',
    '        type="button"',
    '        className={btnClass}',
    '        onClick={onSpeak}',
    '        disabled={!canSpeak}',
    '        aria-label="Ouvir a página"',
    '      >',
    '        {label}',
    '      </button>',
    '      <button',
    '        type="button"',
    '        className={btnClass}',
    '        onClick={onStop}',
    '        disabled={!canSpeak || !speaking}',
    '        aria-label="Parar leitura"',
    '      >',
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
  Write-Host "[SKIP] ReadingControls.tsx não existe — pulando."
}

# ------------------------------------------------------------
# 2) V2Nav — evitar warning de key duplicada (key + index)
# ------------------------------------------------------------
$v2NavPath = Join-Path $repo "src\components\v2\V2Nav.tsx"
PatchFile $v2NavPath {
  param($raw)

  $o = $raw

  # garante index no map
  if ($o -match '\.map\(\(it\)\s*=>') {
    $o = $o -replace '\.map\(\(it\)\s*=>', '.map((it, i) =>'
  }
  if ($o -match '\.map\(\(it\)\s*=>\s*\{') {
    $o = $o -replace '\.map\(\(it\)\s*=>\s*\{', '.map((it, i) => {'
  }

  # key={it.key} -> key={it.key + "-" + String(i)}
  if ($o -match 'key=\{it\.key\}') {
    $o = $o -replace 'key=\{it\.key\}', 'key={it.key + "-" + String(i)}'
  }

  return $o
} | Out-Null

# ------------------------------------------------------------
# 3) MapaV2 — passar mapa={mapa} pro MapaDockV2 + fios quentes no Painel
# ------------------------------------------------------------
$mapaV2Path = Join-Path $repo "src\components\v2\MapaV2.tsx"
PatchFile $mapaV2Path {
  param($raw)
  $o = $raw

  # 3a) props MapaDockV2: adiciona mapa={mapa}
  if ($o -match '<MapaDockV2\s+slug=\{slug\}\s*/>') {
    $o = $o -replace '<MapaDockV2\s+slug=\{slug\}\s*/>', '<MapaDockV2 slug={slug} mapa={mapa} />'
  } elseif ($o -match '<MapaDockV2\s+slug=\{slug\}\s*>') {
    $o = $o -replace '<MapaDockV2\s+slug=\{slug\}\s*>', '<MapaDockV2 slug={slug} mapa={mapa}>'
  }

  # 3b) fios quentes: inserir bloco após header "Painel" (best-effort)
  if (($o -notmatch 'Abrir Provas') -and ($o -match '>Painel</div>')) {
    $ins = @(
      '<div style={{ display: "flex", gap: 8, flexWrap: "wrap", marginBottom: 10 }}>',
      '  <a',
      '    href={"/c/" + slug + "/v2/provas?q=" + encodeURIComponent(selectedId || "")}',
      '    style={{ padding: "8px 10px", borderRadius: 10, border: "1px solid rgba(255,255,255,0.18)", textDecoration: "none", background: "rgba(0,0,0,0.20)" }}',
      '  >',
      '    Abrir Provas',
      '  </a>',
      '  <a',
      '    href={"/c/" + slug + "/v2/debate?q=" + encodeURIComponent(selectedId || "")}',
      '    style={{ padding: "8px 10px", borderRadius: 10, border: "1px solid rgba(255,255,255,0.18)", textDecoration: "none", background: "rgba(0,0,0,0.20)" }}',
      '  >',
      '    Abrir Debate',
      '  </a>',
      '  <a',
      '    href={"/c/" + slug + "/v2/linha-do-tempo#" + (selectedId || "")}',
      '    style={{ padding: "8px 10px", borderRadius: 10, border: "1px solid rgba(255,255,255,0.18)", textDecoration: "none", background: "rgba(0,0,0,0.20)" }}',
      '  >',
      '    Abrir Linha',
      '  </a>',
      '  <button',
      '    type="button"',
      '    onClick={() => {',
      '      try {',
      '        const u = window.location.origin + "/c/" + slug + "/v2/mapa#" + (selectedId || "");',
      '        void navigator.clipboard.writeText(u);',
      '      } catch {',
      '        // noop',
      '      }',
      '    }}',
      '    style={{ padding: "8px 10px", borderRadius: 10, border: "1px solid rgba(255,255,255,0.18)", background: "rgba(0,0,0,0.25)", color: "white", cursor: "pointer" }}',
      '  >',
      '    Copiar link',
      '  </button>',
      '</div>'
    ) -join "`n"

    $o = $o -replace '(>Painel</div>)', ('$1' + "`n" + $ins)
  }

  return $o
} | Out-Null

# ------------------------------------------------------------
# 4) Next 16.1 async params/searchParams (best-effort) em pages V2
# ------------------------------------------------------------
$v2Root = Join-Path $repo "src\app\c\[slug]\v2"
if (Test-Path -LiteralPath $v2Root) {
  $pages = Get-ChildItem -LiteralPath $v2Root -Recurse -File -Filter "page.tsx"
  Write-Host ("[DIAG] V2 pages: " + $pages.Count)

  foreach ($f in $pages) {
    PatchFile $f.FullName {
      param($raw)
      $o = $raw

      # props.params.slug -> (await props.params).slug
      if ($o -match 'props\.params\.slug' -and ($o -notmatch '\(await props\.params\)\.slug')) {
        $o = $o.Replace("props.params.slug", "(await props.params).slug")
      }

      # const { slug } = props.params; -> await props.params
      if ($o -match '\=\s*props\.params;' -and ($o -notmatch 'await props\.params')) {
        $o = $o.Replace("= props.params;", "= await props.params;")
      }

      # assinatura tipada comum
      if ($o -match 'props:\s*\{\s*params:\s*\{\s*slug:\s*string\s*\}\s*\}') {
        $o = $o -replace 'props:\s*\{\s*params:\s*\{\s*slug:\s*string\s*\}\s*\}', 'props: { params: Promise<{ slug: string }> }'
      }

      return $o
    } | Out-Null
  }
} else {
  Write-Host "[SKIP] Não achei pasta V2 pages."
}

# ------------------------------------------------------------
# VERIFY
# ------------------------------------------------------------
RunPs1 (Join-Path $repo "tools\cv-verify.ps1")

# ------------------------------------------------------------
# REPORT (sem crases)
# ------------------------------------------------------------
$rep = @(
  '# CV — Hotfix v0_38 — Mapa fios quentes + keys + ReadingControls + Next params',
  '',
  '## O que entrou',
  '- ReadingControls reescrito: sem setState direto em effect; hidratação estável via useSyncExternalStore; aplica escala no DOM.',
  '- V2Nav: key passa a incluir index para evitar warning de duplicidade.',
  '- MapaV2: passa mapa={mapa} para MapaDockV2 (corrige build).',
  '- MapaV2: fios quentes no Painel (Abrir Provas, Abrir Debate, Abrir Linha, Copiar link).',
  '- Best-effort: pages V2 async usando await props.params em Next 16.1.',
  '',
  '## Verify',
  '- tools/cv-verify.ps1 (guard + lint + build)',
  ''
) -join "`n"

WriteReport "cv-hotfix-v2-map-nav-reading-nextparams-v0_38.md" $rep | Out-Null
Write-Host "[OK] v0_38 aplicado e verificado."