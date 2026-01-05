param(
  [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function TestP([string]$p) { Test-Path -LiteralPath $p }

$repo = (Get-Location).Path
$boot = Join-Path $repo "tools\_bootstrap.ps1"
if (TestP $boot) {
  . $boot
} else {
  function WL([string]$s) { Write-Host $s }
  function EnsureDir([string]$p) { if (-not (TestP $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
  function WriteUtf8NoBom([string]$p, [string]$content) {
    $parent = Split-Path -Parent $p
    if ($parent) { EnsureDir $parent }
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($p, $content, $enc)
  }
  function BackupFile([string]$p) {
    if (TestP $p) {
      $ts = (Get-Date -Format "yyyyMMdd_HHmmss")
      $bakDir = Join-Path $repo "tools\_patch_backup"
      EnsureDir $bakDir
      $leaf = Split-Path -Leaf $p
      Copy-Item -LiteralPath $p -Destination (Join-Path $bakDir ($leaf + "." + $ts + ".bak")) -Force
    }
  }
  function ResolveExe([string]$name) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { return $cmd.Source }
    return $name
  }
  function RunNative([string]$cwd, [string]$exe, [string[]]$cmdArgs) {
    $pretty = ($cmdArgs -join " ")
    WL ("[RUN] " + $exe + " " + $pretty)
    Push-Location $cwd
    & $exe @cmdArgs
    $code = $LASTEXITCODE
    Pop-Location
    if ($code -ne 0) { throw ("[STOP] comando falhou (exit " + $code + "): " + $exe + " " + $pretty) }
  }
  function NewReport([string]$name, [string[]]$lines) {
    $repDir = Join-Path $repo "reports"
    EnsureDir $repDir
    $p = Join-Path $repDir $name
    WriteUtf8NoBom $p ($lines -join "`n")
    return $p
  }
}

$npmExe = (Get-Command npm.cmd -ErrorAction SilentlyContinue).Source
if (-not $npmExe) { $npmExe = "npm.cmd" }

$readingPath = Join-Path $repo "src\components\ReadingControls.tsx"
$cadernosPath = Join-Path $repo "src\lib\cadernos.ts"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] ReadingControls: " + $readingPath)
WL ("[DIAG] cadernos.ts: " + $cadernosPath)

if (-not (TestP $readingPath)) { throw ("[STOP] Não achei: " + $readingPath) }
if (-not (TestP $cadernosPath)) { throw ("[STOP] Não achei: " + $cadernosPath) }

# -------------------------
# PATCH 1: ReadingControls — prefs via useSyncExternalStore (sem setState em effect)
# -------------------------
BackupFile $readingPath

$rcLines = @(
'"use client";',
'',
'import React, { useEffect, useMemo, useRef, useState, useSyncExternalStore } from "react";',
'',
'type Prefs = { reading: boolean; scale: number };',
'',
'const KEY = "cv_reading_prefs";',
'const EVT = "cv:prefs";',
'const DEFAULT_RAW = ''{"reading":false,"scale":1}'';',
'',
'function normalize(obj: unknown): Prefs {',
'  const o = (obj && typeof obj === "object") ? (obj as { reading?: unknown; scale?: unknown }) : {};',
'  const reading = o.reading === true;',
'  const scale = (typeof o.scale === "number" && o.scale >= 0.9 && o.scale <= 1.6) ? o.scale : 1;',
'  return { reading, scale };',
'}',
'',
'function readRaw(): string {',
'  if (typeof window === "undefined") return DEFAULT_RAW;',
'  try {',
'    const v = window.localStorage.getItem(KEY);',
'    return v ? String(v) : DEFAULT_RAW;',
'  } catch {',
'    return DEFAULT_RAW;',
'  }',
'}',
'',
'function subscribe(cb: () => void): () => void {',
'  if (typeof window === "undefined") return () => {};',
'  const onStorage = (e: StorageEvent) => {',
'    if (!e || !("key" in e) || e.key === null || e.key === KEY) cb();',
'  };',
'  const onCustom = () => cb();',
'  window.addEventListener("storage", onStorage);',
'  window.addEventListener(EVT, onCustom);',
'  return () => {',
'    window.removeEventListener("storage", onStorage);',
'    window.removeEventListener(EVT, onCustom);',
'  };',
'}',
'',
'function getServerSnapshot(): string {',
'  return DEFAULT_RAW;',
'}',
'',
'function getSnapshot(): string {',
'  return readRaw();',
'}',
'',
'function writePrefs(p: Prefs) {',
'  if (typeof window === "undefined") return;',
'  try { window.localStorage.setItem(KEY, JSON.stringify(p)); } catch {}',
'  try { window.dispatchEvent(new Event(EVT)); } catch {}',
'}',
'',
'function applyPrefs(p: Prefs) {',
'  if (typeof document === "undefined") return;',
'  const root = document.documentElement;',
'  root.classList.toggle("cv-reading", p.reading);',
'  root.style.setProperty("--cv-font-scale", String(p.scale));',
'}',
'',
'export default function ReadingControls() {',
'  const raw = useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot);',
'  const prefs = useMemo(() => {',
'    try { return normalize(JSON.parse(raw)); } catch { return normalize(null); }',
'  }, [raw]);',
'',
'  const [speaking, setSpeaking] = useState(false);',
'  const utterRef = useRef<SpeechSynthesisUtterance | null>(null);',
'',
'  const canTts = useMemo(() => (typeof window !== "undefined" && "speechSynthesis" in window), []);',
'',
'  useEffect(() => {',
'    // efeito só sincroniza DOM (externo) — sem setState',
'    applyPrefs(prefs);',
'  }, [prefs.reading, prefs.scale]);',
'',
'  function pickText(): string {',
'    if (typeof document === "undefined") return "";',
'    const main = document.querySelector("main");',
'    const t = main ? (main as HTMLElement).innerText : document.body.innerText;',
'    return (t || "").trim();',
'  }',
'',
'  function stopTts() {',
'    if (typeof window === "undefined") return;',
'    try { window.speechSynthesis.cancel(); } catch {}',
'    utterRef.current = null;',
'    setSpeaking(false);',
'  }',
'',
'  function startTts() {',
'    if (!canTts) return;',
'    const text = pickText();',
'    if (!text) return;',
'    stopTts();',
'    const u = new SpeechSynthesisUtterance(text);',
'    utterRef.current = u;',
'    u.onend = () => { setSpeaking(false); utterRef.current = null; };',
'    u.onerror = () => { setSpeaking(false); utterRef.current = null; };',
'    setSpeaking(true);',
'    window.speechSynthesis.speak(u);',
'  }',
'',
'  return (',
'    <section className="card p-4 flex flex-wrap gap-2 items-center" aria-label="Controles de leitura">',
'      <button',
'        type="button"',
'        className="card px-3 py-2 hover:bg-white/10 transition"',
'        aria-pressed={prefs.reading}',
'        onClick={() => writePrefs({ reading: !prefs.reading, scale: prefs.scale })}',
'      >',
'        {prefs.reading ? "Leitura: ON" : "Leitura: OFF"}',
'      </button>',
'',
'      <label className="text-sm muted flex items-center gap-2" aria-label="Tamanho do texto">',
'        <span>A</span>',
'        <input',
'          type="range"',
'          min={0.9}',
'          max={1.6}',
'          step={0.05}',
'          value={prefs.scale}',
'          onChange={(e) => writePrefs({ reading: prefs.reading, scale: Number(e.target.value) })}',
'        />',
'        <span>A+</span>',
'      </label>',
'',
'      <div className="flex gap-2 items-center">',
'        <button',
'          type="button"',
'          className="card px-3 py-2 hover:bg-white/10 transition"',
'          onClick={() => (speaking ? stopTts() : startTts())}',
'          disabled={!canTts}',
'          aria-pressed={speaking}',
'        >',
'          {canTts ? (speaking ? "Parar voz" : "Ouvir") : "Voz indisponível"}',
'        </button>',
'      </div>',
'    </section>',
'  );',
'}',
''
)

WriteUtf8NoBom $readingPath ($rcLines -join "`n")
WL "[OK] wrote: ReadingControls.tsx (useSyncExternalStore; sem setState em effect)"

# -------------------------
# PATCH 2: cadernos.ts — meta.slug fallback antes do parse (line-based, robusto)
# -------------------------
BackupFile $cadernosPath
$lines = Get-Content -LiteralPath $cadernosPath
$changed = $false

for ($i = 0; $i -lt $lines.Count; $i++) {
  $line = $lines[$i]
  if ($line -like "*CadernoMeta.parse*" -and $line -like "*metaPath*" -and $line -like "*const meta*") {
    $indent = ""
    if ($line -match '^(\s*)') { $indent = $Matches[1] }
    $lines[$i] = ($indent + 'const metaRaw = JSON.parse(await fs.readFile(metaPath, "utf8"));')
    $insert = @(
      ($indent + 'if (!metaRaw.slug) metaRaw.slug = slug;'),
      ($indent + 'const meta = CadernoMeta.parse(metaRaw);')
    )
    $before = @()
    if ($i -gt 0) { $before = $lines[0..($i)] } else { $before = @($lines[$i]) }
    $after = @()
    if (($i + 1) -le ($lines.Count - 1)) { $after = $lines[($i + 1)..($lines.Count - 1)] }
    $lines = @($before + $insert + $after)
    $changed = $true
    break
  }
}

if ($changed) {
  WriteUtf8NoBom $cadernosPath ($lines -join "`n")
  WL "[OK] patched: cadernos.ts (meta.slug fallback antes do Zod parse)"
} else {
  WL "[WARN] Não encontrei a linha do parse do meta para patch (procurei por: const meta + CadernoMeta.parse + metaPath)."
}

# -------------------------
# REPORT + VERIFY
# -------------------------
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$rep = NewReport "cv-hotfix-readingcontrols-store-and-meta-slug-v0_18b.md" @(
("# CV Hotfix v0.18b — ReadingControls store + meta.slug fallback — " + $now),
"",
"## Fixes",
"- ReadingControls: prefs via useSyncExternalStore (SSR/hydration estável; lint sem setState-in-effect).",
"- cadernos.ts: meta.slug é preenchido com o slug da rota se não existir no meta.json (antes do Zod parse).",
"",
"## Motivo",
"- Corrige o erro do eslint react-hooks/set-state-in-effect.",
"- Remove ZodError de meta.slug undefined em cadernos novos."
)

WL ("[OK] Report: " + $rep)

WL "[VERIFY] npm run lint..."
RunNative $repo $npmExe @("run","lint")

if (-not $SkipBuild) {
  WL "[VERIFY] npm run build..."
  RunNative $repo $npmExe @("run","build")
} else {
  WL "[VERIFY] build pulado (-SkipBuild)."
}

WL ""
WL "[OK] Hotfix aplicado."