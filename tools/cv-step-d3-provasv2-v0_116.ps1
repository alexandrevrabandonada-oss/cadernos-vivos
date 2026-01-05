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
# ---------------------------
$provasComp = @(
  'import type { CSSProperties } from "react";',
  'import fs from "node:fs/promises";',
  'import path from "node:path";',
  '',
  'type AnyObj = Record<string, unknown>;',
  '',
  'async function readOptional(fp: string): Promise<string | null> {',
  '  try { return await fs.readFile(fp, "utf8"); } catch { return null; }',
  '}',
  '',
  'function isObj(v: unknown): v is AnyObj {',
  '  return !!v && typeof v === "object" && !Array.isArray(v);',
  '}',
  '',
  'function pickArray(parsed: unknown): unknown[] | null {',
  '  if (Array.isArray(parsed)) return parsed;',
  '  if (isObj(parsed)) {',
  '    const items = parsed["items"];',
  '    if (Array.isArray(items)) return items;',
  '    const proofs = parsed["proofs"];',
  '    if (Array.isArray(proofs)) return proofs;',
  '    const sources = parsed["sources"];',
  '    if (Array.isArray(sources)) return sources;',
  '    const refs = parsed["refs"];',
  '    if (Array.isArray(refs)) return refs;',
  '  }',
  '  return null;',
  '}',
  '',
  'function textOf(v: unknown): string {',
  '  if (typeof v === "string") return v;',
  '  if (typeof v === "number") return String(v);',
  '  if (typeof v === "boolean") return v ? "true" : "false";',
  '  return "";',
  '}',
  '',
  'function safeTitle(item: AnyObj, idx: number): string {',
  '  const t = textOf(item["title"]) || textOf(item["name"]) || textOf(item["label"]);',
  '  return t || ("Fonte " + String(idx + 1));',
  '}',
  '',
  'function safeUrl(item: AnyObj): string {',
  '  const u = textOf(item["url"]) || textOf(item["href"]) || textOf(item["link"]);',
  '  return u;',
  '}',
  '',
  'function safeNote(item: AnyObj): string {',
  '  const n = textOf(item["note"]) || textOf(item["desc"]) || textOf(item["summary"]) || textOf(item["text"]);',
  '  return n;',
  '}',
  '',
  'function safeKind(item: AnyObj): string {',
  '  const k = textOf(item["kind"]) || textOf(item["type"]) || textOf(item["categoria"]);',
  '  return k;',
  '}',
  '',
  'const card: CSSProperties = {',
  '  border: "1px solid rgba(255,255,255,0.12)",',
  '  borderRadius: 14,',
  '  padding: 14,',
  '  background: "rgba(0,0,0,0.22)",',
  '};',
  '',
  'export default async function ProvasV2(props: { slug: string; title?: string }) {',
  '  const { slug } = props;',
  '  const root = path.join(process.cwd(), "content", "cadernos", slug);',
  '',
  '  const md =',
  '    (await readOptional(path.join(root, "provas.md"))) ||',
  '    (await readOptional(path.join(root, "provas.mdx"))) ||',
  '    (await readOptional(path.join(root, "provas.txt")));',
  '',
  '  const rawJson = await readOptional(path.join(root, "provas.json"));',
  '  let jsonItems: unknown[] | null = null;',
  '  if (rawJson) {',
  '    try { jsonItems = pickArray(JSON.parse(rawJson) as unknown); } catch { jsonItems = null; }',
  '  }',
  '',
  '  const wrap: CSSProperties = { marginTop: 12, display: "grid", gap: 12 };',
  '  const small: CSSProperties = { fontSize: 12, opacity: 0.78 };',
  '  const h2: CSSProperties = { fontSize: 18, fontWeight: 900, letterSpacing: "-0.2px", marginTop: 2 };',
  '',
  '  return (',
  '    <section aria-label="Provas V2" style={wrap}>',
  '      <div style={card}>',
  '        <div style={{ fontSize: 12, opacity: 0.75 }}>Concreto Zen • Provas</div>',
  '        <div style={{ fontSize: 22, fontWeight: 950, letterSpacing: "-0.4px", marginTop: 6 }}>Fontes e evidências</div>',
  '        <div style={{ marginTop: 8, fontSize: 13, opacity: 0.82 }}>',
  '          Aqui entram links, documentos, prints, artigos e qualquer evidência que sustenta o caderno.',
  '          Por enquanto, carregamos o que existir em <code>provas.md</code> ou <code>provas.json</code>.',
  '        </div>',
  '      </div>',
  '',
  '      {md ? (',
  '        <article style={card}>',
  '          <div style={small}>Fonte: provas.md / provas.mdx</div>',
  '          <div style={h2}>Texto-base</div>',
  '          <pre style={{ marginTop: 12, whiteSpace: "pre-wrap", lineHeight: 1.55, fontSize: 13, opacity: 0.92 }}>{md}</pre>',
  '        </article>',
  '      ) : null}',
  '',
  '      {(!md && jsonItems && jsonItems.length) ? (',
  '        <article style={card}>',
  '          <div style={small}>Fonte: provas.json</div>',
  '          <div style={h2}>Itens</div>',
  '          <div style={{ display: "grid", gap: 10, marginTop: 12 }}>',
  '            {jsonItems.map((it, idx) => {',
  '              const obj: AnyObj = isObj(it) ? (it as AnyObj) : ({ text: String(it) } as AnyObj);',
  '              const title = safeTitle(obj, idx);',
  '              const url = safeUrl(obj);',
  '              const note = safeNote(obj);',
  '              const kind = safeKind(obj);',
  '              const key = String(obj["id"] || obj["key"] || idx);',
  '              return (',
  '                <div key={key} style={{ padding: 12, borderRadius: 12, border: "1px solid rgba(255,255,255,0.10)", background: "rgba(0,0,0,0.18)" }}>',
  '                  <div style={{ display: "flex", gap: 10, alignItems: "baseline", flexWrap: "wrap" }}>',
  '                    <div style={{ fontSize: 14, fontWeight: 900 }}>{title}</div>',
  '                    {kind ? <span style={{ fontSize: 12, opacity: 0.72 }}>({kind})</span> : null}',
  '                  </div>',
  '                  {url ? (',
  '                    <div style={{ marginTop: 6, fontSize: 13 }}>',
  '                      <a href={url} target="_blank" rel="noreferrer" style={{ color: "inherit", textDecoration: "underline" }}>{url}</a>',
  '                    </div>',
  '                  ) : null}',
  '                  {note ? <div style={{ marginTop: 6, fontSize: 13, opacity: 0.86, whiteSpace: "pre-wrap" }}>{note}</div> : null}',
  '                </div>',
  '              );',
  '            })}',
  '          </div>',
  '        </article>',
  '      ) : null}',
  '',
  '      {(!md && (!jsonItems || jsonItems.length === 0)) ? (',
  '        <div style={card}>',
  '          <div style={h2}>Ainda vazio</div>',
  '          <div style={{ marginTop: 8, fontSize: 13, opacity: 0.82 }}>',
  '            Crie <code>{"content/cadernos/" + slug + "/provas.md"}</code> ou <code>{"content/cadernos/" + slug + "/provas.json"}</code> para alimentar esta tela.',
  '          </div>',
  '        </div>',
  '      ) : null}',
  '    </section>',
  '  );',
  '}'
)

WriteRel "src\components\v2\ProvasV2.tsx" $provasComp

# ---------------------------
# 2) /v2/provas page
# ---------------------------
$provasPage = @(
  'import type { CSSProperties } from "react";',
  'import { getCaderno } from "@/lib/cadernos";',
  'import V2Nav from "@/components/v2/V2Nav";',
  'import ProvasV2 from "@/components/v2/ProvasV2";',
  '',
  'type AnyParams = { slug: string } | Promise<{ slug: string }>; ',
  '',
  'type AccentStyle = CSSProperties & Record<"--accent", string>;',
  '',
  'async function getSlug(params: AnyParams): Promise<string> {',
  '  const p = await Promise.resolve(params as unknown as { slug: string });',
  '  return (p && p.slug) ? p.slug : "";',
  '}',
  '',
  'export default async function Page({ params }: { params: AnyParams }) {',
  '  const slug = await getSlug(params);',
  '  const data = await getCaderno(slug);',
  '  const meta = (data && (data as unknown as { meta?: unknown }).meta) ? (data as unknown as { meta: unknown }).meta : null;',
  '  const title = (data && (data as unknown as { title?: string }).title) ? (data as unknown as { title: string }).title : slug;',
  '',
  '  const accent = (meta && typeof (meta as any).accent === "string") ? (meta as any).accent : "#F5C400";',
  '  const s: AccentStyle = { ["--accent"]: accent };',
  '',
  '  return (',
  '    <main style={{ padding: 18, maxWidth: 1100, margin: "0 auto" }}>',
  '      <div style={s as any} />',
  '      <V2Nav slug={slug} active={"provas" as any} />',
  '      <div style={{ marginTop: 12 }}>',
  '        <ProvasV2 slug={slug} title={title} />',
  '      </div>',
  '    </main>',
  '  );',
  '}'
)

WriteRel "src\app\c\[slug]\v2\provas\page.tsx" $provasPage

# ---------------------------
# 3) Tentar adicionar link Provas no V2Nav (best-effort; sem quebrar)
# ---------------------------
PatchText "src\components\v2\V2Nav.tsx" {
  param($s)
  $out = $s
  if ($out.IndexOf('/v2/provas') -ge 0) { return $out }

  $anchor = '/v2/linha'
  $pos = $out.IndexOf($anchor)
  if ($pos -lt 0) { return $out }

  $ls = $out.LastIndexOf("`n", $pos)
  if ($ls -lt 0) { $ls = 0 } else { $ls = $ls + 1 }

  $ins = @(
    '        <a href={"/c/" + slug + "/v2/provas"} style={linkStyle("provas")}>Provas</a>'
  ) -join "`r`n"

  return ($out.Substring(0, $ls) + $ins + "`r`n" + $out.Substring($ls))
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Step D3 — ProvasV2 (v0_116)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que entrou") | Out-Null
$rep.Add("- Nova rota: /c/[slug]/v2/provas") | Out-Null
$rep.Add("- Componente: ProvasV2 (server-safe; lê provas.md/mdx/txt ou provas.json)") | Out-Null
$rep.Add("- Best-effort: adiciona link Provas no V2Nav se ainda não existir") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null
$rp = WriteReport "cv-step-d3-provasv2-v0_116.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] D3 aplicado e verificado."