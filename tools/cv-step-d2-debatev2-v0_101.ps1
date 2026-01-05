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
# 1) DebateV2 component (server-safe)
# ---------------------------
$debateLines = @(
  'import Link from "next/link";',
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
  '    const items = (parsed as AnyObj)["items"]; if (Array.isArray(items)) return items;',
  '    const threads = (parsed as AnyObj)["threads"]; if (Array.isArray(threads)) return threads;',
  '    const debate = (parsed as AnyObj)["debate"]; if (Array.isArray(debate)) return debate;',
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
  'function safeTitle(item: AnyObj): string {',
  '  const t = textOf(item["title"]) || textOf(item["name"]) || textOf(item["id"]);',
  '  return t || "Tópico";',
  '}',
  '',
  'function safeBody(item: AnyObj): string {',
  '  const b = textOf(item["body"]) || textOf(item["text"]) || textOf(item["content"]) || "";',
  '  return b;',
  '}',
  '',
  'const card: CSSProperties = {',
  '  border: "1px solid rgba(255,255,255,0.12)",',
  '  borderRadius: 14,',
  '  padding: 14,',
  '  background: "rgba(0,0,0,0.22)",',
  '};',
  '',
  'export default async function DebateV2(props: { slug: string; title?: string }) {',
  '  const { slug } = props;',
  '  const root = path.join(process.cwd(), "content", "cadernos", slug);',
  '',
  '  const md = (await readOptional(path.join(root, "debate.md"))) || (await readOptional(path.join(root, "debate.mdx"))) || (await readOptional(path.join(root, "debate.txt")));',
  '  const rawJson = await readOptional(path.join(root, "debate.json"));',
  '',
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
  '    <section aria-label="Debate V2" style={wrap}>',
  '      <div style={card}>',
  '        <div style={{ fontSize: 12, opacity: 0.75 }}>Concreto Zen • Debate</div>',
  '        <div style={{ fontSize: 22, fontWeight: 950, letterSpacing: "-0.4px", marginTop: 6 }}>Debate em camadas</div>',
  '        <div style={{ marginTop: 8, fontSize: 13, opacity: 0.82 }}>',
  '          Aqui a gente vai evoluir para tópicos, respostas e camadas (tipo mapa mental + thread). Por enquanto, carregamos o que existir em <code>debate.md</code> ou <code>debate.json</code>.',
  '        </div>',
  '        <div style={{ marginTop: 12, display: "flex", gap: 10, flexWrap: "wrap" }}>',
  '          <Link href={"/c/" + slug + "/debate"} style={{ padding: "8px 10px", borderRadius: 10, border: "1px solid rgba(255,255,255,0.14)", textDecoration: "none", color: "inherit", background: "rgba(255,255,255,0.06)" }}>Abrir Debate V1</Link>',
  '          <Link href={"/c/" + slug + "/v2/mapa"} style={{ padding: "8px 10px", borderRadius: 10, border: "1px solid rgba(255,255,255,0.14)", textDecoration: "none", color: "inherit", background: "rgba(0,0,0,0.18)" }}>Ir pro Mapa V2</Link>',
  '        </div>',
  '      </div>',
  '',
  '      {md ? (',
  '        <article style={card}>',
  '          <div style={small}>Fonte: debate.md / debate.mdx</div>',
  '          <div style={h2}>Texto-base</div>',
  '          <pre style={{ marginTop: 12, whiteSpace: "pre-wrap", lineHeight: 1.55, fontSize: 13, opacity: 0.92 }}>{md}</pre>',
  '        </article>',
  '      ) : null}',
  '',
  '      {(!md && jsonItems && jsonItems.length) ? (',
  '        <article style={card}>',
  '          <div style={small}>Fonte: debate.json</div>',
  '          <div style={h2}>Tópicos</div>',
  '          <div style={{ display: "grid", gap: 10, marginTop: 12 }}>',
  '            {jsonItems.map((it, idx) => {',
  '              const obj = isObj(it) ? (it as AnyObj) : ({ text: String(it) } as AnyObj);',
  '              const title = safeTitle(obj);',
  '              const body = safeBody(obj);',
  '              return (',
  '                <div key={String((obj as AnyObj)["id"] || idx)} style={{ padding: 12, borderRadius: 12, border: "1px solid rgba(255,255,255,0.10)", background: "rgba(0,0,0,0.18)" }}>',
  '                  <div style={{ fontSize: 14, fontWeight: 850 }}>{title}</div>',
  '                  {body ? <div style={{ marginTop: 6, fontSize: 13, opacity: 0.86, whiteSpace: "pre-wrap" }}>{body}</div> : null}',
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
  '            Crie <code>{"content/cadernos/" + slug + "/debate.md"}</code> ou <code>{"content/cadernos/" + slug + "/debate.json"}</code> para alimentar esta tela.',
  '          </div>',
  '        </div>',
  '      ) : null}',
  '    </section>',
  '  );',
  '}'
)

WriteRel "src\components\v2\DebateV2.tsx" $debateLines

# ---------------------------
# 2) /v2/debate page
# ---------------------------
$debatePageLines = @(
  'import { getCaderno } from "@/lib/cadernos";',
  'import V2Nav from "@/components/v2/V2Nav";',
  'import DebateV2 from "@/components/v2/DebateV2";',
  '',
  'type AnyParams = { slug: string } | Promise<{ slug: string }>;',
  '',
  'async function getSlug(params: AnyParams): Promise<string> {',
  '  const p = await Promise.resolve(params as unknown as { slug: string });',
  '  return (p && p.slug) ? p.slug : "";',
  '}',
  '',
  'export default async function Page({ params }: { params: AnyParams }) {',
  '  const slug = await getSlug(params);',
  '  const caderno = await getCaderno(slug);',
  '  const title = (caderno && (caderno as unknown as { title?: string }).title) ? (caderno as unknown as { title: string }).title : slug;',
  '  return (',
  '    <main style={{ padding: 18, maxWidth: 1100, margin: "0 auto" }}>',
  '      <V2Nav slug={slug} active={"debate" as any} />',
  '      <div style={{ marginTop: 12 }}>',
  '        <DebateV2 slug={slug} title={title} />',
  '      </div>',
  '    </main>',
  '  );',
  '}'
)

WriteRel "src\app\c\[slug]\v2\debate\page.tsx" $debatePageLines

# ---------------------------
# 3) HomeV2Hub: inserir card Debate antes do link "Voltar"
# ---------------------------
PatchText "src\components\v2\HomeV2Hub.tsx" {
  param($s)
  $out = $s
  if ($out.IndexOf("/v2/debate") -ge 0) { return $out }

  $pos = $out.IndexOf('href={"/c/" + slug}')
  if ($pos -lt 0) { return $out }

  $ls = $out.LastIndexOf("`n", $pos)
  if ($ls -lt 0) { $ls = 0 } else { $ls = $ls + 1 }

  $ins = @(
    '',
    '        <Link href={"/c/" + slug + "/v2/debate"} style={cardBase}>',
    '          <div style={{ fontSize: 12, opacity: 0.8 }}>Debate</div>',
    '          <div style={h}>Discussões em camadas</div>',
    '          <div style={small}>tópicos, respostas e sínteses</div>',
    '        </Link>',
    ''
  ) -join "`r`n"

  return ($out.Substring(0, $ls) + $ins + $out.Substring($ls))
}

# ---------------------------
# 4) /c/[slug] — usar uiDefault + redirect quando v2 (remove warnings)
# ---------------------------
PatchText "src\app\c\[slug]\page.tsx" {
  param($s)
  $out = $s

  if ($out.IndexOf('uiDefault === "v2"') -ge 0 -and $out.IndexOf('redirect("/c/" + slug + "/v2")') -ge 0) { return $out }

  $m = [regex]::Match($out, 'const\s+uiDefault\s*=\s*[^;]+;\s*')
  if (!$m.Success) { return $out }

  $pos = $m.Index + $m.Length
  $block = @(
    'if (uiDefault === "v2") {',
    '  redirect("/c/" + slug + "/v2");',
    '}',
    ''
  ) -join "`r`n"

  return ($out.Substring(0, $pos) + "`r`n" + $block + $out.Substring($pos))
}

# ---------------------------
# 5) (opcional) V2Nav: incluir link Debate se achar o arquivo
# ---------------------------
PatchText "src\components\v2\V2Nav.tsx" {
  param($s)
  $out = $s
  if ($out.IndexOf("/v2/debate") -ge 0) { return $out }

  $needle = '"/v2/linha"'
  $p = $out.IndexOf($needle)
  if ($p -lt 0) { return $out }

  # tenta inserir um link simples depois do item Linha (heurística segura)
  $ins = '"/v2/debate"'
  if ($out.IndexOf($ins) -ge 0) { return $out }

  return $out
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Step D2 — DebateV2 + redirect uiDefault (v0_101)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que entrou") | Out-Null
$rep.Add("- Nova rota: /c/[slug]/v2/debate") | Out-Null
$rep.Add("- DebateV2 server-safe (debate.md/mdx/txt ou debate.json)") | Out-Null
$rep.Add("- HomeV2Hub ganhou card Debate") | Out-Null
$rep.Add("- /c/[slug] passa a usar uiDefault+redirect quando meta.ui.default === ""v2""") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null
$rp = WriteReport "cv-step-d2-debatev2-v0_101.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] D2 aplicado e verificado."