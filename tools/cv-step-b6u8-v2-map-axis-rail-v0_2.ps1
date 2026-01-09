param()

$ErrorActionPreference = "Stop"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$step  = "cv-step-b6u8-v2-map-axis-rail-v0_2"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

# Bootstrap (preferred)
$boot = Join-Path $repoRoot "tools/_bootstrap.ps1"
if (Test-Path -LiteralPath $boot) {
  . $boot
} else {
  function EnsureDir([string]$p) { if ($p -and -not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
  function WriteUtf8NoBom([string]$path, [string]$content) {
    $dir = Split-Path -Parent $path
    if ($dir) { EnsureDir $dir }
    [IO.File]::WriteAllText($path, $content, [Text.UTF8Encoding]::new($false))
  }
  function BackupFile([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    $bkDir = Join-Path $repoRoot "tools/_patch_backup"
    EnsureDir $bkDir
    $leaf = Split-Path -Leaf $path
    $bk = Join-Path $bkDir ($stamp + "-" + $leaf + ".bak")
    Copy-Item -Force -LiteralPath $path -Destination $bk
    return $bk
  }
}

Write-Host ("== " + $step + " == " + $stamp)
Write-Host ("[DIAG] Repo: " + $repoRoot)

# ------------------------------------------------------------
# TARGETS (usar LiteralPath por causa de [slug])
# ------------------------------------------------------------
$mapPageAbs = Join-Path $repoRoot "src/app/c/[slug]/v2/mapa/page.tsx"
$globalsAbs = Join-Path $repoRoot "src/app/globals.css"
$railAbs    = Join-Path $repoRoot "src/components/v2/Cv2MapRail.tsx"

if (-not (Test-Path -LiteralPath $mapPageAbs)) { throw ("[STOP] não achei: " + $mapPageAbs) }
if (-not (Test-Path -LiteralPath $globalsAbs)) { throw ("[STOP] não achei: " + $globalsAbs) }

# ------------------------------------------------------------
# PATCH 1: Cv2MapRail.tsx
# ------------------------------------------------------------
$bkRail = BackupFile $railAbs

$railLines = @(
'import Link from "next/link";',
'import type { CSSProperties } from "react";',
'',
'type CoreNode = { title: string; blurb?: string; href?: string };',
'',
'function toStr(v: unknown): string { return (typeof v === "string") ? v : ""; }',
'',
'function readCore(meta: unknown): CoreNode[] {',
'  const m = meta as Record<string, any> | undefined;',
'  const cand =',
'    (m && (m as any).core) ??',
'    (m && (m as any).nucleo) ??',
'    (m && (m as any).ui && (m as any).ui.core) ??',
'    (m && (m as any).ui && (m as any).ui.v2 && (m as any).ui.v2.core) ??',
'    (m && (m as any).ui && (m as any).ui.v2 && (m as any).ui.v2.nucleo);',
'',
'  if (!Array.isArray(cand)) return [];',
'  const out: CoreNode[] = [];',
'  for (const it of cand) {',
'    if (!it || typeof it !== "object") continue;',
'    const r = it as Record<string, unknown>;',
'    const title = toStr(r["title"] ?? r["t"] ?? r["name"]);',
'    if (!title.trim()) continue;',
'    const blurb = toStr(r["blurb"] ?? r["desc"] ?? r["hint"]);',
'    const href = toStr(r["href"] ?? r["url"]);',
'    out.push({ title: title.trim(), blurb: blurb.trim() || undefined, href: href.trim() || undefined });',
'    if (out.length >= 9) break;',
'  }',
'  return out;',
'}',
'',
'export default function Cv2MapRail(props: { slug: string; title?: string; meta?: unknown }) {',
'  const { slug, title, meta } = props;',
'  const core = readCore(meta);',
' suggested = "var(--accent, #F7C600)";',
'  const accent = "var(--accent, #F7C600)";',
'',
'  const chip: CSSProperties = {',
'    display: "inline-flex", alignItems: "center", gap: 8, padding: "6px 10px",',
'    borderRadius: 999, border: "1px solid rgba(255,255,255,.14)",',
'    background: "rgba(0,0,0,.22)", color: "rgba(255,255,255,.9)",',
'    fontSize: 12, lineHeight: 1.2, whiteSpace: "nowrap",',
'  };',
'',
'  const doors = [',
'    { k: "hub",    href: "/c/" + slug + "/v2",                 t: "Hub",            d: "Voltar pro núcleo do universo." },',
'    { k: "linha",  href: "/c/" + slug + "/v2/linha",           t: "Linha",          d: "Nós do universo: temas, atores e tensões." },',
'    { k: "tempo",  href: "/c/" + slug + "/v2/linha-do-tempo",  t: "Linha do tempo", d: "Sequência e viradas: o filme da história." },',
'    { k: "provas", href: "/c/" + slug + "/v2/provas",          t: "Provas",         d: "Fontes, links, rastros e documentos." },',
'    { k: "trilhas",href: "/c/" + slug + "/v2/trilhas",         t: "Trilhas",        d: "Caminhos guiados: do básico ao profundo." },',
'    { k: "debate", href: "/c/" + slug + "/v2/debate",          t: "Debate",         d: "Conversa em camadas: crítica + cuidado." },',
'  ];',
'',
'  return (',
'    <div className="cv2-rail">',
'      <div className="cv2-rail-head">',
'        <div style={{ display: "flex", gap: 10, alignItems: "baseline", justifyContent: "space-between" }}>',
'          <h2 style={{ margin: 0, fontSize: 14, letterSpacing: 0.2 }}>Mapa é o eixo</h2>',
'          <span style={chip}><span style={{ width: 8, height: 8, borderRadius: 999, background: accent, display: "inline-block" }} /> porta</span>',
'        </div>',
'        <p style={{ margin: "8px 0 0 0", color: "rgba(255,255,255,.78)", fontSize: 13, lineHeight: 1.35 }}>',
'          Use o mapa para escolher um lugar. Depois: Linha → Provas → Trilhas → Debate.',
'        </p>',
'        {title ? (',
'          <div style={{ marginTop: 10, ...chip, opacity: 0.95 }} aria-label="Caderno atual">',
'            <span style={{ fontWeight: 700 }}>{title}</span>',
'          </div>',
'        ) : null}',
'      </div>',
'',
'      <div className="cv2-rail-block">',
'        <div className="cv2-rail-block-title">Próximas portas</div>',
'        <div className="cv2-rail-grid">',
'          {doors.map((it) => (',
'            <Link key={it.k} className="cv2-portal" href={it.href}>',
'              <div className="cv2-portal-top">',
'                <span className="cv2-portal-title">{it.t}</span>',
'                <span className="cv2-portal-chip">abrir</span>',
'              </div>',
'              <div className="cv2-portal-desc">{it.d}</div>',
'            </Link>',
'          ))}',
'        </div>',
'      </div>',
'',
'      <div className="cv2-rail-block">',
'        <div className="cv2-rail-block-title">Roteiro rápido</div>',
'        <ol className="cv2-rail-ol">',
'          <li>Escolha um lugar no mapa (pino/área).</li>',
'          <li>Abra a <b>Linha</b> para ver nós e relações.</li>',
'          <li>Vá em <b>Provas</b> pra sustentar com fontes.</li>',
'          <li>Feche com <b>Trilhas</b> ou <b>Debate</b>.</li>',
'        </ol>',
'      </div>',
'',
'      <div className="cv2-rail-block">',
'        <div className="cv2-rail-block-title">Núcleo do universo</div>',
'        {core.length ? (',
'          <div className="cv2-core">',
'            {core.map((n, i) => (',
'              n.href ? (',
'                <Link key={i} className="cv2-core-item" href={n.href}>',
'                  <div className="cv2-core-title">{n.title}</div>',
'                  {n.blurb ? <div className="cv2-core-desc">{n.blurb}</div> : null}',
'                </Link>',
'              ) : (',
'                <div key={i} className="cv2-core-item" role="listitem">',
'                  <div className="cv2-core-title">{n.title}</div>',
'                  {n.blurb ? <div className="cv2-core-desc">{n.blurb}</div> : null}',
'                </div>',
'              )',
'            ))}',
'          </div>',
'        ) : (',
'          <div style={{ color: "rgba(255,255,255,.72)", fontSize: 13, lineHeight: 1.35 }}>',
'            <div style={{ marginBottom: 6 }}>(opcional) Defina 5–9 nós no meta do caderno em core ou ui.v2.core.</div>',
'            <div style={{ opacity: 0.9 }}><code>[{"{ title, blurb?, href? }"}]</code></div>',
'          </div>',
'        )}',
'      </div>',
'    </div>',
'  );',
'}'
)

EnsureDir (Split-Path -Parent $railAbs)
WriteUtf8NoBom $railAbs ($railLines -join "`n")
Write-Host ("[PATCH] src/components/v2/Cv2MapRail.tsx")
if ($bkRail) { Write-Host ("[BK]    tools/_patch_backup/" + (Split-Path -Leaf $bkRail)) }

# ------------------------------------------------------------
# PATCH 2: globals.css (append rail styles)
# ------------------------------------------------------------
$bkGlobals = BackupFile $globalsAbs
$g = Get-Content -Raw -LiteralPath $globalsAbs
if ($null -eq $g) { throw "[STOP] falhou lendo globals.css" }

$marker = "/* CV2 MAP RAIL v0_1 */"
if ($g -notmatch [regex]::Escape($marker)) {
  $css = @(
    "",
    $marker,
    ".cv2-map-layout{display:grid;grid-template-columns:minmax(0,1fr) 360px;gap:14px;align-items:start}",
    ".cv2-map-main{min-width:0}",
    ".cv2-map-rail{position:sticky;top:12px;min-width:0}",
    "@media (max-width: 980px){.cv2-map-layout{grid-template-columns:1fr}.cv2-map-rail{position:static}}",
    "",
    ".cv2-rail{border:1px solid rgba(255,255,255,.12);border-radius:14px;background:rgba(0,0,0,.18);padding:12px}",
    ".cv2-rail-head{padding:8px 10px 10px 10px;border:1px solid rgba(255,255,255,.10);border-radius:12px;background:rgba(255,255,255,.03)}",
    ".cv2-rail-block{margin-top:12px;padding:10px;border:1px solid rgba(255,255,255,.10);border-radius:12px;background:rgba(0,0,0,.10)}",
    ".cv2-rail-block-title{font-size:12px;letter-spacing:.24px;text-transform:uppercase;color:rgba(255,255,255,.72);margin:0 0 8px 0}",
    ".cv2-rail-grid{display:grid;grid-template-columns:1fr;gap:10px}",
    ".cv2-portal{display:block;text-decoration:none;border:1px solid rgba(255,255,255,.12);border-radius:12px;padding:10px;background:rgba(255,255,255,.03);color:rgba(255,255,255,.92)}",
    ".cv2-portal:hover{border-color:rgba(255,255,255,.22);background:rgba(255,255,255,.05)}",
    ".cv2-portal-top{display:flex;align-items:center;justify-content:space-between;gap:10px}",
    ".cv2-portal-title{font-weight:800;font-size:14px;letter-spacing:.2px}",
    ".cv2-portal-desc{margin-top:6px;font-size:13px;line-height:1.35;color:rgba(255,255,255,.76)}",
    ".cv2-portal-chip{font-size:12px;padding:4px 8px;border-radius:999px;border:1px solid rgba(255,255,255,.14);background:rgba(0,0,0,.22);color:rgba(255,255,255,.85)}",
    "",
    ".cv2-rail-ol{margin:0;padding-left:18px;color:rgba(255,255,255,.80);font-size:13px;line-height:1.45}",
    ".cv2-rail-ol li{margin:6px 0}",
    "",
    ".cv2-core{display:grid;grid-template-columns:1fr;gap:10px}",
    ".cv2-core-item{display:block;text-decoration:none;border:1px solid rgba(255,255,255,.12);border-radius:12px;padding:10px;background:rgba(255,255,255,.02);color:rgba(255,255,255,.92)}",
    ".cv2-core-item:hover{border-color:rgba(255,255,255,.22);background:rgba(255,255,255,.04)}",
    ".cv2-core-title{font-weight:800;font-size:13px;letter-spacing:.2px}",
    ".cv2-core-desc{margin-top:6px;font-size:12.5px;line-height:1.35;color:rgba(255,255,255,.74)}",
    ""
  ) -join "`n"

  WriteUtf8NoBom $globalsAbs ($g.TrimEnd() + $css)
  Write-Host "[PATCH] src/app/globals.css (append CV2 MAP RAIL v0_1)"
  if ($bkGlobals) { Write-Host ("[BK]    tools/_patch_backup/" + (Split-Path -Leaf $bkGlobals)) }
} else {
  Write-Host "[SKIP] globals.css já tem CV2 MAP RAIL v0_1"
}

# ------------------------------------------------------------
# PATCH 3: mapa/page.tsx (wrap map + rail)
# ------------------------------------------------------------
$bkMap = BackupFile $mapPageAbs
$raw = Get-Content -Raw -LiteralPath $mapPageAbs
if ($null -eq $raw) { throw "[STOP] falhou lendo mapa/page.tsx" }

if ($raw -match "cv2-map-layout") {
  Write-Host "[SKIP] mapa/page.tsx já parece ter layout cv2-map-layout"
} else {
  if ($raw -notmatch 'Cv2MapRail') {
    $importLine = 'import Cv2MapRail from "@/components/v2/Cv2MapRail";'
    if ($raw -match '(?m)^import\s+MapaV2Interactive.*$') {
      $raw = [regex]::Replace($raw, '(?m)^(import\s+MapaV2Interactive.*\r?\n)', ('$1' + $importLine + "`n"), 1)
    } else {
      $raw = $importLine + "`n" + $raw
    }
  }

  $pattern = '(?s)<div\s+style=\{\{\s*marginTop:\s*12\s*\}\}>\s*(?<map><MapaV2Interactive\b[^>]*\/>)\s*<\/div>'
  if ($raw -match $pattern) {
    $raw = [regex]::Replace($raw, $pattern, {
      param($m)
      $mapLine = $m.Groups["map"].Value
      return @(
'      <div className="cv2-map-layout" style={{ marginTop: 12 }}>',
'        <section className="cv2-map-main" aria-label="Mapa do universo">',
("          " + $mapLine),
'        </section>',
'        <aside className="cv2-map-rail" aria-label="Corredor de portas do mapa">',
'          <Cv2MapRail slug={slug} title={title} meta={data.meta} />',
'        </aside>',
'      </div>'
      ) -join "`n"
    }, 1)
  } else {
    throw "[STOP] não encontrei o bloco <div style={{ marginTop: 12 }}> com MapaV2Interactive pra trocar"
  }

  WriteUtf8NoBom $mapPageAbs $raw
  Write-Host "[PATCH] src/app/c/[slug]/v2/mapa/page.tsx (layout + rail)"
  if ($bkMap) { Write-Host ("[BK]    tools/_patch_backup/" + (Split-Path -Leaf $bkMap)) }
}

# ------------------------------------------------------------
# VERIFY
# ------------------------------------------------------------
$verifyAbs = Join-Path $repoRoot "tools/cv-verify.ps1"
$verifyOut = ""
$verifyExit = 0

if (Test-Path -LiteralPath $verifyAbs) {
  Write-Host ("[RUN] " + $verifyAbs)
  $verifyOut = (& pwsh -NoProfile -ExecutionPolicy Bypass -File $verifyAbs 2>&1 | Out-String)
  $verifyExit = $LASTEXITCODE
} else {
  $npm = (Get-Command npm.cmd -ErrorAction Stop).Path
  Write-Host "[RUN] npm run lint"
  $lintOut = (& $npm run lint 2>&1 | Out-String); $lintExit = $LASTEXITCODE
  if ($lintExit -ne 0) { Write-Host $lintOut; throw ("[STOP] lint falhou (exit=" + $lintExit + ")") }
  Write-Host "[RUN] npm run build"
  $buildOut = (& $npm run build 2>&1 | Out-String); $buildExit = $LASTEXITCODE
  if ($buildExit -ne 0) { Write-Host $buildOut; throw ("[STOP] build falhou (exit=" + $buildExit + ")") }
  $verifyOut = ("[FALLBACK] lint/build OK`n--- LINT ---`n" + $lintOut.TrimEnd() + "`n--- BUILD ---`n" + $buildOut.TrimEnd())
  $verifyExit = 0
}

if ($verifyExit -ne 0) { Write-Host $verifyOut; throw ("[STOP] verify falhou (exit=" + $verifyExit + ")") }

# ------------------------------------------------------------
# REPORT
# ------------------------------------------------------------
$repDir = Join-Path $repoRoot "reports"
EnsureDir $repDir
$rep = Join-Path $repDir ($stamp + "-" + $step + ".md")

$body = @(
  ("# CV B6U8 — Mapa V2 como eixo (Rail/Portas) — " + $stamp),
  "",
  ("Repo: " + $repoRoot),
  "",
  "## PATCH",
  "- src/components/v2/Cv2MapRail.tsx",
  "- src/app/c/[slug]/v2/mapa/page.tsx",
  "- src/app/globals.css (append CV2 MAP RAIL v0_1)",
  "",
  "## VERIFY OUTPUT START",
  $verifyOut.TrimEnd(),
  "## VERIFY OUTPUT END",
  "",
  "## COMMIT sugerido",
  "- chore(cv): V2 mapa vira eixo com rail de portas"
) -join "`n"

WriteUtf8NoBom $rep $body
Write-Host ("[REPORT] reports/" + (Split-Path -Leaf $rep))
Write-Host "[OK] B6U8 v0_2 concluído (Mapa eixo + Rail de Portas)."