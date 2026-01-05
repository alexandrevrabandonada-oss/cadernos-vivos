# CV — V2 Tijolo D2 — Mapa Dock (Concreto Zen) + integração no MapaV2 — v0_32
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = 'Stop'

$repo = Get-Location
$bootstrap = Join-Path $repo 'tools\_bootstrap.ps1'
if (-not (Test-Path -LiteralPath $bootstrap)) { throw '[STOP] tools/_bootstrap.ps1 não encontrado.' }
. $bootstrap

Write-Host ('[DIAG] Repo: ' + $repo)

$dockPath = Join-Path $repo 'src\components\v2\MapaDockV2.tsx'
$mapaV2Path = Join-Path $repo 'src\components\v2\MapaV2.tsx'

if (-not (Test-Path -LiteralPath $mapaV2Path)) { throw ('[STOP] Não achei: ' + $mapaV2Path) }

EnsureDir (Split-Path -Parent $dockPath)

# 1) Escreve MapaDockV2.tsx (client)
$lines = @(
'"use client";',
'',
'import Link from "next/link";',
'import { useEffect, useMemo, useState } from "react";',
'import type { CSSProperties } from "react";',
'',
'type NodeLite = { id: string; title: string; kind?: string; tags?: string[] };',
'',
'function isRecord(v: unknown): v is Record<string, unknown> {',
'  return typeof v === "object" && v !== null;',
'}',
'function asString(v: unknown): string {',
'  return typeof v === "string" ? v : "";',
'}',
'function asStringArray(v: unknown): string[] {',
'  if (Array.isArray(v)) return v.filter((x) => typeof x === "string") as string[];',
'  if (typeof v === "string") return [v];',
'  return [];',
'}',
'function normNode(v: unknown): NodeLite | null {',
'  if (!isRecord(v)) return null;',
'  const id = asString(v.id) || asString(v.slug) || asString(v.key);',
'  const title = asString(v.title) || asString(v.name) || asString(v.label) || id;',
'  if (!id) return null;',
'  const kind = asString(v.kind) || asString(v.type) || undefined;',
'  const tags = asStringArray(v.tags) ;',
'  return { id, title, kind, tags: tags.length ? tags : undefined };',
'}',
'function collectNodes(mapa: unknown): NodeLite[] {',
'  const out: NodeLite[] = [];',
'  const seen = new Set<string>();',
'',
'  function push(n: NodeLite | null) {',
'    if (!n) return;',
'    if (seen.has(n.id)) return;',
'    seen.add(n.id);',
'    out.push(n);',
'  }',
'',
'  function walk(v: unknown, depth: number) {',
'    if (depth > 6) return;',
'    if (Array.isArray(v)) {',
'      for (const it of v) walk(it, depth + 1);',
'      return;',
'    }',
'    if (!isRecord(v)) return;',
'',
'    // caso clássico: { nodes: [...] }',
'    if (Array.isArray(v.nodes)) {',
'      for (const n of v.nodes) push(normNode(n));',
'    }',
'',
'    // alguns mapas guardam em "items" ou "mapa"',
'    if (Array.isArray(v.items)) {',
'      for (const n of v.items) push(normNode(n));',
'    }',
'',
'    // varre algumas chaves comuns sem explodir tudo',
'    const keys = ["mapa", "data", "panorama", "content", "graph"];',
'    for (const k of keys) {',
'      if (k in v) walk(v[k], depth + 1);',
'    }',
'  }',
'',
'  walk(mapa, 0);',
'',
'  // ordena com calma: kind primeiro (se houver), depois título',
'  out.sort((a, b) => {',
'    const ka = (a.kind || "").toLowerCase();',
'    const kb = (b.kind || "").toLowerCase();',
'    if (ka !== kb) return ka < kb ? -1 : 1;',
'    const ta = a.title.toLowerCase();',
'    const tb = b.title.toLowerCase();',
'    return ta < tb ? -1 : ta > tb ? 1 : 0;',
'  });',
'  return out;',
'}',
'',
'export default function MapaDockV2(props: { slug: string; mapa: unknown }) {',
'  const [open, setOpen] = useState(true);',
'  const [q, setQ] = useState("");',
'  const [copied, setCopied] = useState("");',
'  const [isMobile, setIsMobile] = useState(false);',
'',
'  useEffect(() => {',
'    const calc = () => setIsMobile(window.innerWidth < 980);',
'    calc();',
'    window.addEventListener("resize", calc);',
'    return () => window.removeEventListener("resize", calc);',
'  }, []);',
'',
'  const nodes = useMemo(() => collectNodes(props.mapa), [props.mapa]);',
'  const filtered = useMemo(() => {',
'    const qq = q.trim().toLowerCase();',
'    if (!qq) return nodes.slice(0, 24);',
'    const r = nodes.filter((n) => {',
'      const base = (n.title + " " + n.id + " " + (n.kind || "") + " " + (n.tags ? n.tags.join(" ") : "")).toLowerCase();',
'      return base.includes(qq);',
'    });',
'    return r.slice(0, 24);',
'  }, [nodes, q]);',
'',
'  async function copyLink(id: string) {',
'    try {',
'      const url = window.location.origin + "/c/" + props.slug + "/v2/mapa#" + encodeURIComponent(id);',
'      await navigator.clipboard.writeText(url);',
'      setCopied(id);',
'      setTimeout(() => setCopied(""), 1200);',
'    } catch {',
'      /* noop */',
'    }',
'  }',
'',
'  const shell: CSSProperties = {',
'    background: "rgba(10,10,12,0.88)",',
'    border: "1px solid rgba(255,255,255,0.10)",',
'    borderRadius: 14,',
'    boxShadow: "0 10px 30px rgba(0,0,0,0.35)",',
'    backdropFilter: "blur(10px)",',
'    color: "rgba(255,255,255,0.92)",',
'  };',
'',
'  const wrap: CSSProperties = isMobile',
'    ? { position: "fixed", left: 12, right: 12, bottom: 12, zIndex: 40 }',
'    : { position: "absolute", right: 16, top: 16, width: 360, zIndex: 30 };',
'',
'  const header: CSSProperties = {',
'    display: "flex",',
'    alignItems: "center",',
'    justifyContent: "space-between",',
'    padding: "10px 12px",',
'    borderBottom: "1px solid rgba(255,255,255,0.10)",',
'  };',
'',
'  const btn: CSSProperties = {',
'    border: "1px solid rgba(255,255,255,0.14)",',
'    background: "rgba(255,255,255,0.06)",',
'    borderRadius: 10,',
'    padding: "6px 10px",',
'    cursor: "pointer",',
'    color: "rgba(255,255,255,0.92)",',
'  };',
'',
'  const pill: CSSProperties = {',
'    border: "1px solid rgba(255,255,255,0.14)",',
'    background: "rgba(255,255,255,0.04)",',
'    borderRadius: 999,',
'    padding: "6px 10px",',
'    fontSize: 12,',
'    opacity: 0.95,',
'    textDecoration: "none",',
'    color: "rgba(255,255,255,0.92)",',
'    display: "inline-flex",',
'    gap: 8,',
'    alignItems: "center",',
'  };',
'',
'  return (',
'    <div style={wrap}>',
'      <div style={shell}>',
'        <div style={header}>',
'          <div style={{ display: "flex", flexDirection: "column", gap: 2 }}>',
'            <div style={{ fontWeight: 800, letterSpacing: 0.2 }}>Mapa • Dock</div>',
'            <div style={{ fontSize: 12, opacity: 0.75 }}>atalhos + nós (link #id)</div>',
'          </div>',
'          <button type="button" onClick={() => setOpen((v) => !v)} style={btn}>',
'            {open ? "Fechar" : "Abrir"}',
'          </button>',
'        </div>',
'',
'        {open ? (',
'          <div style={{ padding: 12, display: "flex", flexDirection: "column", gap: 10 }}>',
'            <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>',
'              <Link href={"/c/" + props.slug + "/v2"} style={pill}>⛩️ Home</Link>',
'              <Link href={"/c/" + props.slug + "/v2/provas"} style={pill}>🧾 Provas</Link>',
'              <Link href={"/c/" + props.slug + "/v2/linha"} style={pill}>🧵 Linha</Link>',
'              <Link href={"/c/" + props.slug + "/v2/debate"} style={pill}>💬 Debate</Link>',
'              <Link href={"/c/" + props.slug + "/v2/trilhas"} style={pill}>🧭 Trilhas</Link>',
'            </div>',
'',
'            <div style={{ display: "flex", gap: 8, alignItems: "center" }}>',
'              <input',
'                value={q}',
'                onChange={(e) => setQ(e.target.value)}',
'                placeholder={"Buscar nó (título/id) • " + nodes.length + " nós"}',
'                style={{',
'                  flex: 1,',
'                  borderRadius: 12,',
'                  border: "1px solid rgba(255,255,255,0.12)",',
'                  background: "rgba(0,0,0,0.25)",',
'                  padding: "10px 12px",',
'                  color: "rgba(255,255,255,0.92)",',
'                  outline: "none",',
'                }}',
'              />',
'            </div>',
'',
'            <div style={{ maxHeight: isMobile ? 220 : 360, overflow: "auto", paddingRight: 4 }}>',
'              {filtered.length === 0 ? (',
'                <div style={{ opacity: 0.75, fontSize: 13 }}>Nada encontrado.</div>',
'              ) : (',
'                <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>',
'                  {filtered.map((n) => (',
'                    <div key={n.id} style={{',
'                      border: "1px solid rgba(255,255,255,0.10)",',
'                      borderRadius: 12,',
'                      padding: "10px 10px",',
'                      background: "rgba(255,255,255,0.03)",',
'                      display: "flex",',
'                      gap: 10,',
'                      alignItems: "center",',
'                      justifyContent: "space-between",',
'                    }}>',
'                      <div style={{ minWidth: 0 }}>',
'                        <div style={{ fontWeight: 750, fontSize: 13, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>',
'                          {n.title}',
'                        </div>',
'                        <div style={{ fontSize: 12, opacity: 0.7, display: "flex", gap: 8, flexWrap: "wrap" }}>',
'                          <span style={{ fontFamily: "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace" }}>#{n.id}</span>',
'                          {n.kind ? <span>• {n.kind}</span> : null}',
'                          {n.tags && n.tags.length ? <span>• {n.tags.slice(0, 3).join(", ")}</span> : null}',
'                        </div>',
'                      </div>',
'                      <button type="button" onClick={() => copyLink(n.id)} style={{ ...btn, padding: "6px 10px", fontSize: 12 }}>',
'                        {copied === n.id ? "Copiado" : "Copiar link"}',
'                      </button>',
'                    </div>',
'                  ))}',
'                </div>',
'              )}',
'            </div>',
'',
'            <div style={{ fontSize: 12, opacity: 0.72, lineHeight: 1.3 }}>',
'              Dica: o link copiado já vai com <span style={{ fontFamily: "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace" }}>#id</span>.',
'            </div>',
'          </div>',
'        ) : null}',
'      </div>',
'    </div>',
'  );',
'}'
)

WriteUtf8NoBom $dockPath ($lines -join "`n")
Write-Host ('[OK] wrote: ' + $dockPath)

# 2) Patch MapaV2.tsx: importar + renderizar Dock
$raw = Get-Content -LiteralPath $mapaV2Path -Raw
if ($raw -notmatch 'MapaDockV2') {
  $bk = BackupFile $mapaV2Path

  # 2a) inserir import após último import
  $ls = $raw -split "`r?`n"
  $out = New-Object System.Collections.Generic.List[string]
  $lastImport = -1
  for ($i=0; $i -lt $ls.Length; $i++) {
    if ($ls[$i].TrimStart().StartsWith('import ')) { $lastImport = $i }
  }

  for ($i=0; $i -lt $ls.Length; $i++) {
    $out.Add($ls[$i])
    if ($i -eq $lastImport) {
      $out.Add('import MapaDockV2 from "@/components/v2/MapaDockV2";')
    }
  }

  $raw2 = ($out -join "`n")

  # 2b) inserir render após bloco do MapaCanvasV2 (depois do "/>")
  $ls2 = $raw2 -split "`r?`n"
  $out2 = New-Object System.Collections.Generic.List[string]
  $inCanvas = $false
  $inserted = $false

  # detecta se a função usa props ou destructuring
  $useProps = ($raw2 -match 'function\s+MapaV2\s*\(\s*props') -or ($raw2 -match 'export\s+default\s+function\s+MapaV2\s*\(\s*props')
  $slugExpr = if ($useProps) { 'props.slug' } else { 'slug' }
  $mapaExpr = if ($useProps) { 'props.mapa' } else { 'mapa' }

  foreach ($ln in $ls2) {
    $out2.Add($ln)

    if (-not $inserted) {
      if ($ln -match '<MapaCanvasV2\b') { $inCanvas = $true }
      if ($inCanvas -and ($ln -match '/>\s*$')) {
        $indent = ''
        $m = [regex]::Match($ln, '^(\s*)')
        if ($m.Success) { $indent = $m.Groups[1].Value }
        $out2.Add($indent + '<MapaDockV2 slug={' + $slugExpr + '} mapa={' + $mapaExpr + '} />')
        $inserted = $true
        $inCanvas = $false
      }
    }
  }

  $final = ($out2 -join "`n")
  WriteUtf8NoBom $mapaV2Path $final
  Write-Host ('[OK] patched: ' + $mapaV2Path + ' (import + render Dock)')
  if ($bk) { Write-Host ('[BK] ' + $bk) }
} else {
  Write-Host '[OK] MapaV2 já referencia MapaDockV2 — nada a fazer.'
}

# 3) VERIFY
RunPs1 (Join-Path $repo 'tools\cv-verify.ps1') @()

# 4) REPORT
$report = @(
  '# CV — Tijolo D2 v0_32 — Dock do Mapa V2 (Concreto Zen)',
  '',
  '## O que entrou',
  '- Novo componente client: src/components/v2/MapaDockV2.tsx',
  '- Integração no MapaV2: import + render do Dock (overlay/painel).',
  '',
  '## UX',
  '- Atalhos rápidos: Home/Provas/Linha/Debate/Trilhas',
  '- Busca de nós (título/id) e botão "Copiar link" com #id',
  '- Layout responsivo: mobile (dock fixo), desktop (painel lateral).',
  '',
  '## Verify',
  '- tools/cv-verify.ps1 (Guard → Lint → Build)',
  ''
) -join "`n"

WriteReport 'cv-v2-d2-mapa-dock-v0_32.md' $report | Out-Null
Write-Host '[OK] v0_32 aplicado e verificado.'