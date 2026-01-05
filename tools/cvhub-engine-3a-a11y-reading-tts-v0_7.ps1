param(
  [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function WL([string]$s) { Write-Host $s }
function TestP([string]$p) { return (Test-Path -LiteralPath $p) }

function EnsureDir([string]$p) {
  if (-not (TestP $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

function WriteUtf8NoBom([string]$p, [string]$content) {
  $parent = Split-Path -Parent $p
  if ($parent) { EnsureDir $parent }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($p, $content, $enc)
}

function BackupFile([string]$p) {
  if (TestP $p) {
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

function ResolveRepoHere() {
  $here = (Get-Location).Path
  if (TestP (Join-Path $here "package.json")) { return $here }
  throw ("[STOP] Rode na raiz do repo (onde tem package.json). Atual: " + $here)
}

function AddImportAfterLastImport([string]$raw, [string]$importLine) {
  if ($raw -like ("*" + $importLine + "*")) { return $raw }

  $lines = $raw -split "`r?`n"
  $lastImport = -1
  for ($i=0; $i -lt $lines.Length; $i++) {
    $t = $lines[$i].TrimStart()
    if ($t.StartsWith("import ")) { $lastImport = $i }
  }

  $out = New-Object System.Collections.Generic.List[string]
  for ($i=0; $i -lt $lines.Length; $i++) {
    [void]$out.Add($lines[$i])
    if ($i -eq $lastImport) { [void]$out.Add($importLine) }
  }
  if ($lastImport -lt 0) {
    $out2 = New-Object System.Collections.Generic.List[string]
    [void]$out2.Add($importLine)
    [void]$out2.Add("")
    foreach ($ln in $lines) { [void]$out2.Add($ln) }
    return ($out2 -join "`n")
  }
  return ($out -join "`n")
}

function InsertAfterFirstLineMatch([string]$raw, [string]$contains, [string]$insertLine) {
  if ($raw -like ("*" + $insertLine + "*")) { return $raw }
  $lines = $raw -split "`r?`n"
  $idx = -1
  for ($i=0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -like ("*" + $contains + "*")) { $idx = $i; break }
  }
  if ($idx -lt 0) { return $raw }

  $out = New-Object System.Collections.Generic.List[string]
  for ($i=0; $i -lt $lines.Length; $i++) {
    [void]$out.Add($lines[$i])
    if ($i -eq $idx) { [void]$out.Add($insertLine) }
  }
  return ($out -join "`n")
}

function FindLayoutFile([string]$repo) {
  $appDir = Join-Path $repo "src\app"
  if (-not (TestP $appDir)) { return $null }
  $cands = @(Get-ChildItem -LiteralPath $appDir -Recurse -File -Filter "layout.tsx" -ErrorAction SilentlyContinue)
  foreach ($f in $cands) {
    $raw = Get-Content -LiteralPath $f.FullName -Raw
    if ($raw -like "*<html*" -and $raw -like "*<body*") { return $f.FullName }
  }
  if ($cands.Count -gt 0) { return $cands[0].FullName }
  return $null
}

function FindGlobalsCss([string]$repo) {
  $appDir = Join-Path $repo "src\app"
  if (-not (TestP $appDir)) { return $null }
  $cands = @(Get-ChildItem -LiteralPath $appDir -Recurse -File -Filter "globals.css" -ErrorAction SilentlyContinue)
  if ($cands.Count -gt 0) { return $cands[0].FullName }
  return $null
}

function EnsureSkipLinkInLayout([string]$layoutPath) {
  $raw = Get-Content -LiteralPath $layoutPath -Raw
  if ($raw -like "*href=""#cv-main""*") { return $raw }

  $lines = $raw -split "`r?`n"
  $out = New-Object System.Collections.Generic.List[string]
  $inserted = $false

  for ($i=0; $i -lt $lines.Length; $i++) {
    $ln = $lines[$i]
    [void]$out.Add($ln)

    if (-not $inserted -and $ln -like "*<body*>" ) {
      [void]$out.Add('      <a href="#cv-main" className="sr-only focus:not-sr-only fixed top-3 left-3 z-50 rounded-xl bg-black px-4 py-2 text-white focus:outline-none focus:ring-2 focus:ring-white/50">Pular para o conteúdo</a>')
      $inserted = $true
    }
  }

  return ($out -join "`n")
}

function PatchMainTagsAndControls([string]$pagePath) {
  $raw = Get-Content -LiteralPath $pagePath -Raw
  $orig = $raw

  # Add import
  if (-not ($raw -like "*from ""@/components/ReadingControls""*")) {
    $raw = AddImportAfterLastImport $raw 'import ReadingControls from "@/components/ReadingControls";'
  }

  # Insert <ReadingControls /> after <CadernoHeader ... />
  if (-not ($raw -like "*<ReadingControls*")) {
    $raw = InsertAfterFirstLineMatch $raw "<CadernoHeader" "      <ReadingControls />"
  }

  # Ensure <main id="cv-main" tabIndex={-1} ...>
  if (-not ($raw -like "*id=""cv-main""*")) {
    $rx = New-Object System.Text.RegularExpressions.Regex("<main\s+(?![^>]*\bid=)", [System.Text.RegularExpressions.RegexOptions]::None)
    $raw = $rx.Replace($raw, "<main id=""cv-main"" tabIndex={-1} ", 1)
  }

  # Ensure cv-reading class on main
  $m = [regex]::Match($raw, "<main[^>]*className=""([^""]*)""")
  if ($m.Success) {
    $cls = $m.Groups[1].Value
    if (-not ([regex]::IsMatch($cls, "\bcv-reading\b"))) {
      $raw = $raw.Replace(('className="' + $cls + '"'), ('className="cv-reading ' + $cls + '"'))
    }
  }

  # Replace Recibo -> Registro (word boundary) inside this file
  $raw = [regex]::Replace($raw, "\bRecibo\b", "Registro")
  $raw = [regex]::Replace($raw, "\brecibo\b", "registro")

  if ($raw -ne $orig) { return $raw }
  return $orig
}

# -------------------------
# DIAG
# -------------------------
$repo = ResolveRepoHere
$npmExe = ResolveExe "npm.cmd"
WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)

$componentsDir = Join-Path $repo "src\components"
$pagesScope = Join-Path $repo "src\app\c\[slug]"
EnsureDir $componentsDir

# -------------------------
# PATCH A — ReadingControls.tsx (client)
# -------------------------
$readingPath = Join-Path $componentsDir "ReadingControls.tsx"
BackupFile $readingPath

$readingLines = @(
'"use client";',
'',
'import { useEffect, useMemo, useState } from "react";',
'',
'type Prefs = { reading: boolean; contrast: boolean };',
'',
'function readPrefs(): Prefs {',
'  try {',
'    const raw = localStorage.getItem("cv:ui:prefs:v1");',
'    if (!raw) return { reading: false, contrast: false };',
'    const obj = JSON.parse(raw) as Partial<Prefs>;',
'    return { reading: !!obj.reading, contrast: !!obj.contrast };',
'  } catch {',
'    return { reading: false, contrast: false };',
'  }',
'}',
'',
'function writePrefs(p: Prefs) {',
'  try { localStorage.setItem("cv:ui:prefs:v1", JSON.stringify(p)); } catch {}',
'}',
'',
'function speakMain() {',
'  try {',
'    const anyWin = window as unknown as { speechSynthesis?: SpeechSynthesis };',
'    if (!anyWin.speechSynthesis) return;',
'    anyWin.speechSynthesis.cancel();',
'    const el = document.getElementById("cv-main");',
'    const text = (el?.innerText || "").replace(/\\s+/g, " ").trim();',
'    if (!text) return;',
'    const u = new SpeechSynthesisUtterance(text);',
'    u.lang = "pt-BR";',
'    anyWin.speechSynthesis.speak(u);',
'  } catch {}',
'}',
'',
'function stopSpeak() {',
'  try {',
'    const anyWin = window as unknown as { speechSynthesis?: SpeechSynthesis };',
'    if (!anyWin.speechSynthesis) return;',
'    anyWin.speechSynthesis.cancel();',
'  } catch {}',
'}',
'',
'export default function ReadingControls() {',
'  const init = useMemo(() => readPrefs(), []);',
'  const [reading, setReading] = useState<boolean>(init.reading);',
'  const [contrast, setContrast] = useState<boolean>(init.contrast);',
'',
'  useEffect(() => {',
'    const root = document.documentElement;',
'    root.dataset.reading = reading ? "1" : "0";',
'    root.dataset.contrast = contrast ? "1" : "0";',
'    writePrefs({ reading, contrast });',
'  }, [reading, contrast]);',
'',
'  return (',
'    <section className="card p-4 flex flex-wrap items-center gap-2" aria-label="Controles de leitura e acessibilidade">', 
'      <button',
'        type="button"',
'        className="card px-3 py-2 hover:bg-white/10 transition"',
'        aria-pressed={reading}',
'        onClick={() => setReading((v) => !v)}',
'      >',
'        <span className="accent">Modo leitura</span>',
'      </button>',
'',
'      <button',
'        type="button"',
'        className="card px-3 py-2 hover:bg-white/10 transition"',
'        aria-pressed={contrast}',
'        onClick={() => setContrast((v) => !v)}',
'      >',
'        <span className="accent">Alto contraste</span>',
'      </button>',
'',
'      <div className="ml-auto flex flex-wrap gap-2">',
'        <button type="button" className="card px-3 py-2 hover:bg-white/10 transition" onClick={speakMain}>',
'          <span className="accent">Ouvir</span>',
'        </button>',
'        <button type="button" className="card px-3 py-2 hover:bg-white/10 transition" onClick={stopSpeak}>',
'          Parar',
'        </button>',
'      </div>',
'',
'      <div className="w-full text-xs muted mt-2">',
'        Dica: use Tab para navegar. O link "Pular para o conteúdo" aparece ao focar no topo.',
'      </div>',
'    </section>',
'  );',
'}'
)

WriteUtf8NoBom $readingPath ($readingLines -join "`n")
WL ("[OK] wrote: " + $readingPath)

# -------------------------
# PATCH B — globals.css (cv-reading + contrast)
# -------------------------
$globals = FindGlobalsCss $repo
if ($globals) {
  BackupFile $globals
  $g = Get-Content -LiteralPath $globals -Raw
  if (-not ($g -like "*CV-READING-MODE*")) {
    $append = @(
"",
"/* CV-READING-MODE (Engine-3A) */",
"html[data-reading=""1""] .cv-reading {",
"  font-size: 1.08rem;",
"  line-height: 1.75;",
"}",
"",
"html[data-contrast=""1""] {",
"  filter: contrast(1.08);",
"}",
""
    ) -join "`n"
    $g = $g + $append
    WriteUtf8NoBom $globals $g
    WL ("[OK] patched: " + $globals)
  } else {
    WL ("[OK] globals.css já tem bloco CV-READING-MODE: " + $globals)
  }
} else {
  WL "[WARN] Não achei globals.css. (Sem problema: controles funcionam, só sem CSS extra.)"
}

# -------------------------
# PATCH C — layout skip link
# -------------------------
$layout = FindLayoutFile $repo
if ($layout) {
  BackupFile $layout
  $lr = EnsureSkipLinkInLayout $layout
  WriteUtf8NoBom $layout $lr
  WL ("[OK] patched: " + $layout)
} else {
  WL "[WARN] Não achei layout.tsx com <html>/<body>. Pulei skip link."
}

# -------------------------
# PATCH D — pages: main id + controls + registro wording
# -------------------------
if (-not (TestP $pagesScope)) {
  WL ("[WARN] scope não existe: " + $pagesScope)
} else {
  $pages = @(Get-ChildItem -LiteralPath $pagesScope -Recurse -File -Filter "page.tsx" -ErrorAction SilentlyContinue)
  WL ("[DIAG] pages em /c/[slug]: " + $pages.Count)

  $patchedCount = 0
  foreach ($p in $pages) {
    $before = Get-Content -LiteralPath $p.FullName -Raw
    $after = PatchMainTagsAndControls $p.FullName
    if ($after -ne $before) {
      BackupFile $p.FullName
      WriteUtf8NoBom $p.FullName $after
      $patchedCount++
      WL ("[OK] patched: " + $p.FullName)
    }
  }
  WL ("[OK] pages patched: " + $patchedCount)
}

# Also patch components for Recibo -> Registro (safe word boundary)
$compFiles = @(Get-ChildItem -LiteralPath $componentsDir -Recurse -File -Filter "*.tsx" -ErrorAction SilentlyContinue)
$rep2 = 0
foreach ($f in $compFiles) {
  $raw = Get-Content -LiteralPath $f.FullName -Raw
  $new = $raw
  $new = [regex]::Replace($new, "\bRecibo\b", "Registro")
  $new = [regex]::Replace($new, "\brecibo\b", "registro")
  if ($new -ne $raw) {
    BackupFile $f.FullName
    WriteUtf8NoBom $f.FullName $new
    $rep2++
    WL ("[OK] wording: " + $f.FullName)
  }
}
WL ("[OK] components wording updated: " + $rep2)

# -------------------------
# REPORT
# -------------------------
$repDir = Join-Path $repo "reports"
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repDir "cv-engine-3a-a11y-reading-tts-v0_7.md"

$reportLines = @(
("# CV-Engine-3A — A11y + Modo Leitura + TTS — " + $now),
"",
"## O que entrou",
"- Skip link no layout (pular para #cv-main).",
"- main das paginas ganhou id=cv-main + tabIndex=-1 + classe cv-reading.",
"- Novo componente ReadingControls (modo leitura, alto contraste, ouvir/parar).",
"- Padronizacao de linguagem: Registro (nao Recibo).",
"",
"## Verificar manual",
"- Tab: o link de pular aparece e leva ao conteudo.",
"- Modo leitura altera tipografia/ritmo (se globals.css existir).",
"- Ouvir/Parar funciona em navegadores com Web Speech API."
)

WriteUtf8NoBom $reportPath ($reportLines -join "`n")
WL ("[OK] Report: " + $reportPath)

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
WL "[OK] Engine-3A aplicado."
WL "[NEXT] Abra: /c/poluicao-vr (e qualquer subpagina). Teste Tab, Modo Leitura e Ouvir."