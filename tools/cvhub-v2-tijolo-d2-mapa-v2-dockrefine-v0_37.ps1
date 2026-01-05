# CV — V2 Tijolo D2 — Mapa V2 (integra Dock) + hotfix setState-in-effect + lint polish — v0_37
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

$repo = Get-Location
$bootstrap = Join-Path $repo "tools\_bootstrap.ps1"
if (-not (Test-Path -LiteralPath $bootstrap)) { throw "[STOP] tools/_bootstrap.ps1 não encontrado." }
. $bootstrap

Write-Host ("[DIAG] Repo: " + $repo)

$mapaV2Path  = Join-Path $repo "src\components\v2\MapaV2.tsx"
$dockPath    = Join-Path $repo "src\components\v2\MapaDockV2.tsx"
$slugPage    = Join-Path $repo "src\app\c\[slug]\page.tsx"

# --- PATCH 1: MapaDockV2 — remover setState no corpo do effect (lint react-hooks/set-state-in-effect) ---
if (Test-Path -LiteralPath $dockPath) {
  Write-Host ("[DIAG] Dock: " + $dockPath)
  $raw = Get-Content -LiteralPath $dockPath -Raw
  $lines = $raw -split "`r?`n"
  $out = New-Object System.Collections.Generic.List[string]
  $changed = $false

  foreach ($ln in $lines) {
    $line = $ln

    # 1) init do estado: useState(... "" ...) -> useState(() => readHashId())
    if ($line -match "useState<([^>]+)>\(\s*`"`"\s*\)") {
      $t = $Matches[1]
      $line = $line -replace "useState<[^>]+>\(\s*`"`"\s*\)", ("useState<" + $t + ">(() => readHashId())")
      $changed = $true
    }

    # 2) remover linha de init dentro do effect (mas NÃO remover handlers com =>)
    if (($line -match "setSelectedId\(readHashId\(\)\)") -and (-not ($line -like "*=>*"))) {
      $changed = $true
      continue
    }
    if (($line -match "setTimeout\(\(\)\s*=>\s*setSelectedId\(readHashId\(\)\)") ) {
      $changed = $true
      continue
    }

    $out.Add($line)
  }

  if ($changed) {
    $bk = BackupFile $dockPath
    WriteUtf8NoBom $dockPath ($out -join "`n")
    Write-Host "[OK] patched: MapaDockV2.tsx (init via useState(() => readHashId()); sem setState no corpo do effect)"
    if ($bk) { Write-Host ("[BK] " + $bk) }
  } else {
    Write-Host "[OK] MapaDockV2: no change (padrões não encontrados)."
  }
} else {
  Write-Host "[SKIP] MapaDockV2 não encontrado."
}

# --- PATCH 2: MapaV2 — reescrever com layout Dock + área principal (placeholder útil) ---
EnsureDir (Split-Path -Parent $mapaV2Path)
$bkMap = BackupFile $mapaV2Path

$mapLines = @(
'"use client";',
'',
'import React, { useMemo } from "react";',
'import Link from "next/link";',
'import MapaDockV2 from "@/components/v2/MapaDockV2";',
'',
'type Node = {',
'  id: string;',
'  title: string;',
'  kind: string;',
'  tags: string[];',
'};',
'',
'type Props = {',
'  slug: string;',
'  mapa: unknown;',
'  title?: string;',
'};',
'',
'function asRecord(v: unknown): Record<string, unknown> | null {',
'  if (!v || typeof v !== "object") return null;',
'  return v as Record<string, unknown>;',
'}',
'',
'function asArray(v: unknown): unknown[] | null {',
'  return Array.isArray(v) ? v : null;',
'}',
'',
'function asString(v: unknown): string | null {',
'  return typeof v === "string" ? v : null;',
'}',
'',
'function pickId(o: Record<string, unknown>, fallback: string): string {',
'  const a = asString(o["id"]);',
'  if (a) return a;',
'  const b = asString(o["slug"]);',
'  if (b) return b;',
'  const c = asString(o["key"]);',
'  if (c) return c;',
'  return fallback;',
'}',
'',
'function pickTitle(o: Record<string, unknown>, id: string): string {',
'  const a = asString(o["title"]);',
'  if (a) return a;',
'  const b = asString(o["label"]);',
'  if (b) return b;',
'  const c = asString(o["name"]);',
'  if (c) return c;',
'  return id;',
'}',
'',
'function pickKind(o: Record<string, unknown>): string {',
'  const a = asString(o["type"]);',
'  if (a) return a;',
'  const b = asString(o["kind"]);',
'  if (b) return b;',
'  return "node";',
'}',
'',
'function pickTags(o: Record<string, unknown>): string[] {',
'  const t = o["tags"];',
'  const arr = asArray(t);',
'  if (arr) {',
'    const out: string[] = [];',
'    for (let i = 0; i < arr.length; i++) {',
'      const s = asString(arr[i]);',
'      if (s) out.push(s);',
'    }',
'    return out.slice(0, 12);',
'  }',
'  const one = asString(o["tag"]);',
'  return one ? [one] : [];',
'}',
'',
'function extractNodes(mapa: unknown): Node[] {',
'  let items: unknown[] = [];',
'  const ma = asArray(mapa);',
'  if (ma) items = ma;',
'  const mr = asRecord(mapa);',
'  if (mr) {',
'    const nodes = asArray(mr["nodes"]);',
'    if (nodes) items = nodes;',
'  }',
'',
'  const out: Node[] = [];',
'  for (let i = 0; i < items.length; i++) {',
'    const o = asRecord(items[i]);',
'    if (!o) continue;',
'    const id = pickId(o, "n-" + i);',
'    const title = pickTitle(o, id);',
'    const kind = pickKind(o);',
'    const tags = pickTags(o);',
'    out.push({ id, title, kind, tags });',
'    if (out.length >= 250) break;',
'  }',
'  return out;',
'}',
'',
'export default function MapaV2(props: Props) {',
'  const slug = props.slug;',
'  const mapa = props.mapa;',
'  const title = props.title ? props.title : slug;',
'  const baseV2 = "/c/" + slug + "/v2";',
'',
'  const nodes = useMemo(() => extractNodes(mapa), [mapa]);',
'',
'  // Dock props: passamos slug/title/mapa (e fazemos cast p/ não brigar com assinatura do Dock)',
'  const dockProps = { slug, title, mapa };',
'',
'  return (',
'    <section style={{ display: "flex", gap: 12, alignItems: "stretch" }}>',
'      <div style={{ width: 420, maxWidth: "48vw" }}>',
'        <MapaDockV2 {...(dockProps as unknown as Parameters<typeof MapaDockV2>[0])} />',
'      </div>',
'',
'      <main style={{ flex: 1, minWidth: 0 }}>',
'        <div',
'          style={{',
'            border: "1px solid rgba(255,255,255,0.08)",',
'            background: "rgba(255,255,255,0.03)",',
'            borderRadius: 14,',
'            padding: 14,',
'            minHeight: "calc(100vh - 110px)",',
'          }}',
'        >',
'          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", gap: 10, flexWrap: "wrap" }}>',
'            <div>',
'              <div style={{ fontSize: 12, opacity: 0.85 }}>Mapa (V2)</div>',
'              <div style={{ fontSize: 20, fontWeight: 900, letterSpacing: 0.2 }}>{title}</div>',
'            </div>',
'            <div style={{ display: "flex", gap: 10, flexWrap: "wrap" }}>',
'              <Link href={baseV2 + "/provas"} style={{ textDecoration: "underline", opacity: 0.95 }}>Provas</Link>',
'              <Link href={baseV2 + "/debate"} style={{ textDecoration: "underline", opacity: 0.95 }}>Debate</Link>',
'              <Link href={baseV2 + "/linha"} style={{ textDecoration: "underline", opacity: 0.95 }}>Linha</Link>',
'            </div>',
'          </div>',
'',
'          <div style={{ height: 12 }} />',
'',
'          <div style={{ fontSize: 12, opacity: 0.85, lineHeight: 1.5 }}>',
'            Canvas do mapa (V2) entra aqui. Por enquanto, este painel já serve como “visão do mapa”: cards por nó com âncora (#id),',
'            e o Dock à esquerda resolve navegação/seleção.',
'          </div>',
'',
'          <div style={{ height: 12 }} />',
'',
'          {nodes.length === 0 ? (',
'            <div style={{ opacity: 0.85, lineHeight: 1.6 }}>Nenhum nó detectado no mapa. (Esperado: mapa.nodes[])</div>',
'          ) : (',
'            <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>',
'              {nodes.map((n) => (',
'                <div',
'                  key={n.id}',
'                  id={n.id}',
'                  style={{',
'                    border: "1px solid rgba(255,255,255,0.10)",',
'                    background: "rgba(0,0,0,0.20)",',
'                    borderRadius: 14,',
'                    padding: 12,',
'                  }}',
'                >',
'                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", gap: 10, flexWrap: "wrap" }}>',
'                    <div>',
'                      <div style={{ fontWeight: 900, fontSize: 16, lineHeight: 1.25 }}>{n.title}</div>',
'                      <div style={{ fontSize: 12, opacity: 0.75, marginTop: 4 }}>{n.kind} · {n.id}</div>',
'                    </div>',
'                    <div style={{ display: "flex", gap: 10, flexWrap: "wrap" }}>',
'                      <a href={"#" + n.id} style={{ textDecoration: "underline", opacity: 0.95 }}>#</a>',
'                      <Link href={baseV2 + "/provas#" + n.id} style={{ textDecoration: "underline", opacity: 0.95 }}>Provas</Link>',
'                      <Link href={baseV2 + "/debate"} style={{ textDecoration: "underline", opacity: 0.95 }}>Debate</Link>',
'                    </div>',
'                  </div>',
'',
'                  {n.tags.length > 0 ? (',
'                    <div style={{ marginTop: 10, display: "flex", gap: 8, flexWrap: "wrap" }}>',
'                      {n.tags.map((t) => (',
'                        <span',
'                          key={t}',
'                          style={{',
'                            fontSize: 12,',
'                            padding: "4px 8px",',
'                            borderRadius: 999,',
'                            border: "1px solid rgba(255,255,255,0.10)",',
'                            background: "rgba(255,255,255,0.05)",',
'                            opacity: 0.95,',
'                          }}',
'                        >',
'                          {t}',
'                        </span>',
'                      ))}',
'                    </div>',
'                  ) : null}',
'                </div>',
'              ))}',
'            </div>',
'          )}',
'        </div>',
'      </main>',
'    </section>',
'  );',
'}'
)

WriteLinesUtf8NoBom $mapaV2Path $mapLines
Write-Host ("[OK] wrote: " + $mapaV2Path)
if ($bkMap) { Write-Host ("[BK] " + $bkMap) }

# --- PATCH 3: remover import redirect não usado (warning) ---
if (Test-Path -LiteralPath $slugPage) {
  $praw = Get-Content -LiteralPath $slugPage -Raw
  if (($praw -match "redirect") -and (-not ($praw -match "redirect\("))) {
    $plines = $praw -split "`r?`n"
    $pout = New-Object System.Collections.Generic.List[string]
    $pchanged = $false
    foreach ($ln in $plines) {
      if ($ln -match "import\s*\{\s*redirect\s*\}\s*from\s*['""]next/navigation['""]") {
        $pchanged = $true
        continue
      }
      $pout.Add($ln)
    }
    if ($pchanged) {
      $bkP = BackupFile $slugPage
      WriteUtf8NoBom $slugPage ($pout -join "`n")
      Write-Host "[OK] patched: removeu import redirect não usado"
      if ($bkP) { Write-Host ("[BK] " + $bkP) }
    } else {
      Write-Host "[OK] slug page: sem change (import não encontrado)."
    }
  } else {
    Write-Host "[OK] slug page: redirect usado ou não presente."
  }
}

# VERIFY
RunPs1 (Join-Path $repo "tools\cv-verify.ps1") @()

# REPORT
$report = @(
  "# CV — Tijolo D2 v0_37 — Mapa V2 + Dock + lint polish",
  "",
  "## O que mudou",
  "- src/components/v2/MapaV2.tsx: layout flex com Dock (esq.) + painel principal (dir.) com cards por nó (#id) e links p/ Provas/Debate.",
  "- src/components/v2/MapaDockV2.tsx: remove setState do corpo do useEffect (init via useState(() => readHashId())).",
  "- src/app/c/[slug]/page.tsx: remove import redirect não usado (quando aplicável).",
  "",
  "## Verify",
  "- tools/cv-verify.ps1 (Guard → Lint → Build)",
  ""
) -join "`n"
WriteReport "cv-v2-tijolo-d2-mapa-v2-dockrefine-v0_37.md" $report | Out-Null
Write-Host "[OK] D2 v0_37 aplicado e verificado."