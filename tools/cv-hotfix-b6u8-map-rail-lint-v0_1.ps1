param()

$ErrorActionPreference = "Stop"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$repoRoot = (Resolve-Path ".").Path

Write-Host ("== cv-hotfix-b6u8-map-rail-lint-v0_1 == " + $stamp)
Write-Host ("[DIAG] Repo: " + $repoRoot)

# --- bootstrap (preferencial) ---
$boot = Join-Path $repoRoot "tools\_bootstrap.ps1"
if (Test-Path $boot) {
  . $boot
} else {
  function EnsureDir([string]$p){ if(-not (Test-Path $p)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
 Iт
  function WriteUtf8NoBom([string]$p,[string]$c){ EnsureDir (Split-Path -Parent $p); [IO.File]::WriteAllText($p,$c,[Text.UTF8Encoding]::new($false)) }
  function BackupFile([string]$p){
    $bkDir = Join-Path $repoRoot ("tools\_patch_backup\" + (Get-Date -Format "yyyyMMdd-HHmmss"))
    EnsureDir $bkDir
    $dst = Join-Path $bkDir (Split-Path -Leaf $p) + ".bak"
    Copy-Item -Force $p $dst
    return $dst
  }
}

$targetRel = "src\components\v2\Cv2MapRail.tsx"
$targetAbs = Join-Path $repoRoot $targetRel
if (-not (Test-Path $targetAbs)) { throw ("[STOP] não achei: " + $targetAbs) }

$bk = BackupFile $targetAbs
Write-Host ("[BK]    " + $bk)

# --- PATCH: rewrite lint-safe Cv2MapRail.tsx ---
$lines = @(
'/* CV2 MapRail — lint-safe (no any, no render side-effects) */',
'import React from "react";',
'import Link from "next/link";',
'',
'type CoreNode = { id: string; title: string; kind?: string; blurb?: string };',
'type Cv2Meta = Record<string, unknown>;',
'',
'function asRecord(v: unknown): Record<string, unknown> | null {',
'  return v && typeof v === "object" ? (v as Record<string, unknown>) : null;',
'}',
'',
'function readCore(meta: unknown): CoreNode[] {',
'  const m = asRecord(meta) as Cv2Meta | null;',
'  if (!m) return [];',
'  const ui = asRecord(m["ui"]);',
'  const coreRaw = (ui && ui["core"]) ?? m["core"];',
'  if (!Array.isArray(coreRaw)) return [];',
'  const out: CoreNode[] = [];',
'  for (const item of coreRaw) {',
'    const r = asRecord(item);',
'    if (!r) continue;',
'    const id = typeof r["id"] === "string" ? (r["id"] as string) : (typeof r["slug"] === "string" ? (r["slug"] as string) : "");',
'    const title = typeof r["title"] === "string" ? (r["title"] as string) : (typeof r["name"] === "string" ? (r["name"] as string) : "");',
'    if (!id || !title) continue;',
'    const kind = typeof r["kind"] === "string" ? (r["kind"] as string) : undefined;',
'    const blurb = typeof r["blurb"] === "string" ? (r["blurb"] as string) : (typeof r["desc"] === "string" ? (r["desc"] as string) : undefined);',
'    out.push({ id, title, kind, blurb });',
'  }',
'  return out.slice(0, 12);',
'}',
'',
'function pickAccent(meta: unknown): string {',
'  const m = asRecord(meta);',
'  if (!m) return "var(--accent, #F7C600)";',
'  const ui = asRecord(m["ui"]);',
'  const a = (ui && ui["accent"]) ?? m["accent"];',
'  return typeof a === "string" && a.trim() ? a.trim() : "var(--accent, #F7C600)";',
'}',
'',
'export default function Cv2MapRail(props: { slug: string; title?: string; meta?: unknown }) {',
'  const { slug, title, meta } = props;',
'  const core = readCore(meta);',
'  const accent = pickAccent(meta);',
'',
'  const card: React.CSSProperties = {',
'    border: "1px solid rgba(255,255,255,0.12)",',
'    borderRadius: 14,',
'    padding: 12,',
'    background: "rgba(0,0,0,0.18)",',
'    backdropFilter: "blur(10px)",',
'  };',
'  const pill: React.CSSProperties = {',
'    display: "inline-flex",',
'    alignItems: "center",',
'    gap: 8,',
'    border: "1px solid rgba(255,255,255,0.14)",',
'    borderRadius: 999,',
'    padding: "6px 10px",',
'    fontSize: 12,',
'    color: "rgba(255,255,255,0.9)",',
'    textDecoration: "none",',
'  };',
'  const dot: React.CSSProperties = {',
'    width: 8, height: 8, borderRadius: 999, background: accent, boxShadow: "0 0 0 3px rgba(0,0,0,0.35)"',
'  };',
'',
'  return (',
'    <aside className="cv2-map-rail" style={{ display: "flex", flexDirection: "column", gap: 10 }}>',
'      <div style={card}>',
'        <div style={{ display: "flex", justifyContent: "space-between", gap: 12, alignItems: "flex-start" }}>',
'          <div>',
'            <div style={{ display: "flex", alignItems: "center", gap: 8 }}>',
'              <span style={dot} />',
'              <strong>Mapa é o eixo</strong>',
'            </div>',
'            <div style={{ marginTop: 6, opacity: 0.85, fontSize: 13, lineHeight: 1.35 }}>',
'              Use o mapa para escolher um lugar. Depois: Linha → Provas → Trilhas → Debate.',
'            </div>',
'          </div>',
'          <span style={{ ...pill, opacity: 0.85 }}>porta</span>',
'        </div>',
'        <div style={{ marginTop: 10, display: "flex", flexWrap: "wrap", gap: 8 }}>',
'          <span style={{ ...pill, opacity: 0.95 }}>{title || slug}</span>',
'          <Link href={"/c/" + slug + "/v2"} style={pill}>Hub</Link>',
'        </div>',
'      </div>',
'',
'      <div style={card}>',
'        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>',
'          <strong>Próximas portas</strong>',
'          <Link href={"/c/" + slug + "/v2"} style={pill}>Voltar ao Hub</Link>',
'        </div>',
'        <div style={{ marginTop: 10, display: "flex", flexDirection: "column", gap: 8 }}>',
'          <DoorRow label="Hub" href={"/c/" + slug + "/v2"} />',
'          <DoorRow label="Linha" href={"/c/" + slug + "/v2/linha"} />',
'          <DoorRow label="Linha do tempo" href={"/c/" + slug + "/v2/linha-do-tempo"} />',
'          <DoorRow label="Provas" href={"/c/" + slug + "/v2/provas"} />',
'          <DoorRow label="Trilhas" href={"/c/" + slug + "/v2/trilhas"} />',
'          <DoorRow label="Debate" href={"/c/" + slug + "/v2/debate"} />',
'        </div>',
'      </div>',
'',
'      {core.length > 0 ? (',
'        <div style={card}>',
'          <strong>Núcleo do universo</strong>',
'          <div style={{ marginTop: 10, display: "flex", flexDirection: "column", gap: 8 }}>',
'            {core.map((n) => (',
'              <div key={n.id} style={{ display: "flex", justifyContent: "space-between", gap: 10, alignItems: "center" }}>',
'                <div style={{ minWidth: 0 }}>',
'                  <div style={{ fontWeight: 700, lineHeight: 1.2 }}>{n.title}</div>',
'                  <div style={{ opacity: 0.75, fontSize: 12, lineHeight: 1.25 }}>',
'                    {(n.blurb || n.kind || "").toString()}',
'                  </div>',
'                </div>',
'                <span style={{ ...pill, opacity: 0.85 }}>nó</span>',
'              </div>',
'            ))}',
'          </div>',
'        </div>',
'      ) : null}',
'    </aside>',
'  );',
'}',
'',
'function DoorRow(props: { label: string; href: string }) {',
'  const row: React.CSSProperties = {',
'    display: "flex",',
'    justifyContent: "space-between",',
'    alignItems: "center",',
'    gap: 10,',
'    border: "1px solid rgba(255,255,255,0.12)",',
'    borderRadius: 12,',
'    padding: "10px 12px",',
'    textDecoration: "none",',
'    color: "rgba(255,255,255,0.92)",',
'  };',
'  const btn: React.CSSProperties = {',
'    border: "1px solid rgba(255,255,255,0.14)",',
'    borderRadius: 999,',
'    padding: "6px 10px",',
'    fontSize: 12,',
'    opacity: 0.9,',
'  };',
'  return (',
'    <Link href={props.href} style={row}>',
'      <span style={{ fontWeight: 700 }}>{props.label}</span>',
'      <span style={btn}>abrir</span>',
'    </Link>',
'  );',
'}'
)

$enc = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllLines($targetAbs, $lines, $enc)
Write-Host ("[PATCH] " + $targetRel)

# --- VERIFY ---
$npm = (Get-Command npm.cmd -ErrorAction Stop).Path

Write-Host "[RUN] npm run lint"
$lintOut = (& $npm run lint 2>&1 | Out-String)
$lintExit = $LASTEXITCODE
if ($lintExit -ne 0) { Write-Host $lintOut; throw ("[STOP] lint falhou (exit=" + $lintExit + ")") }

Write-Host "[RUN] npm run build"
$buildOut = (& $npm run build 2>&1 | Out-String)
$buildExit = $LASTEXITCODE
if ($buildExit -ne 0) { Write-Host $buildOut; throw ("[STOP] build falhou (exit=" + $buildExit + ")") }

# --- REPORT ---
$repDir = Join-Path $repoRoot "reports"
if (Get-Command EnsureDir -ErrorAction SilentlyContinue) { EnsureDir $repDir } else { New-Item -ItemType Directory -Force -Path $repDir | Out-Null }
$rep = Join-Path $repDir ($stamp + "-cv-hotfix-b6u8-map-rail-lint-v0_1.md")

$body = @(
("# CV HOTFIX B6U8 — MapRail lint-safe — " + $stamp),
"",
("Repo: " + $repoRoot),
"",
"## PATCH",
("- " + $targetRel),
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

if (Get-Command WriteUtf8NoBom -ErrorAction SilentlyContinue) { WriteUtf8NoBom $rep $body } else { [IO.File]::WriteAllText($rep, $body, $enc) }
Write-Host ("[REPORT] reports\" + (Split-Path -Leaf $rep))

Write-Host "[OK] Hotfix aplicado (Cv2MapRail sem any/side-effects) + lint/build OK."