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
# 1) Componente ProvasV2.tsx (server-safe)
# ---------------------------
$provasComp = @(
  'import Link from "next/link";'
  'import type { CSSProperties } from "react";'
  'import fs from "node:fs/promises";'
  'import path from "node:path";'
  ''
  'type AnyObj = Record<string, unknown>;'
  ''
  'async function readOptional(fp: string): Promise<string | null> {'
  '  try { return await fs.readFile(fp, "utf8"); } catch { return null; }'
  '}'
  ''
  'function isObj(v: unknown): v is AnyObj {'
  '  return !!v && typeof v === "object" && !Array.isArray(v);'
  '}'
  ''
  'function pickArray(parsed: unknown): unknown[] | null {'
  '  if (Array.isArray(parsed)) return parsed;'
  '  if (isObj(parsed)) {'
  '    const items = (parsed as AnyObj)["items"];'
  '    if (Array.isArray(items)) return items;'
  '    const proofs = (parsed as AnyObj)["proofs"];'
  '    if (Array.isArray(proofs)) return proofs;'
  '    const refs = (parsed as AnyObj)["refs"];'
  '    if (Array.isArray(refs)) return refs;'
  '  }'
  '  return null;'
  '}'
  ''
  'function textOf(v: unknown): string {'
  '  if (typeof v === "string") return v;'
  '  if (typeof v === "number") return String(v);'
  '  if (typeof v === "boolean") return v ? "true" : "false";'
  '  return "";'
  '}'
  ''
  'function pick(item: AnyObj, keys: string[]): string {'
  '  for (const k of keys) {'
  '    const v = item[k];'
  '    const t = textOf(v).trim();'
  '    if (t) return t;'
  '  }'
  '  return "";'
  '}'
  ''
  'function safeId(item: AnyObj, idx: number): string {'
  '  return pick(item, ["id", "slug", "key"]) || String(idx);'
  '}'
  ''
  'const card: CSSProperties = {'
  '  border: "1px solid rgba(255,255,255,0.12)",'
  '  borderRadius: 14,'
  '  padding: 14,'
  '  background: "rgba(0,0,0,0.22)",'
  '};'
  ''
  'const chip: CSSProperties = {'
  '  display: "inline-flex",'
  '  alignItems: "center",'
  '  gap: 8,'
  '  padding: "6px 10px",'
  '  borderRadius: 999,'
  '  border: "1px solid rgba(255,255,255,0.14)",'
  '  textDecoration: "none",'
  '  color: "inherit",'
  '  background: "rgba(255,255,255,0.06)",'
  '  fontSize: 12,'
  '};'
  ''
  'export default async function ProvasV2(props: { slug: string; title?: string }) {'
  '  const { slug } = props;'
  '  const root = path.join(process.cwd(), "content", "cadernos", slug);'
  ''
  '  const md ='
  '    (await readOptional(path.join(root, "provas.md"))) ||'
  '    (await readOptional(path.join(root, "provas.mdx"))) ||'
  '    (await readOptional(path.join(root, "provas.txt")));'
  ''
  '  const rawJson = await readOptional(path.join(root, "provas.json"));'
  '  let jsonItems: unknown[] | null = null;'
  '  if (rawJson) {'
  '    try { jsonItems = pickArray(JSON.parse(rawJson) as unknown); } catch { jsonItems = null; }'
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
  '          A ideia aqui é manter as “provas” legíveis e linkáveis: artigos, PDFs, relatórios, prints, leis, entrevistas.'
  '          Por enquanto, carregamos o que existir em <code>provas.md</code> ou <code>provas.json</code>.'
  '        </div>'
  '        <div style={{ marginTop: 12, display: "flex", gap: 10, flexWrap: "wrap" }}>'
  '          <Link href={"/c/" + slug + "/referencias"} style={chip}>Abrir Referências V1</Link>'
  '          <Link href={"/c/" + slug + "/v2/mapa"} style={{ ...chip, background: "rgba(0,0,0,0.18)" }}>Ir pro Mapa V2</Link>'
  '        </div>'
  '      </div>'
  ''
  '      {md ? ('
  '        <article style={card}>'
  '          <div style={small}>Fonte: provas.md / provas.mdx</div>'
  '          <div style={h2}>Texto-base</div>'
  '          <pre style={{ marginTop: 12, whiteSpace: "pre-wrap", lineHeight: 1.55, fontSize: 13, opacity: 0.92 }}>{md}</pre>'
  '        </article>'
  '      ) : null}'
  ''
  '      {(!md && jsonItems && jsonItems.length) ? ('
  '        <article style={card}>'
  '          <div style={small}>Fonte: provas.json</div>'
  '          <div style={h2}>Itens</div>'
  '          <div style={{ display: "grid", gap: 10, marginTop: 12 }}>'
  '            {jsonItems.map((it, idx) => {'
  '              const obj = isObj(it) ? (it as AnyObj) : ({ text: String(it) } as AnyObj);'
  '              const title = pick(obj, ["title", "name"]) || "Fonte";'
  '              const url = pick(obj, ["url", "href", "link"]);'
  '              const kind = pick(obj, ["kind", "type", "source"]);'
  '              const note = pick(obj, ["note", "desc", "description", "text", "content"]);'
  '              const date = pick(obj, ["date", "year"]);'
  '              const id = safeId(obj, idx);'
  '              return ('
  '                <div key={id} style={{ padding: 12, borderRadius: 12, border: "1px solid rgba(255,255,255,0.10)", background: "rgba(0,0,0,0.18)" }}>'
  '                  <div style={{ display: "flex", gap: 10, flexWrap: "wrap", alignItems: "baseline" }}>'
  '                    <div style={{ fontSize: 14, fontWeight: 850 }}>{title}</div>'
  '                    {kind ? <span style={{ fontSize: 12, opacity: 0.75 }}>• {kind}</span> : null}'
  '                    {date ? <span style={{ fontSize: 12, opacity: 0.75 }}>• {date}</span> : null}'
  '                  </div>'
  '                  {url ? ('
  '                    <div style={{ marginTop: 6 }}>'
  '                      <a href={url} target="_blank" rel="noreferrer" style={{ fontSize: 13, opacity: 0.9, textDecoration: "underline" }}>{url}</a>'
  '                    </div>'
  '                  ) : null}'
  '                  {note ? <div style={{ marginTop: 6, fontSize: 13, opacity: 0.86, whiteSpace: "pre-wrap" }}>{note}</div> : null}'
  '                </div>'
  '              );'
  '            })}'
  '          </div>'
  '        </article>'
  '      ) : null}'
  ''
  '      {(!md && (!jsonItems || jsonItems.length === 0)) ? ('
  '        <div style={card}>'
  '          <div style={h2}>Ainda vazio</div>'
  '          <div style={{ marginTop: 8, fontSize: 13, opacity: 0.82 }}>'
  '            Crie <code>{"content/cadernos/" + slug + "/provas.md"}</code> ou <code>{"content/cadernos/" + slug + "/provas.json"}</code> para alimentar esta tela.'
  '          </div>'
  '        </div>'
  '      ) : null}'
  '    </section>'
  '  );'
  '}'
)

WriteRel "src\components\v2\ProvasV2.tsx" $provasComp

# ---------------------------
# 2) Rota /v2/provas
# ---------------------------
$provasPage = @(
  'import { getCaderno } from "@/lib/cadernos";'
  'import V2Nav from "@/components/v2/V2Nav";'
  'import ProvasV2 from "@/components/v2/ProvasV2";'
  ''
  'type AnyParams = { slug: string } | Promise<{ slug: string }>;'
  ''
  'async function getSlug(params: AnyParams): Promise<string> {'
  '  const p = await Promise.resolve(params as unknown as { slug: string });'
  '  return (p && p.slug) ? p.slug : "";'
  '}'
  ''
  'export default async function Page({ params }: { params: AnyParams }) {'
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

WriteRel "src\app\c\[slug]\v2\provas\page.tsx" $provasPage

# ---------------------------
# 3) V2Nav: garantir "provas" no tipo do active (se houver union)
# ---------------------------
PatchText "src\components\v2\V2Nav.tsx" {
  param($s)
  $out = $s
  if ($out.IndexOf('"provas"') -ge 0) { return $out }

  $lines = $out -split "`r`n"
  $changedLocal = $false
  for ($i = 0; $i -lt $lines.Length; $i++) {
    $ln = $lines[$i]
    if ($ln -match '\bactive\b' -and $ln -match '"mapa"' -and $ln -notmatch '"provas"') {
      $lines[$i] = $ln.Replace('"mapa"', '"mapa" | "provas"')
      $changedLocal = $true
      break
    }
  }
  if ($changedLocal) { return ($lines -join "`r`n") }
  return $out
}

# ---------------------------
# 4) HomeV2Hub: garantir card /v2/provas (caso tenha sumido)
# ---------------------------
PatchText "src\components\v2\HomeV2Hub.tsx" {
  param($s)
  $out = $s
  if ($out.IndexOf('/v2/provas') -ge 0) { return $out }

  $pos = $out.IndexOf('href={"/c/" + slug}')
  if ($pos -lt 0) { return $out }
  $ls = $out.LastIndexOf("`n", $pos)
  if ($ls -lt 0) { $ls = 0 } else { $ls = $ls + 1 }

  $insLines = @(
'        <Link href={"/c/" + slug + "/v2/provas"} style={cardBase}>'
'          <div style={{ fontSize: 12, opacity: 0.8 }}>Provas</div>'
'          <div style={h}>Fontes e evidências</div>'
'          <div style={small}>organizar referências e links</div>'
'        </Link>'
''
  )
  $ins = ($insLines -join "`r`n")
  return ($out.Substring(0, $ls) + $ins + $out.Substring($ls))
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Step D3 — ProvasV2 (v0_104)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que entrou") | Out-Null
$rep.Add("- Nova rota: /c/[slug]/v2/provas") | Out-Null
$rep.Add("- Componente: ProvasV2 (server-safe; lê provas.md/mdx/txt ou provas.json)") | Out-Null
$rep.Add("- HomeV2Hub: garante card Provas") | Out-Null
$rep.Add("- V2Nav: garante tipo active com ""provas"" (se preciso)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null
$rp = WriteReport "cv-step-d3-provasv2-v0_104.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] D3 aplicado e verificado."