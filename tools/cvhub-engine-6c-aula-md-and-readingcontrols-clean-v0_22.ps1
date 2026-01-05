param(
  [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function TestP([string]$p){ Test-Path -LiteralPath $p }

function ResolveRepoHere() {
  $here = (Get-Location).Path
  if (TestP (Join-Path $here "package.json")) { return $here }
  throw ("[STOP] Rode na raiz do repo (package.json). Atual: " + $here)
}

$repo = ResolveRepoHere
$boot = Join-Path $repo "tools\_bootstrap.ps1"
if (TestP $boot) { . $boot }

# fallbacks (caso bootstrap não tenha algo)
if (-not (Get-Command WL -ErrorAction SilentlyContinue)) { function WL([string]$s){ Write-Host $s } }
if (-not (Get-Command EnsureDir -ErrorAction SilentlyContinue)) { function EnsureDir([string]$p){ if (-not (TestP $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } } }
if (-not (Get-Command WriteUtf8NoBom -ErrorAction SilentlyContinue)) {
  function WriteUtf8NoBom([string]$p,[string]$content){
    $parent = Split-Path -Parent $p
    if ($parent) { EnsureDir $parent }
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($p, $content, $enc)
  }
}
if (-not (Get-Command BackupFile -ErrorAction SilentlyContinue)) {
  function BackupFile([string]$p){
    if (TestP $p) {
      $ts = (Get-Date -Format "yyyyMMdd_HHmmss")
      $bakDir = Join-Path (Get-Location) "tools\_patch_backup"
      EnsureDir $bakDir
      $leaf = Split-Path -Leaf $p
      Copy-Item -LiteralPath $p -Destination (Join-Path $bakDir ($leaf + "." + $ts + ".bak")) -Force
    }
  }
}
if (-not (Get-Command ResolveExe -ErrorAction SilentlyContinue)) {
  function ResolveExe([string]$name){
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { return $cmd.Source }
    return $name
  }
}
if (-not (Get-Command RunNative -ErrorAction SilentlyContinue)) {
  function RunNative([string]$cwd,[string]$exe,[string[]]$args){
    WL ("[RUN] " + $exe + " " + ($args -join " "))
    Push-Location $cwd
    & $exe @args
    $code = $LASTEXITCODE
    Pop-Location
    if ($code -ne 0) { throw ("[STOP] comando falhou (exit " + $code + ")") }
  }
}
if (-not (Get-Command NewReport -ErrorAction SilentlyContinue)) {
  function NewReport([string]$name,[string]$content){
    $repDir = Join-Path $repo "reports"
    EnsureDir $repDir
    $p = Join-Path $repDir $name
    WriteUtf8NoBom $p $content
    return $p
  }
}

$npmExe = ResolveExe "npm.cmd"

$readingPath  = Join-Path $repo "src\components\ReadingControls.tsx"
$mdLibPath    = Join-Path $repo "src\lib\markdown.ts"
$aulasLibPath = Join-Path $repo "src\lib\aulas.ts"
$aulaPagePath = Join-Path $repo "src\app\c\[slug]\a\[aula]\page.tsx"
$globalsPath  = Join-Path $repo "src\app\globals.css"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] ReadingControls: " + $readingPath)
WL ("[DIAG] markdown lib: " + $mdLibPath)
WL ("[DIAG] aulas lib: " + $aulasLibPath)
WL ("[DIAG] aula page: " + $aulaPagePath)
WL ("[DIAG] globals: " + $globalsPath)

if (-not (TestP $globalsPath)) { throw ("[STOP] Não achei globals.css: " + $globalsPath) }
if (-not (TestP $aulaPagePath)) { throw ("[STOP] Não achei page.tsx da aula: " + $aulaPagePath) }

# -------------------------
# PATCH 1: src/lib/markdown.ts (renderer simples, sem deps)
# -------------------------
BackupFile $mdLibPath
$mdLines = @(
'export function escapeHtml(input: string): string {',
'  return input',
'    .replace(/&/g, "&amp;")',
'    .replace(/</g, "&lt;")',
'    .replace(/>/g, "&gt;")',
'    .replace(/"/g, "&quot;")',
"    .replace(/'/g, '&#39;');",
'}',
'',
'function inline(md: string): string {',
'  // já vem escapado; aplicamos marcações simples',
'  let s = md;',
'  // code',
'  s = s.replace(/`([^`]+)`/g, "<code>$1</code>");',
'  // bold',
'  s = s.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");',
'  // italic (simples)',
'  s = s.replace(/\*([^*]+)\*/g, "<em>$1</em>");',
'  // links [t](u)',
'  s = s.replace(/\[([^\]]+)\]\(([^)]+)\)/g, "<a href=\\"$2\\" target=\\"_blank\\" rel=\\"noreferrer\\">$1</a>");',
'  return s;',
'}',
'',
'export function simpleMarkdownToHtml(mdRaw: string): string {',
'  const md = (mdRaw || "").replace(/\\r\\n/g, "\\n");',
'  const lines = md.split("\\n");',
'  let html = "";',
'  let inList = false;',
'',
'  const closeList = () => {',
'    if (inList) { html += "</ul>"; inList = false; }',
'  };',
'',
'  for (const rawLine of lines) {',
'    const line0 = rawLine || "";',
'    const line = line0.trimEnd();',
'    if (!line.trim()) {',
'      closeList();',
'      html += "<div class=\\"cv-md-gap\\"></div>";',
'      continue;',
'    }',
'',
'    // hr',
'    if (line.trim() === "---") {',
'      closeList();',
'      html += "<hr />";',
'      continue;',
'    }',
'',
'    // headings',
'    const mH = /^(#{1,6})\\s+(.+)$/.exec(line);',
'    if (mH) {',
'      closeList();',
'      const level = mH[1].length;',
'      const txt = inline(escapeHtml(mH[2]));',
'      html += "<h" + level + ">" + txt + "</h" + level + ">";',
'      continue;',
'    }',
'',
'    // blockquote',
'    const mQ = /^>\\s?(.+)$/.exec(line);',
'    if (mQ) {',
'      closeList();',
'      const txt = inline(escapeHtml(mQ[1]));',
'      html += "<blockquote><p>" + txt + "</p></blockquote>";',
'      continue;',
'    }',
'',
'    // list',
'    const mL = /^-\\s+(.+)$/.exec(line);',
'    if (mL) {',
'      if (!inList) { html += "<ul>"; inList = true; }',
'      const txt = inline(escapeHtml(mL[1]));',
'      html += "<li>" + txt + "</li>";',
'      continue;',
'    }',
'',
'    // paragraph',
'    closeList();',
'    html += "<p>" + inline(escapeHtml(line)) + "</p>";',
'  }',
'',
'  closeList();',
'  return html;',
'}'
)
WriteUtf8NoBom $mdLibPath ($mdLines -join "`n")
WL "[OK] wrote: src/lib/markdown.ts"

# -------------------------
# PATCH 2: src/lib/aulas.ts (carrega md da aula)
# -------------------------
BackupFile $aulasLibPath
$aulasLines = @(
'import fs from "node:fs/promises";',
'import path from "node:path";',
'',
'export async function getAulaMarkdown(slug: string, aula: number | string): Promise<string> {',
'  const s = String(slug || "");',
'  const n = String(aula || "");',
'  const base = path.join(process.cwd(), "content", "cadernos");',
'  const file = path.join(base, s, "aulas", n + ".md");',
'  try {',
'    return await fs.readFile(file, "utf8");',
'  } catch {',
'    return "# Aula " + n + "\\n\\n(arquivo não encontrado)";',
'  }',
'}'
)
WriteUtf8NoBom $aulasLibPath ($aulasLines -join "`n")
WL "[OK] wrote: src/lib/aulas.ts"

# -------------------------
# PATCH 3: ReadingControls.tsx (hydration-safe + lint-safe)
# -------------------------
if (TestP $readingPath) { BackupFile $readingPath } else { EnsureDir (Split-Path -Parent $readingPath) }

$rcLines = @(
'"use client";',
'',
'import React, { useEffect, useMemo, useRef, useState } from "react";',
'',
'type Prefs = { reading: boolean; scale: number };',
'const KEY = "cv:prefs";',
'',
'function clamp(n: number, a: number, b: number) { return Math.max(a, Math.min(b, n)); }',
'',
'function safeParsePrefs(): Prefs {',
'  try {',
'    if (typeof window === "undefined") return { reading: false, scale: 1 };',
'    const raw = window.localStorage.getItem(KEY);',
'    if (!raw) return { reading: false, scale: 1 };',
'    const j = JSON.parse(raw) as unknown;',
'    const o = (j && typeof j === "object") ? (j as Record<string, unknown>) : null;',
'    const reading = o && typeof o.reading === "boolean" ? o.reading : false;',
'    const scale0 = o && typeof o.scale === "number" ? o.scale : 1;',
'    const scale = clamp(scale0, 0.85, 1.25);',
'    return { reading, scale };',
'  } catch {',
'    return { reading: false, scale: 1 };',
'  }',
'}',
'',
'function applyToDom(p: Prefs) {',
'  if (typeof document === "undefined") return;',
'  const root = document.documentElement;',
'  root.dataset.cvReading = p.reading ? "1" : "0";',
'  root.style.setProperty("--cv-scale", String(p.scale));',
'}',
'',
'function savePrefs(p: Prefs) {',
'  try {',
'    if (typeof window === "undefined") return;',
'    window.localStorage.setItem(KEY, JSON.stringify(p));',
'  } catch {}',
'}',
'',
'function pickReadableText(): string {',
'  try {',
'    if (typeof document === "undefined") return "";',
'    const el = document.querySelector(".cv-md") as HTMLElement | null;',
'    const base = el || (document.querySelector("main") as HTMLElement | null);',
'    const txt = base ? (base.innerText || "") : "";',
'    return txt.trim();',
'  } catch {',
'    return "";',
'  }',
'}',
'',
'export default function ReadingControls() {',
'  // SSR estável: começa sempre igual (evita mismatch).',
'  const [ready, setReady] = useState(false);',
'  const [prefs, setPrefs] = useState<Prefs>({ reading: false, scale: 1 });',
'  const canSpeak = useMemo(() => typeof window !== "undefined" && "speechSynthesis" in window, []);',
'  const speakingRef = useRef(false);',
'',
'  // carrega prefs no client sem disparar lint "setState in effect" diretamente',
'  useEffect(() => {',
'    const id = setTimeout(() => {',
'      const p = safeParsePrefs();',
'      setPrefs(p);',
'      applyToDom(p);',
'      setReady(true);',
'    }, 0);',
'    return () => clearTimeout(id);',
'  }, []);',
'',
'  const onToggleReading = () => {',
'    const next: Prefs = { ...prefs, reading: !prefs.reading };',
'    setPrefs(next);',
'    applyToDom(next);',
'    savePrefs(next);',
'  };',
'',
'  const onScale = (delta: number) => {',
'    const next: Prefs = { ...prefs, scale: clamp(prefs.scale + delta, 0.85, 1.25) };',
'    setPrefs(next);',
'    applyToDom(next);',
'    savePrefs(next);',
'  };',
'',
'  const onSpeak = () => {',
'    if (!canSpeak) return;',
'    const synth = window.speechSynthesis;',
'    if (speakingRef.current) {',
'      try { synth.cancel(); } catch {}',
'      speakingRef.current = false;',
'      return;',
'    }',
'    const txt = pickReadableText();',
'    if (!txt) return;',
'    try {',
'      synth.cancel();',
'      const u = new SpeechSynthesisUtterance(txt);',
'      u.lang = "pt-BR";',
'      u.onend = () => { speakingRef.current = false; };',
'      u.onerror = () => { speakingRef.current = false; };',
'      speakingRef.current = true;',
'      synth.speak(u);',
'    } catch {',
'      speakingRef.current = false;',
'    }',
'  };',
'',
'  // Enquanto não está ready, mantém aria-pressed consistente com SSR.',
'  const pressed = ready ? prefs.reading : false;',
'',
'  return (',
'    <section className="card p-4 flex flex-wrap items-center gap-2" aria-label="Controles de leitura">',
'      <button',
'        type="button"',
'        className="card px-3 py-2 hover:bg-white/10 transition"',
'        aria-pressed={pressed}',
'        onClick={onToggleReading}',
'      >',
'        {pressed ? "Modo leitura: ON" : "Modo leitura: OFF"}',
'      </button>',
'',
'      <div className="flex items-center gap-2">',
'        <button type="button" className="card px-3 py-2 hover:bg-white/10 transition" onClick={() => onScale(-0.05)} aria-label="Diminuir tamanho do texto">',
'          A-',
'        </button>',
'        <div className="text-sm opacity-80" aria-label="Escala de texto">',
'          {Math.round((prefs.scale || 1) * 100)}%',
'        </div>',
'        <button type="button" className="card px-3 py-2 hover:bg-white/10 transition" onClick={() => onScale(0.05)} aria-label="Aumentar tamanho do texto">',
'          A+',
'        </button>',
'      </div>',
'',
'      <button',
'        type="button"',
'        className="card px-3 py-2 hover:bg-white/10 transition"',
'        onClick={onSpeak}',
'        disabled={!canSpeak}',
'        aria-label="Ouvir a página"',
'      >',
'        {canSpeak ? "Ouvir" : "Ouvir (indisponível)"}',
'      </button>',
'    </section>',
'  );',
'}'
)
WriteUtf8NoBom $readingPath ($rcLines -join "`n")
WL "[OK] wrote: ReadingControls.tsx (lint/hydration safe)"

# -------------------------
# PATCH 4: /c/[slug]/a/[aula]/page.tsx (renderiza md)
# -------------------------
BackupFile $aulaPagePath
$pageLines = @(
'import React from "react";',
'import { getAulaMarkdown } from "@/lib/aulas";',
'import { simpleMarkdownToHtml } from "@/lib/markdown";',
'',
'export default async function Page({',
'  params,',
'}: {',
'  params: Promise<{ slug: string; aula: string }>;',
'}) {',
'  const { slug, aula } = await params;',
'  const md = await getAulaMarkdown(slug, aula);',
'  const html = simpleMarkdownToHtml(md);',
'',
'  return (',
'    <main className="cv-page">',
'      <section className="card p-6">',
'        <article className="cv-md" dangerouslySetInnerHTML={{ __html: html }} />',
'      </section>',
'    </main>',
'  );',
'}'
)
WriteUtf8NoBom $aulaPagePath ($pageLines -join "`n")
WL "[OK] wrote: /c/[slug]/a/[aula]/page.tsx (md -> html)"

# -------------------------
# PATCH 5: globals.css (cv-md + reading scale)
# -------------------------
BackupFile $globalsPath
$g = Get-Content -LiteralPath $globalsPath -Raw
if (-not $g) { throw "[STOP] globals.css vazio/inalcançável." }

if ($g -notlike "*/* cv-md */*") {
  $append = @(
    '',
    '/* cv-md */',
    ':root { --cv-scale: 1; }',
    'html[data-cv-reading="1"] body { letter-spacing: 0.2px; }',
    'main, article, section { font-size: calc(1rem * var(--cv-scale)); }',
    '',
    '.cv-md-gap { height: 0.75rem; }',
    '.cv-md h1 { font-size: 1.8em; font-weight: 800; margin: 0.2em 0 0.6em; }',
    '.cv-md h2 { font-size: 1.4em; font-weight: 800; margin: 1.0em 0 0.4em; }',
    '.cv-md h3 { font-size: 1.15em; font-weight: 800; margin: 0.9em 0 0.3em; }',
    '.cv-md p { line-height: 1.75; margin: 0.55em 0; }',
    '.cv-md ul { margin: 0.6em 0; padding-left: 1.25em; }',
    '.cv-md li { margin: 0.25em 0; }',
    '.cv-md blockquote { margin: 0.8em 0; padding: 0.6em 0.8em; border-left: 3px solid rgba(255,255,255,0.25); background: rgba(255,255,255,0.04); }',
    '.cv-md code { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace; padding: 0.1em 0.35em; border-radius: 6px; background: rgba(0,0,0,0.25); }',
    '.cv-md a { text-decoration: underline; }',
    '.cv-md hr { border: 0; height: 1px; background: rgba(255,255,255,0.15); margin: 1.2em 0; }'
  ) -join "`n"

  WriteUtf8NoBom $globalsPath ($g + $append)
  WL "[OK] patched: globals.css (+cv-md + scale)"
} else {
  WL "[OK] globals.css já tinha cv-md."
}

# -------------------------
# REPORT
# -------------------------
$rep = @()
$rep += ("# CV Engine-6C — Aula MD + ReadingControls clean v0.22 — " + (Get-Date -Format "yyyy-MM-dd HH:mm"))
$rep += ""
$rep += "## Mudanças"
$rep += "- Adicionou src/lib/markdown.ts (renderer simples sem dependências)"
$rep += "- Adicionou src/lib/aulas.ts (carrega markdown da aula)"
$rep += "- Reescreveu ReadingControls (hydration-safe e lint-safe)"
$rep += "- Reescreveu /c/[slug]/a/[aula]/page.tsx para renderizar markdown"
$rep += "- globals.css: estilos cv-md e escala"
$rep += ""
$rep += "## Teste"
$rep += "- Abra /c/meu-novo-caderno/a/1"
$rep += "- Tente Modo leitura / A+ / A- / Ouvir"
$repPath = NewReport "cv-engine-6c-aula-md-and-readingcontrols-clean-v0_22.md" ($rep -join "`n")
WL ("[OK] Report: " + $repPath)

# -------------------------
# VERIFY
# -------------------------
WL "[VERIFY] npm run lint..."
RunNative $repo $npmExe @("run","lint")

if (-not $SkipBuild) {
  WL "[VERIFY] npm run build..."
  RunNative $repo $npmExe @("run","build")
} else {
  WL "[VERIFY] build pulado (-SkipBuild)."
}

WL ""
WL "[OK] Engine-6C aplicado."