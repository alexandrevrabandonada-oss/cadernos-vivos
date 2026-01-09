param()

$ErrorActionPreference = "Stop"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$step  = "cv-hotfix-b6u8-rail-lint-v0_1"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

# Bootstrap preferido
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

$fileRel = "src/components/v2/Cv2MapRail.tsx"
$fileAbs = Join-Path $repoRoot $fileRel

if (-not (Test-Path -LiteralPath $fileAbs)) { throw ("[STOP] não achei: " + $fileAbs) }

$bk = BackupFile $fileAbs

$ts = @(
'import Link from "next/link";',
'import type { CSSProperties } from "react";',
'',
'type CoreNode = { title: string; blurb?: string; href?: string };',
'',
'function isRec(v: unknown): v is Record<string, unknown> {',
'  return !!v && typeof v === "object";',
'}',
'',
'function toStr(v: unknown): string {',
'  return (typeof v === "string") ? v : "";',
'}',
'',
'function readCore(meta: unknown): CoreNode[] {',
'  if (!isRec(meta)) return [];',
'',
'  const m = meta;',
'  const ui = isRec(m["ui"]) ? (m["ui"] as Record<string, unknown>) : undefined;',
'  const v2 = ui && isRec(ui["v2"]) ? (ui["v2"] as Record<string, unknown>) : undefined;',
'',
'  const cand =',
'    m["core"] ??',
'    m["nucleo"] ??',
'    (ui ? (ui["core"] ?? ui["nucleo"]) : undefined) ??',
'    (v2 ? (v2["core"] ?? v2["nucleo"]) : undefined);',
'',
'  if (!Array.isArray(cand)) return [];',
'',
'  const out: CoreNode[] = [];',
'  for (const it of cand) {',
'    if (!isRec(it)) continue;',
'    const title = toStr(it["title"] ?? it["t"] ?? it["name"]).trim();',
'    if (!title) continue;',
'    const blurb = toStr(it["blurb"] ?? it["desc"] ?? it["hint"]).trim();',
'    const href  = toStr(it["href"] ?? it["url"]).trim();',
'    out.push({ title, blurb: blurb || undefined, href: href || undefined });',
'    if (out.length >= 9) break;',
'  }',
'  return out;',
'}',
'',
'export default function Cv2MapRail(props: { slug: string; title?: string; meta?: unknown }) {',
'  const { slug, title, meta } = props;',
'  const core = readCore(meta);',
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
'            (opcional) Defina 5–9 nós em meta.core ou meta.ui.v2.core.',
'          </div>',
'        )}',
'      </div>',
'    </div>',
'  );',
'}',
''
)

WriteUtf8NoBom $fileAbs ($ts -join "`n")
Write-Host ("[PATCH] " + $fileRel)
if ($bk) { Write-Host ("[BK]    tools/_patch_backup/" + (Split-Path -Leaf $bk)) }

# VERIFY
$npm = (Get-Command npm.cmd -ErrorAction Stop).Path
Write-Host "[RUN] npm run lint"
$lintOut = (& $npm run lint 2>&1 | Out-String); $lintExit = $LASTEXITCODE
if ($lintExit -ne 0) { Write-Host $lintOut; throw ("[STOP] lint falhou (exit=" + $lintExit + ")") }

Write-Host "[RUN] npm run build"
$buildOut = (& $npm run build 2>&1 | Out-String); $buildExit = $LASTEXITCODE
if ($buildExit -ne 0) { Write-Host $buildOut; throw ("[STOP] build falhou (exit=" + $buildExit + ")") }

# REPORT
$repDir = Join-Path $repoRoot "reports"
EnsureDir $repDir
$rep = Join-Path $repDir ($stamp + "-" + $step + ".md")

$body = @(
  ("# CV HOTFIX — B6U8 Rail lint/type fix — " + $stamp),
  "",
  ("Repo: " + $repoRoot),
  "",
  "## PATCH",
  "- src/components/v2/Cv2MapRail.tsx (remove any + remove side-effect line)",
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
Write-Host ("[REPORT] reports/" + (Split-Path -Leaf $rep))
Write-Host "[OK] HOTFIX aplicado (Cv2MapRail lint/build OK)."