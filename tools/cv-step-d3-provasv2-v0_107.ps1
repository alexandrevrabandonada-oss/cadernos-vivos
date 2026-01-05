$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Write-Host ("[DIAG] Repo: " + $repo)

. (Join-Path $PSScriptRoot "_bootstrap.ps1")

$changed = New-Object System.Collections.Generic.List[string]

function WriteRel([string]$rel, [string[]]$lines) {
  $fp = Join-Path $repo $rel
  EnsureDir (Split-Path -Parent $fp)
  if (Test-Path -LiteralPath $fp) {
    $bk = BackupFile $fp
    Write-Host ("[BK] " + $bk)
  }
  WriteUtf8NoBom $fp ($lines -join "`r`n")
  Write-Host ("[OK] wrote: " + $fp)
  $script:changed.Add($fp) | Out-Null
}

function PatchText([string]$rel, [scriptblock]$mutate) {
  $fp = Join-Path $repo $rel
  if (!(Test-Path -LiteralPath $fp)) {
    Write-Host ("[SKIP] nao achei: " + $fp)
    return
  }
  $raw = Get-Content -LiteralPath $fp -Raw
  if ($null -eq $raw) { throw ("[STOP] leitura nula: " + $fp) }

  $next = & $mutate $raw
  if ($null -eq $next) { throw "[STOP] mutate retornou null" }

  if ($next -ne $raw) {
    $bk = BackupFile $fp
    WriteUtf8NoBom $fp $next
    Write-Host ("[OK] patched: " + $fp)
    Write-Host ("[BK] " + $bk)
    $script:changed.Add($fp) | Out-Null
  } else {
    Write-Host ("[OK] sem mudanca: " + $fp)
  }
}

# ---------------------------
# 1) ProvasV2 component (server-safe)
# Lê:
# - content/cadernos/{slug}/provas.md|mdx|txt
# - ou provas.json (fallback: referencias.json / refs.json)
# ---------------------------
$provasCompLines = @(
  'import Link from "next/link";'
  'import type { CSSProperties } from "react";'
  'import fs from "node:fs/promises";'
  'import path from "node:path";'
  ''
  'type AnyObj = Record<string, unknown>;'
  'type ProofItem = {'
  '  title?: string;'
  '  url?: string;'
  '  source?: string;'
  '  note?: string;'
  '  quote?: string;'
  '  date?: string;'
  '  tags?: string[];'
  '  kind?: string;'
  '};'
  ''
  'async function readOptional(fp: string): Promise<string | null> {'
  '  try { return await fs.readFile(fp, "utf8"); } catch { return null; }'
  '}'
  ''
  'function isObj(v: unknown): v is AnyObj {'
  '  return !!v && typeof v === "object" && !Array.isArray(v);'
  '}'
  ''
  'function s(v: unknown): string {'
  '  if (typeof v === "string") return v;'
  '  if (typeof v === "number") return String(v);'
  '  if (typeof v === "boolean") return v ? "true" : "false";'
  '  return "";'
  '}'
  ''
  'function arrStr(v: unknown): string[] | undefined {'
  '  if (!Array.isArray(v)) return undefined;'
  '  const out = v.map((x) => s(x)).filter(Boolean);'
  '  return out.length ? out : undefined;'
  '}'
  ''
  'function normalizeItem(v: unknown): ProofItem {'
  '  if (!isObj(v)) return { title: s(v) || "Item" };'
  '  const o = v as AnyObj;'
  '  return {'
  '    title: s(o["title"]) || s(o["name"]) || s(o["id"]) || "Item",'
  '    url: s(o["url"]) || s(o["link"]),'
  '    source: s(o["source"]) || s(o["from"]),'
  '    note: s(o["note"]) || s(o["notes"]),'
  '    quote: s(o["quote"]) || s(o["excerpt"]),'
  '    date: s(o["date"]) || s(o["day"]) || s(o["publishedAt"]),'
  '    tags: arrStr(o["tags"]),'
  '    kind: s(o["kind"]) || s(o["type"]),'
  '  };'
  '}'
  ''
  'function pickItems(parsed: unknown): ProofItem[] {'
  '  if (!parsed) return [];'
  '  if (Array.isArray(parsed)) return parsed.map(normalizeItem);'
  '  if (isObj(parsed)) {'
  '    const o = parsed as AnyObj;'
  '    const items = o["items"];'
  '    if (Array.isArray(items)) return items.map(normalizeItem);'
  '    const proofs = o["proofs"];'
  '    if (Array.isArray(proofs)) return proofs.map(normalizeItem);'
  '    const refs = o["refs"];'
  '    if (Array.isArray(refs)) return refs.map(normalizeItem);'
  '  }'
  '  return [];'
  '}'
  ''
  'const card: CSSProperties = {'
  '  border: "1px solid rgba(255,255,255,0.12)",'
  '  borderRadius: 14,'
  '  padding: 14,'
  '  background: "rgba(0,0,0,0.22)",'
  '};'
  ''
  'const btn: CSSProperties = {'
  '  padding: "8px 10px",'
  '  borderRadius: 10,'
  '  border: "1px solid rgba(255,255,255,0.14)",'
  '  textDecoration: "none",'
  '  color: "inherit",'
  '  background: "rgba(255,255,255,0.06)",'
  '  fontSize: 12,'
  '};'
  ''
  'function extLink(url: string): string {'
  '  return url;'
  '}'
  ''
  'export default async function ProvasV2(props: { slug: string; title?: string }) {'
  '  const { slug } = props;'
  '  const root = path.join(process.cwd(), "content", "cadernos", slug);'
  ''
  '  const md ='
  '    (await readOptional(path.join(root, "provas.md"))) ||'
  '    (await readOptional(path.join(root, "provas.mdx"))) ||'
  '    (await readOptional(path.join(root, "provas.txt"))) ||'
  '    (await readOptional(path.join(root, "referencias.md"))) ||'
  '    (await readOptional(path.join(root, "referencias.txt")));'
  ''
  '  const rawJson ='
  '    (await readOptional(path.join(root, "provas.json"))) ||'
  '    (await readOptional(path.join(root, "referencias.json"))) ||'
  '    (await readOptional(path.join(root, "refs.json")));'
  ''
  '  let items: ProofItem[] = [];'
  '  if (rawJson) {'
  '    try {'
  '      items = pickItems(JSON.parse(rawJson) as unknown);'
  '    } catch {'
  '      items = [];'
  '    }'
  '  }'
  ''
  '  const wrap: CSSProperties = { marginTop: 12, display: "grid", gap: 12 };'
  '  const small: CSSProperties = { fontSize: 12, opacity: 0.78 };'
  '  const h2: CSSProperties = { fontSize: 18, fontWeight: 900, letterSpacing: "-0.2px", marginTop: 2 };'
  ''
  '  return ('
  '    <section aria-label="Provas V2" style={wrap}>'
  '      <div style={card}>'
  '        <div style={{ fontSize: 12, opacity: 0.75 }}>Concreto Zen • Provas</div>'
  '        <div style={{ fontSize: 22, fontWeight: 950, letterSpacing: "-0.4px", marginTop: 6 }}>Fontes e evidências</div>'
  '        <div style={{ marginTop: 8, fontSize: 13, opacity: 0.82 }}>'
  '          Aqui entram links, PDFs, matérias, documentos e trechos importantes.'
  '          Alimenta via provas.json (ou referencias.json/refs.json) ou via provas.md.'
  '        </div>'
  '        <div style={{ marginTop: 12, display: "flex", gap: 10, flexWrap: "wrap" }}>'
  '          <Link href={"/c/" + slug + "/referencias"} style={btn}>Abrir Referências V1</Link>'
  '          <Link href={"/c/" + slug + "/v2/mapa"} style={{ ...btn, background: "rgba(0,0,0,0.18)" }}>Ir pro Mapa V2</Link>'
  '        </div>'
  '      </div>'
  ''
  '      {md ? ('
  '        <article style={card}>'
  '          <div style={small}>Fonte: provas.md / referencias.md</div>'
  '          <div style={h2}>Texto-base</div>'
  '          <pre style={{ marginTop: 12, whiteSpace: "pre-wrap", lineHeight: 1.55, fontSize: 13, opacity: 0.92 }}>{md}</pre>'
  '        </article>'
  '      ) : null}'
  ''
  '      {(!md && items.length) ? ('
  '        <article style={card}>'
  '          <div style={small}>Fonte: provas.json / referencias.json</div>'
  '          <div style={h2}>Itens</div>'
  '          <div style={{ display: "grid", gap: 10, marginTop: 12 }}>'
  '            {items.map((it, idx) => {'
  '              const key = (it.url || it.title || String(idx));'
  '              return ('
  '                <div key={key} style={{ padding: 12, borderRadius: 12, border: "1px solid rgba(255,255,255,0.10)", background: "rgba(0,0,0,0.18)" }}>'
  '                  <div style={{ display: "flex", gap: 10, flexWrap: "wrap", alignItems: "baseline" }}>'
  '                    <div style={{ fontSize: 14, fontWeight: 850 }}>{it.title || "Item"}</div>'
  '                    {it.kind ? <div style={{ fontSize: 11, opacity: 0.75 }}>({it.kind})</div> : null}'
  '                    {it.date ? <div style={{ fontSize: 11, opacity: 0.75 }}>{it.date}</div> : null}'
  '                  </div>'
  '                  {it.source ? <div style={{ marginTop: 6, fontSize: 12, opacity: 0.78 }}>Fonte: {it.source}</div> : null}'
  '                  {it.quote ? <div style={{ marginTop: 8, fontSize: 13, opacity: 0.9, whiteSpace: "pre-wrap" }}>{it.quote}</div> : null}'
  '                  {it.note ? <div style={{ marginTop: 8, fontSize: 13, opacity: 0.86, whiteSpace: "pre-wrap" }}>{it.note}</div> : null}'
  '                  {it.tags && it.tags.length ? ('
  '                    <div style={{ marginTop: 8, display: "flex", gap: 6, flexWrap: "wrap" }}>'
  '                      {it.tags.map((t) => ('
  '                        <span key={t} style={{ fontSize: 11, padding: "3px 8px", borderRadius: 999, border: "1px solid rgba(255,255,255,0.12)", opacity: 0.8 }}>{t}</span>'
  '                      ))}'
  '                    </div>'
  '                  ) : null}'
  '                  {it.url ? ('
  '                    <div style={{ marginTop: 10 }}>'
  '                      <a href={extLink(it.url)} target="_blank" rel="noreferrer" style={{ ...btn, display: "inline-flex" }}>Abrir link</a>'
  '                    </div>'
  '                  ) : null}'
  '                </div>'
  '              );'
  '            })}'
  '          </div>'
  '        </article>'
  '      ) : null}'
  ''
  '      {(!md && items.length === 0) ? ('
  '        <div style={card}>'
  '          <div style={h2}>Ainda vazio</div>'
  '          <div style={{ marginTop: 8, fontSize: 13, opacity: 0.82 }}>'
  '            Crie content/cadernos/{slug}/provas.json (ou referencias.json) ou provas.md para alimentar esta tela.'
  '          </div>'
  '        </div>'
  '      ) : null}'
  '    </section>'
  '  );'
  '}'
)

WriteRel "src\components\v2\ProvasV2.tsx" $provasCompLines

# ---------------------------
# 2) /v2/provas page
# ---------------------------
$provasPageLines = @(
  'import { getCaderno } from "@/lib/cadernos";'
  'import V2Nav from "@/components/v2/V2Nav";'
  'import ProvasV2 from "@/components/v2/ProvasV2";'
  ''
  'type SlugParams = { slug: string };'
  ''
  'async function getSlug(params: unknown): Promise<string> {'
  '  const p = (await Promise.resolve(params)) as Partial<SlugParams>;'
  '  return typeof p?.slug === "string" ? p.slug : "";'
  '}'
  ''
  'export default async function Page({ params }: { params: unknown }) {'
  '  const slug = await getSlug(params);'
  '  const caderno = await getCaderno(slug);'
  '  const title = (caderno && (caderno as unknown as { title?: string }).title) ? (caderno as unknown as { title: string }).title : slug;'
  ''
  '  return ('
  '    <main style={{ padding: 18, maxWidth: 1100, margin: "0 auto" }}>'
  '      <V2Nav slug={slug} active="provas" />'
  '      <div style={{ marginTop: 12 }}>'
  '        <ProvasV2 slug={slug} title={title} />'
  '      </div>'
  '    </main>'
  '  );'
  '}'
)

WriteRel "src\app\c\[slug]\v2\provas\page.tsx" $provasPageLines

# ---------------------------
# 3) Limpar "as any" do V2Nav (se existir)
# ---------------------------
PatchText "src\app\c\[slug]\v2\debate\page.tsx" {
  param($s)
  $out = $s
  $out = $out.Replace('active={"debate" as any}', 'active="debate"')
  return $out
}
PatchText "src\app\c\[slug]\v2\linha\page.tsx" {
  param($s)
  $out = $s
  $out = $out.Replace('active={"linha" as any}', 'active="linha"')
  return $out
}
PatchText "src\app\c\[slug]\v2\page.tsx" {
  param($s)
  $out = $s
  $out = $out.Replace('active={"mapa" as any}', 'active="mapa"')
  return $out
}

# ---------------------------
# 4) Opcional: garantir card "Provas" no HomeV2Hub (se por algum motivo não tiver)
# (na tua versão atual ele já tem, então aqui só confirma)
# ---------------------------
PatchText "src\components\v2\HomeV2Hub.tsx" {
  param($s)
  $out = $s
  if ($out.IndexOf('/v2/provas') -ge 0) { return $out }
  return $out
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Step D3 — ProvasV2 (v0_107)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que entrou") | Out-Null
$rep.Add("- Nova rota: /c/[slug]/v2/provas") | Out-Null
$rep.Add("- Componente: ProvasV2 (server-safe; lê provas.md|referencias.md ou provas.json|referencias.json|refs.json)") | Out-Null
$rep.Add("- Limpou active=... as any em páginas V2 (se existia).") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null
$rp = WriteReport "cv-step-d3-provasv2-v0_107.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] D3 aplicado e verificado."