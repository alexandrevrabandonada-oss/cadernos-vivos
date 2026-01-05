$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Write-Host ("[DIAG] Repo: " + $repo)

# bootstrap (best-effort)
$bootstrap = Join-Path $PSScriptRoot "_bootstrap.ps1"
if (Test-Path -LiteralPath $bootstrap) { . $bootstrap; Write-Host ("[DIAG] Bootstrap: " + $bootstrap) }

# fallbacks (se bootstrap não carregou)
if (-not (Get-Command EnsureDir -ErrorAction SilentlyContinue)) {
  function EnsureDir([string]$p) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}
if (-not (Get-Command WriteUtf8NoBom -ErrorAction SilentlyContinue)) {
  function WriteUtf8NoBom([string]$p, [string]$t) {
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($p, $t, $enc)
  }
}
if (-not (Get-Command BackupFile -ErrorAction SilentlyContinue)) {
  function BackupFile([string]$p) {
    if (-not (Test-Path -LiteralPath $p)) { return $null }
    $bkDir = Join-Path $repo "tools\_patch_backup"
    EnsureDir $bkDir
    $ts = Get-Date -Format "yyyyMMdd-HHmmss"
    $leaf = Split-Path -Leaf $p
    $bk = Join-Path $bkDir ($ts + "-" + $leaf + ".bak")
    Copy-Item -LiteralPath $p -Destination $bk -Force
    return $bk
  }
}
if (-not (Get-Command RunPs1 -ErrorAction SilentlyContinue)) {
  function RunPs1([string]$p) {
    & $PSHOME\pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $p
    if ($LASTEXITCODE -ne 0) { throw ("[STOP] RunPs1 falhou (exit " + $LASTEXITCODE + "): " + $p) }
  }
}

$changed = New-Object System.Collections.Generic.List[string]

# -----------------------
# 0) PATCH leve: V2Nav (keys + remove i não usado), se necessário
# -----------------------
$navPath = Join-Path $repo "src\components\v2\V2Nav.tsx"
if (Test-Path -LiteralPath $navPath) {
  $raw = Get-Content -LiteralPath $navPath -Raw
  $out = $raw
  $did = $false

  if ($out -match "\.map\(\(\s*it\s*,\s*i\s*\)\s*=>") {
    $out = [regex]::Replace($out, "\.map\(\(\s*it\s*,\s*i\s*\)\s*=>", ".map((it) =>")
    $did = $true
  }

  if ($out -match "key=\{it\.key\}" -and ($out -notmatch "it\.key\s*\+\s*`"")) {
    $out = $out.Replace("key={it.key}", "key={it.key + " + '":"' + " + it.href}")
    $did = $true
  }

  if ($did -and ($out -ne $raw)) {
    $bk = BackupFile $navPath
    WriteUtf8NoBom $navPath $out
    Write-Host ("[OK] patched: " + $navPath)
    if ($bk) { Write-Host ("[BK] " + $bk) }
    $changed.Add($navPath) | Out-Null
  } else {
    Write-Host "[OK] V2Nav: nada pra mudar."
  }
} else {
  Write-Host ("[WARN] V2Nav não encontrado: " + $navPath)
}

# -----------------------
# 1) WRITE: /c/[slug]/v2 (Home V2)
# -----------------------
$pagePath = Join-Path $repo "src\app\c\[slug]\v2\page.tsx"
EnsureDir (Split-Path -Parent $pagePath)

$bk1 = BackupFile $pagePath

$pageLines = @(
  'import Link from "next/link";',
  'import V2Nav from "@/components/v2/V2Nav";',
  'import { loadCadernoV2 } from "@/lib/v2";',
  '',
  'function titleFromMeta(meta: unknown, fallback: string): string {',
  '  if (typeof meta !== "object" || meta === null) return fallback;',
  '  const r = meta as { title?: unknown };',
  '  const t = r.title;',
  '  return typeof t === "string" && t.trim() ? t.trim() : fallback;',
  '}',
  '',
  'function excerptFromMarkdown(md: unknown, maxLen: number): string {',
  '  if (typeof md !== "string") return "";',
  '  const lines = md.split(/\r?\n/).map((s) => s.trim()).filter(Boolean);',
  '  if (!lines.length) return "";',
  '  // pula headings e pega a primeira linha "normal"',
  '  let pick = "";',
  '  for (const ln of lines) {',
  '    if (ln.startsWith("#")) continue;',
  '    pick = ln;',
  '    break;',
  '  }',
  '  if (!pick) pick = lines[0] ?? "";',
  '  if (pick.length > maxLen) return pick.slice(0, maxLen - 1) + "…";',
  '  return pick;',
  '}',
  '',
  'type HotNode = { id: string; title: string; kind?: string };',
  '',
  'function isRecord(v: unknown): v is Record<string, unknown> {',
  '  return typeof v === "object" && v !== null;',
  '}',
  '',
  'function pickString(obj: Record<string, unknown>, keys: string[]): string | undefined {',
  '  for (const k of keys) {',
  '    const v = obj[k];',
  '    if (typeof v === "string" && v.trim()) return v.trim();',
  '  }',
  '  return undefined;',
  '}',
  '',
  'function hotNodesFromMapa(mapa: unknown, limit: number): HotNode[] {',
  '  // aceita mapa.nodes[], ou mapa.items[], ou array direto de nodes',
  '  let arr: unknown[] | undefined;',
  '  if (Array.isArray(mapa)) {',
  '    arr = mapa;',
  '  } else if (isRecord(mapa)) {',
  '    const n = mapa["nodes"];',
  '    const it = mapa["items"];',
  '    if (Array.isArray(n)) arr = n;',
  '    else if (Array.isArray(it)) arr = it;',
  '  }',
  '  if (!arr) return [];',
  '',
  '  const out: HotNode[] = [];',
  '  for (let i = 0; i < arr.length; i++) {',
  '    const v = arr[i];',
  '    if (!isRecord(v)) continue;',
  '    const title = pickString(v, ["title","titulo","name","nome","label"]) ?? ("No " + String(i + 1));',
  '    const id = pickString(v, ["id","slug","key"]) ?? ("no-" + String(i + 1));',
  '    const kind = pickString(v, ["kind","type","tipo","categoria"]);',
  '    out.push({ id, title, kind });',
  '    if (out.length >= limit) break;',
  '  }',
  '  return out;',
  '}',
  '',
  'export default async function Page(props: { params: any }) {',
  '  const slug = (await props.params).slug as string;',
  '  const c = await loadCadernoV2(slug);',
  '',
  '  const meta = (c as unknown as { meta?: unknown }).meta;',
  '  const title = titleFromMeta(meta, slug);',
  '  const pano = (c as unknown as { panoramaMd?: unknown; panorama?: unknown }).panoramaMd ?? (c as unknown as { panorama?: unknown }).panorama;',
  '  const sub = excerptFromMarkdown(pano, 220);',
  '  const mapa = (c as unknown as { mapa?: unknown }).mapa;',
  '  const hot = hotNodesFromMapa(mapa, 6);',
  '',
  '  const Card = (p: { href: string; title: string; desc: string }) => (',
  '    <Link',
  '      href={p.href}',
  '      style={{',
  '        display: "block",',
  '        border: "1px solid rgba(255,255,255,0.12)",',
  '        borderRadius: 16,',
  '        padding: 14,',
  '        background: "rgba(0,0,0,0.22)",',
  '        textDecoration: "none",',
  '        color: "white",',
  '      }}',
  '    >',
  '      <div style={{ fontWeight: 900, letterSpacing: 0.2 }}>{p.title}</div>',
  '      <div style={{ opacity: 0.78, marginTop: 6, lineHeight: 1.35 }}>{p.desc}</div>',
  '    </Link>',
  '  );',
  '',
  '  return (',
  '    <main style={{ padding: 18 }}>',
  '      <V2Nav slug={slug} active="home" />',
  '',
  '      <section style={{ marginTop: 12, border: "1px solid rgba(255,255,255,0.10)", borderRadius: 18, background: "rgba(0,0,0,0.18)", padding: 16 }}>',
  '        <div style={{ display: "flex", justifyContent: "space-between", gap: 12, flexWrap: "wrap", alignItems: "flex-end" }}>',
  '          <div>',
  '            <div style={{ fontSize: 12, opacity: 0.75, letterSpacing: 0.6, textTransform: "uppercase" }}>Caderno V2</div>',
  '            <h1 style={{ margin: "6px 0 0 0", fontSize: 26, letterSpacing: 0.2 }}>{title}</h1>',
  '            {sub ? <div style={{ marginTop: 8, opacity: 0.82, maxWidth: 820, lineHeight: 1.35 }}>{sub}</div> : null}',
  '          </div>',
  '          <div style={{ display: "flex", gap: 10, flexWrap: "wrap" }}>',
  '            <Link href={"/c/" + slug} style={{ textDecoration: "underline", opacity: 0.9 }}>Abrir V1</Link>',
  '            <Link href={"/c/" + slug + "/v2/mapa"} style={{ textDecoration: "underline", opacity: 0.9 }}>Abrir Mapa</Link>',
  '          </div>',
  '        </div>',
  '      </section>',
  '',
  '      <section style={{ marginTop: 14 }}>',
  '        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(240px, 1fr))", gap: 12 }}>',
  '          <Card href={"/c/" + slug + "/v2/mapa"} title="Mapa" desc="Explorar o universo como rede viva: nós, conexões, camadas e foco por hash." />',
  '          <Card href={"/c/" + slug + "/v2/debate"} title="Debate" desc="Discussões e fios de análise — com foco por hash, navegação e continuidade." />',
  '          <Card href={"/c/" + slug + "/v2/provas"} title="Provas" desc="Acervo de evidências: busca local, links, tags e copiar link por item." />',
  '          <Card href={"/c/" + slug + "/v2/linha"} title="Linha do tempo" desc="Linha derivada do mapa: navegar por eventos com foco e contexto." />',
  '          <Card href={"/c/" + slug + "/v2/trilhas"} title="Trilhas" desc="Percursos guiados (quando existir): do básico ao avançado, com aprofundamento." />',
  '        </div>',
  '      </section>',
  '',
  '      <section style={{ marginTop: 16, border: "1px solid rgba(255,255,255,0.10)", borderRadius: 18, background: "rgba(0,0,0,0.16)", padding: 16 }}>',
  '        <div style={{ fontWeight: 900, letterSpacing: 0.2 }}>Fios quentes</div>',
  '        <div style={{ opacity: 0.76, marginTop: 6 }}>Entradas rápidas puxadas do mapa (quando houver nodes). Ideal para chamar o olhar.</div>',
  '',
  '        {hot.length ? (',
  '          <div style={{ marginTop: 12, display: "grid", gap: 10 }}>',
  '            {hot.map((n) => (',
  '              <Link',
  '                key={n.id}',
  '                href={"/c/" + slug + "/v2/mapa#" + n.id}',
  '                style={{',
  '                  display: "block",',
  '                  border: "1px solid rgba(255,255,255,0.10)",',
  '                  borderRadius: 14,',
  '                  padding: 12,',
  '                  background: "rgba(0,0,0,0.22)",',
  '                  textDecoration: "none",',
  '                  color: "white",',
  '                }}',
  '              >',
  '                <div style={{ fontWeight: 800 }}>{n.title}</div>',
  '                <div style={{ opacity: 0.75, marginTop: 4, fontSize: 13 }}>{n.kind ? n.kind : "node"}</div>',
  '              </Link>',
  '            ))}',
  '          </div>',
  '        ) : (',
  '          <div style={{ marginTop: 12, opacity: 0.75, border: "1px dashed rgba(255,255,255,0.16)", borderRadius: 14, padding: 12 }}>',
  '            Ainda não há nodes detectáveis no mapa deste caderno. Assim que você alimentar o mapa.json, essa área acende sozinha.',
  '          </div>',
  '        )}',
  '      </section>',
  '    </main>',
  '  );',
  '}'
)

WriteUtf8NoBom $pagePath ($pageLines -join "`n")
Write-Host ("[OK] wrote: " + $pagePath)
if ($bk1) { Write-Host ("[BK] " + $bk1) }
$changed.Add($pagePath) | Out-Null

# -----------------------
# VERIFY
# -----------------------
$verify = Join-Path $repo "tools\cv-verify.ps1"
if (Test-Path -LiteralPath $verify) {
  Write-Host ("[RUN] " + $verify)
  RunPs1 $verify
} else {
  Write-Host ("[WARN] verify não encontrado: " + $verify)
}

# -----------------------
# REPORT
# -----------------------
$reportsDir = Join-Path $repo "reports"
EnsureDir $reportsDir
$reportPath = Join-Path $reportsDir "cv-v2-tijolo-d1-home-v2-portas-fiosquentes-v0_37.md"

$report = @()
$report += "# CV — V2 Tijolo D1 v0_37 — Home V2"
$report += ""
$report += "## O que entrou"
$report += "- Home V2 em /c/[slug]/v2 com portas para Mapa, Debate, Provas, Linha e Trilhas."
$report += "- Fios quentes: lista de nodes (quando houver) apontando para /v2/mapa#id."
$report += "- Padrao Next 16.1: slug vem de await props.params."
$report += "- Patch leve em V2Nav para reduzir warning de key e remover callback param i se existir."
$report += ""
$report += "## Arquivos"
foreach ($p in $changed) { $report += ("- " + $p) }
$report += ""
$report += "## Verify"
$report += "- tools/cv-verify.ps1 (guard + lint + build)"
$report += ""

WriteUtf8NoBom $reportPath ($report -join "`n")
Write-Host ("[OK] Report: " + $reportPath)
Write-Host "[OK] D1 v0_37 aplicado."