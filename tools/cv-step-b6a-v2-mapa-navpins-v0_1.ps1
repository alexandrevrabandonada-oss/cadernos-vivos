param(
  [switch]$SkipVerify
)

$ErrorActionPreference = "Stop"

# -----------------------------
# Bootstrap
# -----------------------------
$root = Resolve-Path (Join-Path $PSScriptRoot "..") | Select-Object -ExpandProperty Path
$bootstrap = Join-Path $root "tools\_bootstrap.ps1"
if (!(Test-Path $bootstrap)) { throw "[STOP] tools\_bootstrap.ps1 nao encontrado em: $bootstrap" }
. $bootstrap

function NowStamp() {
  return (Get-Date -Format "yyyyMMdd-HHmmss")
}

function ReadUtf8Raw([string]$p) {
  if (!(Test-Path $p)) { return $null }
  return Get-Content -Raw -LiteralPath $p
}

function WriteLinesUtf8NoBom([string]$p, [string[]]$lines) {
  $text = [string]::Join([Environment]::NewLine, $lines) + [Environment]::NewLine
  WriteUtf8NoBom $p $text
}

function InsertAfterLastImport([string[]]$lines, [string]$importLine) {
  $lastIdx = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $ln = $lines[$i]
    if ($ln.TrimStart().StartsWith("import ")) { $lastIdx = $i }
  }
  if ($lastIdx -ge 0) {
    $before = @()
    if ($lastIdx -gt 0) { $before = $lines[0..$lastIdx] } else { $before = @($lines[0]) }
    $after = @()
    if ($lastIdx + 1 -lt $lines.Count) { $after = $lines[($lastIdx+1)..($lines.Count-1)] }
    return @($before + @($importLine) + $after)
  }
  return @(@($importLine) + $lines)
}

function ReplaceFirstRegex([string]$text, [string]$pattern, [string]$replacement) {
  $m = [regex]::Match($text, $pattern)
  if (!$m.Success) { return $text }
  return ($text.Substring(0, $m.Index) + [regex]::Replace($m.Value, $pattern, $replacement, 1) + $text.Substring($m.Index + $m.Length))
}

function RunVerifyMaybe([string]$rootPath) {
  $verify = Join-Path $rootPath "tools\cv-verify.ps1"
  if (Test-Path $verify) {
    Write-Host ("[RUN] " + $verify)
    pwsh -NoProfile -ExecutionPolicy Bypass -File $verify
    return
  }
  Write-Host "[RUN] npm run lint"
  npm run lint
  Write-Host "[RUN] npm run build"
  npm run build
}

# -----------------------------
# Paths
# -----------------------------
$ts = NowStamp
$reportDir = Join-Path $root "reports"
EnsureDir $reportDir

$globalsCss = Join-Path $root "src\app\globals.css"
$interactive = Join-Path $root "src\components\v2\MapaV2Interactive.tsx"
$pinsClient = Join-Path $root "src\components\v2\Cv2MapNavPinsClient.tsx"

$backups = New-Object System.Collections.Generic.List[string]
$actions = New-Object System.Collections.Generic.List[string]

Write-Host "== CV — Step B6a: V2 Mapa nav pins overlay v0_1 == $ts"
Write-Host ("[DIAG] Root: " + $root)

# -----------------------------
# DIAG
# -----------------------------
if (!(Test-Path $globalsCss)) { throw "[STOP] globals.css nao encontrado: $globalsCss" }
if (!(Test-Path $interactive)) { throw "[STOP] MapaV2Interactive.tsx nao encontrado: $interactive" }

# -----------------------------
# PATCH 1: Create Cv2MapNavPinsClient.tsx
# -----------------------------
if (Test-Path $pinsClient) {
  BackupFile $pinsClient ("$ts-Cv2MapNavPinsClient.tsx.bak")
  $backups.Add(("$ts-Cv2MapNavPinsClient.tsx.bak"))
}

$pinLines = @(
  "'use client';",
  "",
  "import * as React from ""react"";",
  "import { usePathname } from ""next/navigation"";",
  "",
  "type NavPin = {",
  "  id: string;",
  "  label: string;",
  "  x: number; // percent",
  "  y: number; // percent",
  "  href: string;",
  "  hint?: string;",
  "};",
  "",
  "function slugFromPath(pathname: string): string | undefined {",
  "  const m = pathname.match(/^\/c\/([^\/]+)\/v2\/mapa(?:\/)?/);",
  "  if (!m) return undefined;",
  "  try {",
  "    return decodeURIComponent(m[1]);",
  "  } catch {",
  "    return m[1];",
  "  }",
  "}",
  "",
  "function buildPins(slug: string): NavPin[] {",
  "  const base = ""/c/"" + encodeURIComponent(slug) + ""/v2"";",
  "  return [",
  "    { id: ""hub"", label: ""Hub"", x: 50, y: 28, href: base, hint: ""Visao geral"" },",
  "    { id: ""debate"", label: ""Debate"", x: 18, y: 44, href: base + ""/debate"" },",
  "    { id: ""linha"", label: ""Linha"", x: 50, y: 56, href: base + ""/linha"" },",
  "    { id: ""linha-do-tempo"", label: ""Linha do tempo"", x: 82, y: 44, href: base + ""/linha-do-tempo"" },",
  "    { id: ""provas"", label: ""Provas"", x: 26, y: 74, href: base + ""/provas"" },",
  "    { id: ""trilhas"", label: ""Trilhas"", x: 74, y: 74, href: base + ""/trilhas"" }",
  "  ];",
  "}",
  "",
  "export function Cv2MapNavPinsClient(): React.JSX.Element | null {",
  "  const pathname = usePathname();",
  "  const slug = pathname ? slugFromPath(pathname) : undefined;",
  "  const pins = React.useMemo(() => (slug ? buildPins(slug) : []), [slug]);",
  "",
  "  if (!slug || pins.length === 0) return null;",
  "",
  "  return (",
  "    <div className=""cv2-map-navpins"" aria-label=""Navegacao do mapa"">",
  "      {pins.map((p) => (",
  "        <a",
  "          key={p.id}",
  "          className=""cv2-map-navpin""",
  "          href={p.href}",
  "          style={{ left: p.x + ""%"", top: p.y + ""%"" }}",
  "          aria-label={p.label}",
  "          title={p.hint ?? p.label}",
  "        >",
  "          <span className=""cv2-map-navpin__dot"" aria-hidden=""true"" />",
  "          <span className=""cv2-map-navpin__label"">{p.label}</span>",
  "        </a>",
  "      ))}",
  "    </div>",
  "  );",
  "}"
)

EnsureDir (Split-Path -Parent $pinsClient)
WriteLinesUtf8NoBom $pinsClient $pinLines
$actions.Add("Created/updated src/components/v2/Cv2MapNavPinsClient.tsx")

# -----------------------------
# PATCH 2: Inject into MapaV2Interactive.tsx (wrap MapaCanvasV2 in stage + add pins)
# -----------------------------
BackupFile $interactive ("$ts-MapaV2Interactive.tsx.bak")
$backups.Add(("$ts-MapaV2Interactive.tsx.bak"))

$raw = Get-Content -LiteralPath $interactive
$lines = @($raw)

$needImport = $true
foreach ($ln in $lines) {
  if ($ln -match "Cv2MapNavPinsClient") { $needImport = $false; break }
}

if ($needImport) {
  $lines = InsertAfterLastImport $lines 'import { Cv2MapNavPinsClient } from "./Cv2MapNavPinsClient";'
  $actions.Add("MapaV2Interactive.tsx: added import for Cv2MapNavPinsClient")
}

# If already wrapped, skip wrapping
$alreadyStage = $false
foreach ($ln in $lines) {
  if ($ln -match 'className=\x22cv2-map-stage\x22') { $alreadyStage = $true; break }
}

if (!$alreadyStage) {
  $idxStart = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match "<MapaCanvasV2") { $idxStart = $i; break }
  }

  if ($idxStart -lt 0) {
    Write-Host "[WARN] Nao achei <MapaCanvasV2 no MapaV2Interactive.tsx — nao injetei stage/pins."
    $actions.Add("MapaV2Interactive.tsx: WARNING no <MapaCanvasV2 anchor found; skipped stage injection")
  } else {
    $indent = ""
    if ($lines[$idxStart] -match "^(\s*)") { $indent = $matches[1] }

    # Find end of the MapaCanvasV2 tag block
    $idxEnd = $idxStart
    for ($j = $idxStart; $j -lt $lines.Count; $j++) {
      $ln = $lines[$j]
      if ($ln -match "</MapaCanvasV2>") { $idxEnd = $j; break }
      if (($ln -match "/>") -and ($ln -match "MapaCanvasV2")) { $idxEnd = $j; break }
      # Multi-line self-closing: stop at a line that has "/>" after start
      if (($j -gt $idxStart) -and ($ln -match "/>")) { $idxEnd = $j; break }
    }

    $before = @()
    if ($idxStart -gt 0) { $before = $lines[0..($idxStart-1)] }

    $canvasBlock = $lines[$idxStart..$idxEnd]

    $after = @()
    if ($idxEnd + 1 -lt $lines.Count) { $after = $lines[($idxEnd+1)..($lines.Count-1)] }

    $wrapOpen = $indent + '<div className="cv2-map-stage">'
    $wrapPin  = $indent + '  <Cv2MapNavPinsClient />'
    $wrapClose= $indent + '</div>'

    $lines = @($before + @($wrapOpen) + $canvasBlock + @($wrapPin) + @($wrapClose) + $after)
    $actions.Add("MapaV2Interactive.tsx: wrapped MapaCanvasV2 with .cv2-map-stage and added <Cv2MapNavPinsClient />")
  }
}

WriteLinesUtf8NoBom $interactive $lines

# -----------------------------
# PATCH 3: globals.css add styles (scoped to .cv-v2)
# -----------------------------
BackupFile $globalsCss ("$ts-globals.css.bak")
$backups.Add(("$ts-globals.css.bak"))

$cssRaw = ReadUtf8Raw $globalsCss
if ($null -eq $cssRaw) { throw "[STOP] Falha ao ler globals.css" }

$marker = "CV2 Map NavPins (B6a)"
if ($cssRaw -match [regex]::Escape($marker)) {
  $actions.Add("globals.css: marker already present; skipped")
} else {
  $cssAppend = @(
    "",
    "/* CV2 Map NavPins (B6a) */",
    ".cv-v2 .cv2-map-stage {",
    "  position: relative;",
    "}",
    ".cv-v2 .cv2-map-navpins {",
    "  position: absolute;",
    "  inset: 0;",
    "  pointer-events: none;",
    "}",
    ".cv-v2 .cv2-map-navpin {",
    "  position: absolute;",
    "  transform: translate(-50%, -50%);",
    "  display: inline-flex;",
    "  align-items: center;",
    "  gap: 8px;",
    "  padding: 6px 10px;",
    "  border-radius: 999px;",
    "  border: 1px solid var(--cv2-line, rgba(255,255,255,0.12));",
    "  background: var(--cv2-surface-2, rgba(0,0,0,0.55));",
    "  color: var(--cv2-text, rgba(255,255,255,0.92));",
    "  text-decoration: none;",
    "  font-size: 12px;",
    "  letter-spacing: 0.02em;",
    "  pointer-events: auto;",
    "  backdrop-filter: blur(6px);",
    "}",
    ".cv-v2 .cv2-map-navpin:hover {",
    "  border-color: var(--cv2-accent, rgba(255,230,0,0.65));",
    "}",
    ".cv-v2 .cv2-map-navpin:focus-visible {",
    "  outline: 2px solid var(--cv2-accent, rgba(255,230,0,0.85));",
    "  outline-offset: 2px;",
    "}",
    ".cv-v2 .cv2-map-navpin__dot {",
    "  width: 10px;",
    "  height: 10px;",
    "  border-radius: 999px;",
    "  background: var(--cv2-accent, #ffe600);",
    "  box-shadow: 0 0 0 3px rgba(0,0,0,0.25);",
    "}",
    ".cv-v2 .cv2-map-navpin__label {",
    "  white-space: nowrap;",
    "}"
  )
  $cssNew = $cssRaw + [string]::Join([Environment]::NewLine, $cssAppend) + [Environment]::NewLine
  WriteUtf8NoBom $globalsCss $cssNew
  $actions.Add("globals.css: appended CV2 nav pins styles")
}

# -----------------------------
# VERIFY
# -----------------------------
$verifyOk = $true
$verifyMsg = ""
if (!$SkipVerify) {
  try {
    RunVerifyMaybe $root
    $verifyMsg = "[OK] verify OK"
  } catch {
    $verifyOk = $false
    $verifyMsg = "[FAIL] verify failed: " + $_.Exception.Message
    Write-Host $verifyMsg
  }
} else {
  $verifyMsg = "[SKIP] verify skipped"
}

# -----------------------------
# REPORT
# -----------------------------
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Step B6a: V2 Mapa nav pins overlay (v0_1)")
$rep.Add("")
$rep.Add("- when: $ts")
$rep.Add("- repo: $root")
$rep.Add("")
$rep.Add("## ACTIONS")
foreach ($a in $actions) { $rep.Add("- " + $a) }
$rep.Add("")
$rep.Add("## BACKUPS")
foreach ($b in $backups) { $rep.Add("- " + $b) }
$rep.Add("")
$rep.Add("## VERIFY")
$rep.Add("- " + $verifyMsg)
$rep.Add("")
$rep.Add("## NOTES")
$rep.Add("- Pins sao um overlay simples (percentual) para navegacao interna do V2.")
$rep.Add("- Se o arquivo MapaV2Interactive.tsx nao tiver <MapaCanvasV2, o tijolo apenas cria o componente e o CSS (sem injetar).")

$reportPath = Join-Path $reportDir ("cv-step-b6a-v2-mapa-navpins-" + $ts + ".md")
WriteLinesUtf8NoBom $reportPath ($rep.ToArray())
Write-Host ("[REPORT] " + $reportPath)

if (!$verifyOk) { throw "[STOP] verify falhou. Veja o report e o output acima." }

Write-Host "[OK] B6a aplicado com sucesso."