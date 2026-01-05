param(
  [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function WL([string]$s) { Write-Host $s }
function EnsureDir([string]$p) { if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function WriteUtf8NoBom([string]$p, [string]$content) {
  $parent = Split-Path -Parent $p
  if ($parent) { EnsureDir $parent }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($p, $content, $enc)
}
function BackupFile([string]$p) {
  if (Test-Path -LiteralPath $p) {
    $ts = (Get-Date -Format "yyyyMMdd_HHmmss")
    $bakDir = Join-Path (Get-Location) "tools\_patch_backup"
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
function FindRepoRoot() {
  $here = (Get-Location).Path
  $p = $here
  for ($i=0; $i -lt 10; $i++) {
    if (Test-Path -LiteralPath (Join-Path $p "package.json")) { return $p }
    $parent = Split-Path -Parent $p
    if (-not $parent -or $parent -eq $p) { break }
    $p = $parent
  }
  throw ("[STOP] Rode na raiz do repo (onde tem package.json). Atual: " + $here)
}
function NewReportLocal([string]$repo, [string]$name, [string[]]$lines) {
  $rep = Join-Path $repo "reports"
  EnsureDir $rep
  $p = Join-Path $rep $name
  WriteUtf8NoBom $p ($lines -join "`n")
  return $p
}

# -------------------------
# DIAG
# -------------------------
$repo = FindRepoRoot
$npmExe = ResolveExe "npm.cmd"
$readingPath = Join-Path $repo "src\components\ReadingControls.tsx"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] ReadingControls: " + $readingPath)

if (-not (Test-Path -LiteralPath $readingPath)) {
  throw ("[STOP] Não achei: " + $readingPath)
}

BackupFile $readingPath

# -------------------------
# PATCH: reescreve ReadingControls SSR-safe
# - NÃO lê localStorage/window no render
# - carrega preferências só no useEffect (após hydrate)
# -------------------------
$lines = @(
'"use client";',
'',
'import React from "react";',
'',
'const LS = {',
'  reading: "cv_reading_mode",',
'  font: "cv_font_scale",',
'} as const;',
'',
'function clamp(n: number, min: number, max: number) {',
'  return Math.min(max, Math.max(min, n));',
'}',
'',
'function safeNumber(v: string | null, fallback: number) {',
'  const n = Number(v);',
'  return Number.isFinite(n) ? n : fallback;',
'}',
'',
'function getMainText(): string {',
'  if (typeof document === "undefined") return "";',
'  const main = document.querySelector("main");',
'  const t = (main ? (main as HTMLElement).innerText : "") || "";',
'  return t.replace(/\s+\n/g, "\n").trim();',
'}',
'',
'export default function ReadingControls() {',
'  // IMPORTANT: defaults precisam bater no SSR, então nada de window/localStorage aqui',
'  const [readingMode, setReadingMode] = React.useState(false);',
'  const [fontScale, setFontScale] = React.useState(1);',
'  const [speaking, setSpeaking] = React.useState(false);',
'',
'  // Carrega preferências depois do hydrate (evita mismatch)',
'  React.useEffect(() => {',
'    try {',
'      const rm = (localStorage.getItem(LS.reading) || "") === "1";',
'      const fs = clamp(safeNumber(localStorage.getItem(LS.font), 1), 0.9, 1.35);',
'      setReadingMode(rm);',
'      setFontScale(fs);',
'    } catch {',
'      // ignore',
'    }',
'  }, []);',
'',
'  // Aplica no DOM + persiste',
'  React.useEffect(() => {',
'    if (typeof document === "undefined") return;',
'    const root = document.documentElement;',
'    root.dataset.cvReading = readingMode ? "on" : "off";',
'    root.style.setProperty("--cv-font-scale", String(fontScale));',
'    try { localStorage.setItem(LS.reading, readingMode ? "1" : "0"); } catch {}',
'    try { localStorage.setItem(LS.font, String(fontScale)); } catch {}',
'  }, [readingMode, fontScale]);',
'',
'  // Cleanup TTS',
'  React.useEffect(() => {',
'    return () => {',
'      try {',
'        if (typeof window !== "undefined" && "speechSynthesis" in window) {',
'          window.speechSynthesis.cancel();',
'        }',
'      } catch {}',
'    };',
'  }, []);',
'',
'  function toggleReading() {',
'    setReadingMode(v => !v);',
'  }',
'',
'  function bumpFont(delta: number) {',
'    setFontScale(v => clamp(Number((v + delta).toFixed(2)), 0.9, 1.35));',
'  }',
'',
'  function reset() {',
'    setReadingMode(false);',
'    setFontScale(1);',
'  }',
'',
'  function toggleSpeak() {',
'    try {',
'      if (typeof window === "undefined" || !("speechSynthesis" in window)) return;',
'      const synth = window.speechSynthesis;',
'      if (speaking) {',
'        synth.cancel();',
'        setSpeaking(false);',
'        return;',
'      }',
'      const text = getMainText();',
'      if (!text) return;',
'      const u = new SpeechSynthesisUtterance(text);',
'      u.rate = 1;',
'      u.pitch = 1;',
'      u.onend = () => setSpeaking(false);',
'      u.onerror = () => setSpeaking(false);',
'      setSpeaking(true);',
'      synth.cancel();',
'      synth.speak(u);',
'    } catch {',
'      setSpeaking(false);',
'    }',
'  }',
'',
'  return (',
'    <section className="card p-4 flex flex-wrap gap-2 items-center" aria-label="Controles de leitura">', 
'      <button',
'        type="button"',
'        className="card px-3 py-2 hover:bg-white/10 transition"',
'        aria-pressed={readingMode}',
'        onClick={toggleReading}',
'        title="Alternar modo leitura"',
'      >',
'        {readingMode ? "Modo leitura: ON" : "Modo leitura: OFF"}',
'      </button>',
'',
'      <button',
'        type="button"',
'        className="card px-3 py-2 hover:bg-white/10 transition"',
'        onClick={() => bumpFont(-0.05)}',
'        title="Diminuir fonte"',
'      >',
'        A-',
'      </button>',
'      <button',
'        type="button"',
'        className="card px-3 py-2 hover:bg-white/10 transition"',
'        onClick={() => bumpFont(0.05)}',
'        title="Aumentar fonte"',
'      >',
'        A+',
'      </button>',
'',
'      <button',
'        type="button"',
'        className="card px-3 py-2 hover:bg-white/10 transition"',
'        aria-pressed={speaking}',
'        onClick={toggleSpeak}',
'        title="Ouvir o conteúdo"',
'      >',
'        {speaking ? "Parar" : "Ouvir"}',
'      </button>',
'',
'      <button',
'        type="button"',
'        className="card px-3 py-2 hover:bg-white/10 transition"',
'        onClick={reset}',
'        title="Resetar preferências"',
'      >',
'        Reset',
'      </button>',
'    </section>',
'  );',
'}',
''
)

WriteUtf8NoBom $readingPath ($lines -join "`n")
WL "[OK] wrote: ReadingControls.tsx (SSR-safe; prefs via useEffect)"

# -------------------------
# REPORT
# -------------------------
$rep = NewReportLocal $repo "cv-hotfix-readingcontrols-hydration-v0_18h.md" @(
("# Hotfix — ReadingControls hydration v0.18h — " + (Get-Date -Format "yyyy-MM-dd HH:mm")),
"",
"## Problema",
"- Hydration mismatch em aria-pressed (SSR false vs client true).",
"",
"## Causa",
"- Preferência estava sendo aplicada antes do hydrate (localStorage/window no render ou no initializer do state).",
"",
"## Mudança",
"- ReadingControls agora inicia com defaults estáveis e carrega preferências em useEffect.",
"- Persistência e aplicação em dataset/CSS vars só depois do mount.",
"",
"## Resultado esperado",
"- Sem warning de hydration ao abrir qualquer /c/[slug]."
)
WL ("[OK] Report: " + $rep)

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
WL "[OK] Hotfix ReadingControls hydration aplicado."