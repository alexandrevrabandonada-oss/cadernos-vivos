param()
$ErrorActionPreference = "Stop"

$stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

Write-Host ("== cv-step-b6u-hub-map-first-v0_1 == " + $stamp)
Write-Host ("[DIAG] Repo: " + $repoRoot)

function EnsureDir([string]$p) { if (!(Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function BackupFile([string]$abs) {
  $bkDir = Join-Path $repoRoot "tools\_patch_backup"
  EnsureDir $bkDir
  $leaf = (Split-Path -Leaf $abs) -replace "[\\\/:\s]", "_"
  $bk = Join-Path $bkDir ($stamp + "-" + $leaf + ".bak")
  Copy-Item -LiteralPath $abs -Destination $bk -Force
  return $bk
}
function WriteUtf8NoBom([string]$abs, [string]$content) { [IO.File]::WriteAllText($abs, $content, [Text.UTF8Encoding]::new($false)) }
function WriteLines([string]$abs, [string[]]$lines) { [IO.File]::WriteAllLines($abs, $lines, [Text.UTF8Encoding]::new($false)) }

$patched = New-Object System.Collections.Generic.List[string]

# ------------------------------------------------------------
# 1) globals.css: add Map-First polish (idempotent)
# ------------------------------------------------------------
$globalsRel = "src\app\globals.css"
$globalsAbs = Join-Path $repoRoot $globalsRel

if (Test-Path -LiteralPath $globalsAbs) {
  $raw = Get-Content -LiteralPath $globalsAbs -Raw
  if ($raw -notmatch "CV2 MAP FIRST") {
    $bk = BackupFile $globalsAbs

    $append = @"




/* ===== CV2 MAP FIRST (Concreto Zen) ===== */
/* CV2 MAP FIRST */
[id^="cv2-"] .cv2-card,
.cv-v2 .cv2-card {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

[id^="cv2-"] .cv2-card--primary,
.cv-v2 .cv2-card--primary {
  grid-column: span 2;
  background: rgba(255,255,255,0.06);
  border-color: rgba(255,255,255,0.20);
}

@media (max-width: 780px) {
  [id^="cv2-"] .cv2-card--primary,
  .cv-v2 .cv2-card--primary {
    grid-column: auto;
  }
}

[id^="cv2-"] .cv2-pill,
.cv-v2 .cv2-pill {
  font-size: 11px;
  padding: 4px 8px;
  border-radius: 999px;
  border: 1px solid rgba(255,255,255,0.16);
  background: rgba(255,255,255,0.06);
  opacity: 0.9;
}
/* ===== /CV2 MAP FIRST ===== */

"@

    WriteUtf8NoBom $globalsAbs ($raw.TrimEnd() + $append)
    Write-Host ("[PATCH] " + $globalsRel + " (append CV2 MAP FIRST)")
    Write-Host ("[BK]    tools\_patch_backup\" + (Split-Path -Leaf $bk))
    $patched.Add($globalsRel) | Out-Null
  } else {
    Write-Host "SKIP: globals.css já tem CV2 MAP FIRST"
  }
} else {
  Write-Host "[WARN] não achei src/app/globals.css"
}

# ------------------------------------------------------------
# 2) Rewrite V2CoreNodes.tsx: Map as primary + pill
# ------------------------------------------------------------
$coreRel = "src\components\v2\V2CoreNodes.tsx"
$coreAbs = Join-Path $repoRoot $coreRel
EnsureDir (Split-Path -Parent $coreAbs)

if (Test-Path -LiteralPath $coreAbs) {
  $bk = BackupFile $coreAbs
  Write-Host ("[BK]    tools\_patch_backup\" + (Split-Path -Leaf $bk))
}

$coreLines = @(
'import Link from "next/link";',
'',
'type Item = { key: string; href: (slug: string) => string; title: string; desc: string };',
'',
'const CORE: Item[] = [',
'  { key: "mapa", href: (s) => "/c/" + s + "/v2/mapa", title: "Mapa", desc: "O eixo do universo: lugares, conexões e portas." },',
'  { key: "linha", href: (s) => "/c/" + s + "/v2/linha", title: "Linha", desc: "Nós do universo: temas, cenas, atores e tensões." },',
'  { key: "linha-do-tempo", href: (s) => "/c/" + s + "/v2/linha-do-tempo", title: "Linha do tempo", desc: "Sequência, memória e viradas da história." },',
'  { key: "provas", href: (s) => "/c/" + s + "/v2/provas", title: "Provas", desc: "Fontes, links, documentos e rastros." },',
'  { key: "trilhas", href: (s) => "/c/" + s + "/v2/trilhas", title: "Trilhas", desc: "Caminhos guiados: do básico ao profundo." },',
'  { key: "debate", href: (s) => "/c/" + s + "/v2/debate", title: "Debate", desc: "Conversa em camadas: crítica + cuidado." },',
'];',
'',
'export default function V2CoreNodes({ slug }: { slug: string }) {',
'  return (',
'    <section aria-label="Núcleo do universo">', 
'      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", gap: 12, flexWrap: "wrap" }}>',
'        <h2 style={{ fontSize: 16, margin: 0 }}>Núcleo do universo</h2>',
'        <div style={{ fontSize: 12, opacity: 0.7 }}>{CORE.length} portas essenciais</div>',
'      </div>',
'',
'      <div style={{ display: "grid", gap: 10, gridTemplateColumns: "repeat(auto-fit, minmax(230px, 1fr))", marginTop: 10 }}>',
'        {CORE.map((x) => {',
'          const isPrimary = x.key === "mapa";',
'          const cls = "cv2-card" + (isPrimary ? " cv2-card--primary" : "");',
'          return (',
'            <Link key={x.key} href={x.href(slug)} className={cls}>',
'              <div style={{ display: "flex", alignItems: "baseline", justifyContent: "space-between", gap: 10 }}>',
'                <div className="cv2-cardTitle">{x.title}</div>',
'                {isPrimary ? <span className="cv2-pill">Comece aqui</span> : null}',
'              </div>',
'              <div className="cv2-cardDesc">{x.desc}</div>',
'            </Link>',
'          );',
'        })}',
'      </div>',
'    </section>',
'  );',
'}'
)

WriteLines $coreAbs $coreLines
Write-Host ("[PATCH] " + $coreRel)
$patched.Add($coreRel) | Out-Null

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
$rep = Join-Path $repDir ($stamp + "-cv-b6u-hub-map-first.md")

$body = @(
  ("# CV B6U — Hub Map-first — " + $stamp),
  "",
  ("Repo: " + $repoRoot),
  "",
  "## PATCH",
  ($patched | ForEach-Object { "- " + $_ }),
  "",
  "## VERIFY",
  ("- lint exit: " + $lintExit),
  ("- build exit: " + $buildExit),
  "",
  "--- LINT OUTPUT START ---",
  $lintOut.TrimEnd(),
  "--- LINT OUTPUT END ---",
  "",
  "--- BUILD OUTPUT START ---",
  $buildOut.TrimEnd(),
  "--- BUILD OUTPUT END ---"
) -join "`n"

WriteUtf8NoBom $rep $body
Write-Host ("[REPORT] reports\" + (Split-Path -Leaf $rep))
Write-Host "[OK] B6U concluído (Mapa como porta principal + pill)."