$ErrorActionPreference = "Stop"

function _NowTag { Get-Date -Format "yyyyMMdd-HHmmss" }

# ------------------------------------------------------------
# Bootstrap + fallbacks
# ------------------------------------------------------------
$boot = Join-Path $PSScriptRoot "_bootstrap.ps1"
if (Test-Path -LiteralPath $boot) { . $boot }

if (-not (Get-Command EnsureDir -ErrorAction SilentlyContinue)) {
  function EnsureDir([string]$p) { if ($p -and -not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
}
if (-not (Get-Command WriteUtf8NoBom -ErrorAction SilentlyContinue)) {
  function WriteUtf8NoBom([string]$p, [string]$t) {
    EnsureDir (Split-Path -Parent $p)
    [IO.File]::WriteAllText($p, $t, [Text.UTF8Encoding]::new($false))
  }
}
if (-not (Get-Command BackupFile -ErrorAction SilentlyContinue)) {
  function BackupFile([string]$p) {
    if (-not (Test-Path -LiteralPath $p)) { return $null }
    $bkDir = Join-Path $PSScriptRoot "_patch_backup"
    EnsureDir $bkDir
    $ts = Get-Date -Format "yyyyMMdd-HHmmss"
    $leaf = Split-Path -Leaf $p
    $dst = Join-Path $bkDir ($ts + "-" + $leaf + ".bak")
    Copy-Item -LiteralPath $p -Destination $dst -Force
    return $dst
  }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$stamp = _NowTag
Write-Host ("== CV B6V — V2 Hub Core Nodes + Map-first CTA v0_2 == " + $stamp)
Write-Host ("[DIAG] Repo: " + $repoRoot)

# ------------------------------------------------------------
# Targets
# ------------------------------------------------------------
$hubRel = "src/app/c/[slug]/v2/page.tsx"
$hubAbs = Join-Path $repoRoot $hubRel
if (-not (Test-Path -LiteralPath $hubAbs)) { throw ("[STOP] não achei: " + $hubAbs) }

$coreRel = "src/components/v2/Cv2CoreNodes.tsx"
$coreAbs = Join-Path $repoRoot $coreRel

$globalsRel = "src/app/globals.css"
$globalsAbs = Join-Path $repoRoot $globalsRel

# ------------------------------------------------------------
# 1) Write component Cv2CoreNodes.tsx
# ------------------------------------------------------------
$componentText = @"
import Link from "next/link";

type CoreNode = {
  key: string;
  href: string;
  label: string;
  desc: string;
  badge?: string;
  primary?: boolean;
};

function buildNodes(slug: string): CoreNode[] {
  const base = "/c/" + slug + "/v2";
  return [
    { key: "mapa", href: base + "/mapa", label: "Mapa", desc: "Começar por aqui: visão geral do universo.", badge: "Eixo", primary: true },
    { key: "linha", href: base + "/linha", label: "Linha", desc: "Fatos, tópicos e entradas conectadas.", badge: "Rastro" },
    { key: "linha-do-tempo", href: base + "/linha-do-tempo", label: "Linha do tempo", desc: "Cronologia e memória em camadas." },
    { key: "provas", href: base + "/provas", label: "Provas", desc: "Evidências, fontes e checagens." },
    { key: "trilhas", href: base + "/trilhas", label: "Trilhas", desc: "Percursos guiados: do básico ao profundo.", badge: "Guia" },
    { key: "debate", href: base + "/debate", label: "Debate", desc: "Discussão e sínteses do coletivo." },
  ];
}

export default function Cv2CoreNodes(props: { slug: string; title?: string }) {
  const slug = props.slug;
  const title = props.title;
  const nodes = buildNodes(slug);

  return (
    <section className="cv2-coreWrap" aria-label="Núcleo do universo">
      <div className="cv2-coreHead">
        <div className="cv2-coreTitle">Núcleo do universo</div>
        <div className="cv2-coreSub">{title ? title : slug}</div>
      </div>

      <div className="cv2-coreGrid">
        {nodes.map((n) => (
          <Link
            key={n.key}
            href={n.href}
            prefetch={false}
            className={n.primary ? "cv2-coreCard cv2-coreCard--primary" : "cv2-coreCard"}
          >
            <div className="cv2-coreCardTop">
              <div className="cv2-coreCardLabel">{n.label}</div>
              {n.badge ? <div className="cv2-coreBadge">{n.badge}</div> : null}
            </div>
            <div className="cv2-coreCardDesc">{n.desc}</div>
            {n.primary ? <div className="cv2-coreCta">Começar pelo Mapa →</div> : <div className="cv2-coreCta">Abrir →</div>}
          </Link>
        ))}
      </div>
    </section>
  );
}
"@

if (-not (Test-Path -LiteralPath $coreAbs)) {
  WriteUtf8NoBom $coreAbs $componentText
  Write-Host ("[PATCH] wrote -> " + $coreAbs)
} else {
  $existing = Get-Content -Raw -LiteralPath $coreAbs
  if ($existing -notmatch "cv2-coreWrap" -or $existing -notmatch "Núcleo do universo") {
    $bk = BackupFile $coreAbs
    if ($bk) { Write-Host ("[BK] " + $bk) }
    WriteUtf8NoBom $coreAbs $componentText
    Write-Host ("[PATCH] rewrote -> " + $coreAbs)
  } else {
    Write-Host "[SKIP] Cv2CoreNodes.tsx já existe (parece ok)."
  }
}

# ------------------------------------------------------------
# 2) Append CSS (globals.css)
# ------------------------------------------------------------
$cssBlock = @(
'',
'/* CV2 CORE NODES v0_1 (Concreto Zen) */',
'.cv2-coreWrap {',
'  margin-top: 14px;',
'  margin-bottom: 12px;',
'  padding: 12px;',
'  border: 1px solid rgba(255,255,255,0.10);',
'  border-radius: 14px;',
'  background: rgba(0,0,0,0.22);',
'}',
'.cv2-coreHead {',
'  display: flex;',
'  align-items: baseline;',
'  justify-content: space-between;',
'  gap: 12px;',
'  margin-bottom: 10px;',
'}',
'.cv2-coreTitle {',
'  font-size: 12px;',
'  letter-spacing: 0.12em;',
'  text-transform: uppercase;',
'  opacity: 0.9;',
'}',
'.cv2-coreSub {',
'  font-size: 12px;',
'  opacity: 0.65;',
'  overflow: hidden;',
'  text-overflow: ellipsis;',
'  white-space: nowrap;',
'}',
'.cv2-coreGrid {',
'  display: grid;',
'  grid-template-columns: repeat(3, minmax(0, 1fr));',
'  gap: 10px;',
'}',
"@media (max-width: 900px) {",
'  .cv2-coreGrid { grid-template-columns: repeat(2, minmax(0, 1fr)); }',
'}',
"@media (max-width: 520px) {",
'  .cv2-coreGrid { grid-template-columns: 1fr; }',
'}',
'.cv2-coreCard {',
'  display: block;',
'  padding: 12px;',
'  border-radius: 12px;',
'  border: 1px solid rgba(255,255,255,0.10);',
'  background: rgba(0,0,0,0.14);',
'  text-decoration: none;',
'  color: inherit;',
'  transition: transform 120ms ease, border-color 120ms ease, background 120ms ease;',
'}',
'.cv2-coreCard:hover {',
'  transform: translateY(-1px);',
'  border-color: rgba(255,255,255,0.18);',
'  background: rgba(0,0,0,0.22);',
'}',
'.cv2-coreCardTop {',
'  display: flex;',
'  align-items: center;',
'  justify-content: space-between;',
'  gap: 10px;',
'  margin-bottom: 6px;',
'}',
'.cv2-coreCardLabel {',
'  font-size: 16px;',
'  font-weight: 650;',
'}',
'.cv2-coreCardDesc {',
'  font-size: 13px;',
'  opacity: 0.82;',
'  line-height: 1.35;',
'}',
'.cv2-coreCta {',
'  margin-top: 10px;',
'  font-size: 12px;',
'  opacity: 0.85;',
'}',
'.cv2-coreBadge {',
'  font-size: 11px;',
'  padding: 3px 8px;',
'  border-radius: 999px;',
'  border: 1px solid rgba(255,255,255,0.14);',
'  opacity: 0.9;',
'}',
'.cv2-coreCard--primary {',
'  border-color: rgba(247,198,0,0.45);',
'  background: rgba(247,198,0,0.06);',
'}',
'.cv2-coreCard--primary:hover {',
'  border-color: rgba(247,198,0,0.62);',
'  background: rgba(247,198,0,0.10);',
'}'
) -join "`n"

if (Test-Path -LiteralPath $globalsAbs) {
  $g = Get-Content -Raw -LiteralPath $globalsAbs
  if ($g -notmatch "CV2 CORE NODES v0_1") {
    $bk2 = BackupFile $globalsAbs
    if ($bk2) { Write-Host ("[BK] " + $bk2) }
    WriteUtf8NoBom $globalsAbs ($g.TrimEnd() + $cssBlock + "`n")
    Write-Host ("[PATCH] " + $globalsRel + " (append CV2 CORE NODES css)")
  } else {
    Write-Host "[SKIP] globals.css já tem CV2 CORE NODES."
  }
} else {
  Write-Host ("[WARN] não achei " + $globalsRel + " — pulando css.")
}

# ------------------------------------------------------------
# 3) Patch Hub page to render core nodes
# ------------------------------------------------------------
$hubLines = Get-Content -LiteralPath $hubAbs
$hubChanged = $false

if (($hubLines -join "`n") -notmatch "Cv2CoreNodes") {
  # import
  $hasImport = (($hubLines -join "`n") -match "from `"`@/components/v2/Cv2CoreNodes`"")
  if (-not $hasImport) {
    $lastImport = -1
    for ($i=0; $i -lt $hubLines.Count; $i++) {
      if ($hubLines[$i].TrimStart().StartsWith("import ")) { $lastImport = $i }
    }
    if ($lastImport -ge 0) {
      $hubLines = @(
        $hubLines[0..$lastImport] +
        'import Cv2CoreNodes from "@/components/v2/Cv2CoreNodes";' +
        $hubLines[($lastImport+1)..($hubLines.Count-1)]
      )
      $hubChanged = $true
    }
  }

  $block = @(
'',
'        {/* Núcleo do universo (Concreto Zen) */}',
'        <Cv2CoreNodes slug={slug} title={title} />'
  )

  $idx = -1
  for ($i=0; $i -lt $hubLines.Count; $i++) { if ($hubLines[$i] -match "<V2QuickNav") { $idx = $i; break } }
  if ($idx -ge 0) {
    $hubLines = @(
      $hubLines[0..$idx] +
      $block +
      $hubLines[($idx+1)..($hubLines.Count-1)]
    )
    $hubChanged = $true
  } else {
    $midx = -1
    for ($i=0; $i -lt $hubLines.Count; $i++) { if ($hubLines[$i] -match "<main") { $midx = $i; break } }
    if ($midx -ge 0) {
      $hubLines = @(
        $hubLines[0..$midx] +
        $block +
        $hubLines[($midx+1)..($hubLines.Count-1)]
      )
      $hubChanged = $true
    } else {
      Write-Host "[WARN] não achei <V2QuickNav> nem <main> — não injetei."
    }
  }
} else {
  Write-Host "[SKIP] Hub já tem Cv2CoreNodes."
}

if ($hubChanged) {
  $bk3 = BackupFile $hubAbs
  if ($bk3) { Write-Host ("[BK] " + $bk3) }
  WriteUtf8NoBom $hubAbs ($hubLines -join "`n")
  Write-Host ("[PATCH] " + $hubRel + " (inject core nodes)")
} else {
  Write-Host "[SKIP] Hub não precisou alteração."
}

# ------------------------------------------------------------
# VERIFY
# ------------------------------------------------------------
$npm = (Get-Command npm.cmd -ErrorAction Stop).Path

Write-Host "[RUN] npm run lint"
$lintOut = (& $npm run lint 2>&1 | Out-String)
$lintExit = $LASTEXITCODE
if ($lintExit -ne 0) { Write-Host $lintOut; throw ("[STOP] lint falhou (exit=" + $lintExit + ")") }

Write-Host "[RUN] npm run build"
$buildOut = (& $npm run build 2>&1 | Out-String)
$buildExit = $LASTEXITCODE
if ($buildExit -ne 0) { Write-Host $buildOut; throw ("[STOP] build falhou (exit=" + $buildExit + ")") }

# ------------------------------------------------------------
# REPORT
# ------------------------------------------------------------
$repDir = Join-Path $repoRoot "reports"
EnsureDir $repDir
$rep = Join-Path $repDir ($stamp + "-cv-b6v-v2-hub-core-mapfirst.md")

$body = @(
  ("# CV B6V — V2 Hub Core Nodes + Map-first CTA — " + $stamp),
  "",
  ("Repo: " + $repoRoot),
  "",
  "## PATCH",
  ("- " + $coreRel),
  ("- " + $globalsRel + " (CV2 CORE NODES v0_1)"),
  ("- " + $hubRel),
  "",
  "## VERIFY",
  ("- lint exit: " + $lintExit),
  ("- build exit: " + $buildExit)
) -join "`n"

WriteUtf8NoBom $rep $body
Write-Host ("[REPORT] reports\" + (Split-Path -Leaf $rep))
Write-Host "[OK] B6V v0_2 concluído."