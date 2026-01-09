$ErrorActionPreference = "Stop"

function _NowTag { Get-Date -Format "yyyyMMdd-HHmmss" }

# --- Bootstrap preferencial ---
$boot = Join-Path $PSScriptRoot "_bootstrap.ps1"
if (Test-Path -LiteralPath $boot) { . $boot }

# --- Fallbacks (se bootstrap não estiver disponível no contexto) ---
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
Write-Host ("== CV HOTFIX B6U8 — MapRail lint safe v0_3 == " + $stamp)
Write-Host ("[DIAG] Repo: " + $repoRoot)

$railRel = "src/components/v2/Cv2MapRail.tsx"
$railAbs = Join-Path $repoRoot $railRel

if (-not (Test-Path -LiteralPath $railAbs)) {
  Write-Host ("[SKIP] não existe: " + $railRel)
} else {
  $raw = Get-Content -LiteralPath $railAbs -Raw

  $hasAny = ($raw -match ":\s*any\b") -or ($raw -match "\bany\[\]") -or ($raw -match "\bany\b")
  $hasSuggestedReassign = ($raw -match "`n\s*suggested\s*=") -or ($raw -match "suggested\s*=\s*`"var\(")
  $needsRewrite = $hasAny -or $hasSuggestedReassign

  Write-Host ("[DIAG] MapRail: hasAny=" + $hasAny + " hasSuggestedReassign=" + $hasSuggestedReassign + " => rewrite=" + $needsRewrite)

  if ($needsRewrite) {
    $bk = BackupFile $railAbs
    if ($bk) { Write-Host ("[BK] " + $bk) }

    $tsLines = @(
'/* eslint-disable @typescript-eslint/no-unused-vars */',
'',
'import Link from "next/link";',
'import React from "react";',
'',
'type MetaLike = Record<string, unknown> | null | undefined;',
'',
'type RailProps = {',
'  slug: string;',
'  title?: string;',
'  meta?: MetaLike | unknown;',
'};',
'',
'type RailPage = {',
'  id: string;',
'  label: string;',
'  href: (slug: string) => string;',
'};',
'',
'const PAGES: RailPage[] = [',
'  { id: "hub", label: "Hub", href: (s) => "/c/" + encodeURIComponent(s) + "/v2" },',
'  { id: "mapa", label: "Mapa", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/mapa" },',
'  { id: "linha", label: "Linha", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/linha" },',
'  { id: "linha-do-tempo", label: "Tempo", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/linha-do-tempo" },',
'  { id: "provas", label: "Provas", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/provas" },',
'  { id: "trilhas", label: "Trilhas", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/trilhas" },',
'  { id: "debate", label: "Debate", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/debate" },',
'];',
'',
'function safeSlug(v: unknown): string {',
'  return (typeof v === "string" ? v : "").trim();',
'}',
'',
'export function Cv2MapRail(props: RailProps) {',
'  const slug = safeSlug(props.slug);',
'  if (!slug) return null;',
'  const title = (typeof props.title === "string" && props.title.trim().length) ? props.title.trim() : slug;',
'',
'  return (',
'    <aside className="cv2-mapRail" aria-label="Corredor de portas">',
'      <div className="cv2-mapRail__inner">',
'        <div className="cv2-mapRail__title">',
'          <div className="cv2-mapRail__kicker">Eixo</div>',
'          <div className="cv2-mapRail__name">{title}</div>',
'        </div>',
'',
'        <nav className="cv2-mapRail__nav" aria-label="Portas do universo">',
'          {PAGES.map((p) => (',
'            <Link key={p.id} className={"cv2-mapRail__a" + (p.id === "mapa" ? " is-axis" : "")} href={p.href(slug)}>',
'              <span className="cv2-mapRail__dot" aria-hidden="true" />',
'              <span className="cv2-mapRail__txt">{p.label}</span>',
'            </Link>',
'          ))}',
'        </nav>',
'',
'        <div className="cv2-mapRail__hint">Mapa é o eixo. O resto são portas.</div>',
'      </div>',
'    </aside>',
'  );',
'}',
'',
'export default Cv2MapRail;'
    ) -join "`n"

    WriteUtf8NoBom $railAbs $tsLines
    Write-Host ("[PATCH] rewrote -> " + $railRel)
  } else {
    Write-Host "[SKIP] Cv2MapRail.tsx já está limpo."
  }
}

# 2) Ensure CSS block exists (idempotente)
$globalsRel = "src/app/globals.css"
$globalsAbs = Join-Path $repoRoot $globalsRel
if (Test-Path -LiteralPath $globalsAbs) {
  $g = Get-Content -LiteralPath $globalsAbs -Raw
  if ($g -notmatch "CV2 MAP RAIL v0_3") {
    $bk2 = BackupFile $globalsAbs
    if ($bk2) { Write-Host ("[BK] " + $bk2) }

    $css = @(
'',
'/* CV2 MAP RAIL v0_3 */',
'.cv2-mapRail {',
'  position: sticky;',
'  top: 76px;',
'  align-self: start;',
'  border-left: 1px solid rgba(255,255,255,0.08);',
'  padding-left: 12px;',
'  margin-left: 6px;',
'}',
'.cv2-mapRail__inner {',
'  display: grid;',
'  gap: 10px;',
'  padding: 10px 8px;',
'  border-radius: 12px;',
'  background: rgba(0,0,0,0.22);',
'  box-shadow: 0 0 0 1px rgba(255,255,255,0.06) inset;',
'}',
'.cv2-mapRail__kicker {',
'  font-size: 11px;',
'  letter-spacing: 0.12em;',
'  text-transform: uppercase;',
'  opacity: 0.75;',
'}',
'.cv2-mapRail__name {',
'  font-size: 14px;',
'  font-weight: 700;',
'}',
'.cv2-mapRail__nav {',
'  display: grid;',
'  gap: 8px;',
'}',
'.cv2-mapRail__a {',
'  display: inline-flex;',
'  align-items: center;',
'  gap: 10px;',
'  padding: 8px 10px;',
'  border-radius: 999px;',
'  text-decoration: none;',
'  color: inherit;',
'  background: rgba(255,255,255,0.03);',
'  box-shadow: 0 0 0 1px rgba(255,255,255,0.06) inset;',
'  transition: transform 120ms ease, background 120ms ease, box-shadow 120ms ease;',
'}',
'.cv2-mapRail__a:hover {',
'  transform: translateX(2px);',
'  background: rgba(255,255,255,0.06);',
'  box-shadow: 0 0 0 1px rgba(255,255,255,0.10) inset;',
'}',
'.cv2-mapRail__dot {',
'  width: 10px;',
'  height: 10px;',
'  border-radius: 999px;',
'  background: rgba(255,255,255,0.22);',
'  box-shadow: 0 0 0 2px rgba(0,0,0,0.35);',
'}',
'.cv2-mapRail__a.is-axis .cv2-mapRail__dot {',
'  background: var(--accent, #F7C600);',
'  box-shadow: 0 0 0 2px rgba(0,0,0,0.35), 0 0 18px rgba(247,198,0,0.35);',
'}',
'.cv2-mapRail__txt {',
'  font-size: 13px;',
'  font-weight: 600;',
'}',
'.cv2-mapRail__hint {',
'  font-size: 12px;',
'  opacity: 0.72;',
'}'
    ) -join "`n"

    WriteUtf8NoBom $globalsAbs ($g.TrimEnd() + $css + "`n")
    Write-Host ("[PATCH] " + $globalsRel + " (append CV2 MAP RAIL v0_3)")
  } else {
    Write-Host "[SKIP] globals.css já tem CV2 MAP RAIL v0_3"
  }
} else {
  Write-Host "[WARN] não achei globals.css em src/app/globals.css"
}

# ------------------------------------------------------------
# VERIFY
# ------------------------------------------------------------
$verifyAbs = Join-Path $repoRoot "tools/cv-verify.ps1"
$npm = (Get-Command npm.cmd -ErrorAction Stop).Path

Write-Host "[RUN] npm run lint"
$lintOut = (& $npm run lint 2>&1 | Out-String)
$lintExit = $LASTEXITCODE
if ($lintExit -ne 0) { Write-Host $lintOut; throw ("[STOP] lint falhou (exit=" + $lintExit + ")") }

Write-Host "[RUN] npm run build"
$buildOut = (& $npm run build 2>&1 | Out-String)
$buildExit = $LASTEXITCODE
if ($buildExit -ne 0) { Write-Host $buildOut; throw ("[STOP] build falhou (exit=" + $buildExit + ")") }

if (Test-Path -LiteralPath $verifyAbs) {
  Write-Host ("[RUN] " + $verifyAbs)
  & pwsh -NoProfile -ExecutionPolicy Bypass -File $verifyAbs
  if ($LASTEXITCODE -ne 0) { throw ("[STOP] cv-verify falhou (exit=" + $LASTEXITCODE + ")") }
}

# ------------------------------------------------------------
# REPORT
# ------------------------------------------------------------
$repDir = Join-Path $repoRoot "reports"
EnsureDir $repDir
$rep = Join-Path $repDir ($stamp + "-cv-hotfix-b6u8-maprail-lint.md")

$body = @(
  ("# CV HOTFIX — B6U8 MapRail lint-safe — " + $stamp),
  "",
  ("Repo: " + $repoRoot),
  "",
  "## Files",
  ("- " + $railRel),
  ("- " + $globalsRel),
  "",
  "## Verify",
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
Write-Host "[OK] HOTFIX concluído (MapRail sem any + sem side-effect)."