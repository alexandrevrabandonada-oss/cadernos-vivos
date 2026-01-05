param(
  [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function TestP([string]$p) { Test-Path -LiteralPath $p }
$repo = (Get-Location).Path
$tools = Join-Path $repo "tools"
$boot  = Join-Path $tools "_bootstrap.ps1"

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
# PATCH 1: ReadingControls (hydration safe)
# -------------------------
BackupFile $readingPath

$rc = @(
'"use client";',
'',
'import React, { useEffect, useMemo, useRef, useState } from "react";',
'',
'type Prefs = { reading: boolean; scale: number };',
'',
'function safeParsePrefs(): Prefs {',
'  if (typeof window === "undefined") return { reading: false, scale: 1 };',
'  try {',
'    const raw = window.localStorage.getItem("cv_reading_prefs");',
'    if (!raw) return { reading: false, scale: 1 };',
'    const obj = JSON.parse(raw) as { reading?: unknown; scale?: unknown };',
'    const reading = obj.reading === true;',
'    const scale = (typeof obj.scale === "number" && obj.scale >= 0.9 && obj.scale <= 1.6) ? obj.scale : 1;',
'    return { reading, scale };',
'  } catch {',
'    return { reading: false, scale: 1 };',
'  }',
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
'  const [mounted, setMounted] = useState(false);',
'  // IMPORTANT: estado inicial fixo para bater server/client (evita hydration mismatch)',
'  const [reading, setReading] = useState(false);',
'  const [scale, setScale] = useState(1);',
'  const [speaking, setSpeaking] = useState(false);',
'  const utterRef = useRef<SpeechSynthesisUtterance | null>(null);',
'',
'  useEffect(() => {',
'    setMounted(true);',
'    const p = safeParsePrefs();',
'    setReading(p.reading);',
'    setScale(p.scale);',
'  }, []);',
'',
'  useEffect(() => {',
'    if (!mounted) return;',
'    const p: Prefs = { reading, scale };',
'    applyPrefs(p);',
'    try { window.localStorage.setItem("cv_reading_prefs", JSON.stringify(p)); } catch {}',
'  }, [mounted, reading, scale]);',
'',
'  const canTts = useMemo(() => (typeof window !== "undefined" && "speechSynthesis" in window), []);',
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
'        aria-pressed={reading}',
'        onClick={() => setReading(v => !v)}',
'      >',
'        {reading ? "Leitura: ON" : "Leitura: OFF"}',
'      </button>',
'',
'      <label className="text-sm muted flex items-center gap-2" aria-label="Tamanho do texto">',
'        <span>A</span>',
'        <input',
'          type="range"',
'          min={0.9}',
'          max={1.6}',
'          step={0.05}',
'          value={scale}',
'          onChange={(e) => setScale(Number(e.target.value))}',
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
) -join "`n"

WriteUtf8NoBom $readingPath $rc
WL "[OK] wrote: ReadingControls.tsx (hydration-safe)"

# -------------------------
# PATCH 2: getCaderno meta.slug fallback (sem exigir mexer em meta.json)
# -------------------------
BackupFile $cadernosPath
$raw = Get-Content -LiteralPath $cadernosPath -Raw

$needle1 = 'const meta = CadernoMeta.parse(JSON.parse(await fs.readFile(metaPath, "utf8")));'
$needle2 = "const meta = CadernoMeta.parse(JSON.parse(await fs.readFile(metaPath, 'utf8')));"

$replacement = @(
'  const metaRaw = JSON.parse(await fs.readFile(metaPath, "utf8"));',
'  if (!metaRaw.slug) metaRaw.slug = slug;',
'  const meta = CadernoMeta.parse(metaRaw);'
) -join "`n"

$patched = $false
if ($raw.Contains($needle1)) {
  $raw = $raw.Replace($needle1, $replacement)
  $patched = $true
} elseif ($raw.Contains($needle2)) {
  $raw = $raw.Replace($needle2, $replacement)
  $patched = $true
}

if ($patched) {
  WriteUtf8NoBom $cadernosPath $raw
  WL "[OK] patched: cadernos.ts (meta.slug fallback antes do parse)"
} else {
  WL "[WARN] Não encontrei o trecho exato do parse do meta. Nenhuma mudança em cadernos.ts."
}

# -------------------------
# REPORT + VERIFY
# -------------------------
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$rep = NewReport "cv-engine-5a-meta-slug-infer-and-reading-hydration-v0_18.md" @(
("# CV Engine-5A — Meta slug fallback + ReadingControls hydration-safe — " + $now),
"",
"## O que mudou",
"- ReadingControls: estado inicial fixo (server/client) + carrega preferências só após mount.",
"- cadernos.ts: se meta.json não tiver slug, inferimos pelo folder/rota (slug) antes do Zod parse.",
"",
"## Por quê",
"- Evita ZodError ao abrir cadernos recém-criados sem slug no meta.",
"- Remove warnings de hydration causados por preferências lidas cedo demais.",
"",
"## Próximo",
"- Padronizar spec do meta.json (mood/accent) e usar isso pra 'cada página ser um universo'."
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
WL "[OK] Engine-5A aplicado."