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
# 1) Componente LinhaV2.tsx (server-safe)
# ---------------------------
$linhaComp = @(
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
  '    const items = (parsed as AnyObj)["items"]; if (Array.isArray(items)) return items;'
  '    const timeline = (parsed as AnyObj)["timeline"]; if (Array.isArray(timeline)) return timeline;'
  '    const events = (parsed as AnyObj)["events"]; if (Array.isArray(events)) return events;'
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
  '    const t = textOf(item[k]).trim();'
  '    if (t) return t;'
  '  }'
  '  return "";'
  '}'
  ''
  'type TimelineItem = { id: string; date?: string; title: string; body?: string; kind?: string; };'
  ''
  'function normalize(items: unknown[]): TimelineItem[] {'
  '  const out: TimelineItem[] = [];'
  '  for (let i = 0; i < items.length; i++) {'
  '    const it = items[i];'
  '    const obj: AnyObj = isObj(it) ? (it as AnyObj) : ({ text: String(it) } as AnyObj);'
  '    const id = pick(obj, ["id", "key", "slug"]) || String(i);'
  '    const date = pick(obj, ["date", "when", "year"]);'
  '    const title = pick(obj, ["title", "name"]) || "Marco";'
  '    const body = pick(obj, ["body", "text", "content", "desc", "description"]);'
  '    const kind = pick(obj, ["kind", "type"]);'
  '    out.push({ id, date: date || undefined, title, body: body || undefined, kind: kind || undefined });'
  '  }'
  '  return out;'
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
  'export default async function LinhaV2(props: { slug: string; title?: string }) {'
  '  const { slug } = props;'
  '  const root = path.join(process.cwd(), "content", "cadernos", slug);'
  ''
  '  const md ='
  '    (await readOptional(path.join(root, "linha.md"))) ||'
  '    (await readOptional(path.join(root, "linha.mdx"))) ||'
  '    (await readOptional(path.join(root, "linha.txt"))) ||'
  '    (await readOptional(path.join(root, "timeline.md"))) ||'
  '    (await readOptional(path.join(root, "timeline.txt")));'
  ''
  '  const rawJson = (await readOptional(path.join(root, "linha.json"))) || (await readOptional(path.join(root, "timeline.json")));'
  '  let items: TimelineItem[] = [];'
  '  if (rawJson) {'
  '    try {'
  '      const arr = pickArray(JSON.parse(rawJson) as unknown);'
  '      if (arr && arr.length) items = normalize(arr);'
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
  '    <section aria-label="Linha V2" style={wrap}>'
  '      <div style={card}>'
  '        <div style={{ fontSize: 12, opacity: 0.75 }}>Concreto Zen • Linha</div>'
  '        <div style={{ fontSize: 22, fontWeight: 950, letterSpacing: "-0.4px", marginTop: 6 }}>Linha do tempo</div>'
  '        <div style={{ marginTop: 8, fontSize: 13, opacity: 0.82 }}>'
  '          Aqui entram marcos, eventos, etapas e viradas do caderno. Por enquanto, lê <code>linha.md</code> / <code>linha.json</code> (ou <code>timeline.*</code>).'
  '        </div>'
  '        <div style={{ marginTop: 12, display: "flex", gap: 10, flexWrap: "wrap" }}>'
  '          <Link href={"/c/" + slug} style={chip}>Abrir V1</Link>'
  '          <Link href={"/c/" + slug + "/v2/mapa"} style={{ ...chip, background: "rgba(0,0,0,0.18)" }}>Ir pro Mapa V2</Link>'
  '        </div>'
  '      </div>'
  ''
  '      {md ? ('
  '        <article style={card}>'
  '          <div style={small}>Fonte: linha.md / timeline.md</div>'
  '          <div style={h2}>Texto-base</div>'
  '          <pre style={{ marginTop: 12, whiteSpace: "pre-wrap", lineHeight: 1.55, fontSize: 13, opacity: 0.92 }}>{md}</pre>'
  '        </article>'
  '      ) : null}'
  ''
  '      {(!md && items.length) ? ('
  '        <article style={card}>'
  '          <div style={small}>Fonte: linha.json / timeline.json</div>'
  '          <div style={h2}>Marcos</div>'
  '          <div style={{ display: "grid", gap: 10, marginTop: 12 }}>'
  '            {items.map((it, idx) => ('
  '              <div key={it.id || String(idx)} style={{ padding: 12, borderRadius: 12, border: "1px solid rgba(255,255,255,0.10)", background: "rgba(0,0,0,0.18)" }}>'
  '                <div style={{ display: "flex", gap: 10, flexWrap: "wrap", alignItems: "baseline" }}>'
  '                  <div style={{ fontSize: 14, fontWeight: 850 }}>{it.title}</div>'
  '                  {it.kind ? <span style={{ fontSize: 12, opacity: 0.75 }}>• {it.kind}</span> : null}'
  '                  {it.date ? <span style={{ fontSize: 12, opacity: 0.75 }}>• {it.date}</span> : null}'
  '                </div>'
  '                {it.body ? <div style={{ marginTop: 6, fontSize: 13, opacity: 0.86, whiteSpace: "pre-wrap" }}>{it.body}</div> : null}'
  '              </div>'
  '            ))}'
  '          </div>'
  '        </article>'
  '      ) : null}'
  ''
  '      {(!md && items.length === 0) ? ('
  '        <div style={card}>'
  '          <div style={h2}>Ainda vazio</div>'
  '          <div style={{ marginTop: 8, fontSize: 13, opacity: 0.82 }}>'
  '            Crie <code>{"content/cadernos/" + slug + "/linha.md"}</code> ou <code>{"content/cadernos/" + slug + "/linha.json"}</code> para alimentar esta tela.'
  '          </div>'
  '        </div>'
  '      ) : null}'
  '    </section>'
  '  );'
  '}'
)

WriteRel "src\components\v2\LinhaV2.tsx" $linhaComp

# ---------------------------
# 2) Rota /v2/linha (reescreve padrão)
# ---------------------------
$linhaPage = @(
  'import { getCaderno } from "@/lib/cadernos";'
  'import V2Nav from "@/components/v2/V2Nav";'
  'import LinhaV2 from "@/components/v2/LinhaV2";'
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
  '      <V2Nav slug={slug} active="linha" />'
  '      <div style={{ marginTop: 12 }}>'
  '        <LinhaV2 slug={slug} title={title} />'
  '      </div>'
  '    </main>'
  '  );'
  '}'
)

WriteRel "src\app\c\[slug]\v2\linha\page.tsx" $linhaPage

# ---------------------------
# 3) Debate page: remover "as any" (lint no-explicit-any)
# ---------------------------
PatchText "src\app\c\[slug]\v2\debate\page.tsx" {
  param($s)
  $out = $s
  if ($out.IndexOf('active="debate"') -ge 0) { return $out }
  $out = $out.Replace('active={"debate" as any}', 'active="debate"')
  $out = $out.Replace("active={'debate' as any}", 'active="debate"')
  return $out
}

# ---------------------------
# 4) V2Nav: deixar active como string (para não ficar brigando com union)
# ---------------------------
PatchText "src\components\v2\V2Nav.tsx" {
  param($s)
  $out = $s
  if ($out.IndexOf('active?: string') -ge 0 -or $out.IndexOf('active: string') -ge 0) { return $out }

  # tenta trocar a linha do tipo/props que contém active?:
  $lines = $out -split "`r`n"
  $did = $false
  for ($i = 0; $i -lt $lines.Length; $i++) {
    $ln = $lines[$i]
    if ($ln -match 'active\??\s*:\s*' -and $ln -match ';') {
      # substitui tudo depois de ":" até ";" por " string"
      $p1 = $ln.IndexOf(":")
      $p2 = $ln.LastIndexOf(";")
      if ($p1 -ge 0 -and $p2 -gt $p1) {
        $prefix = $ln.Substring(0, $p1 + 1)
        $suffix = $ln.Substring($p2)
        $lines[$i] = ($prefix + " string" + $suffix)
        $did = $true
        break
      }
    }
  }
  if ($did) { return ($lines -join "`r`n") }
  return $out
}

# ---------------------------
# 5) /c/[slug]/page.tsx: usar uiDefault + redirect (remove warnings)
# ---------------------------
PatchText "src\app\c\[slug]\page.tsx" {
  param($s)
  $out = $s

  if ($out.IndexOf('uiDefault === "v2"') -ge 0 -and $out.IndexOf('redirect("/c/" + slug + "/v2")') -ge 0) {
    return $out
  }

  # só tenta se existe "const uiDefault"
  $m = [regex]::Match($out, 'const\s+uiDefault\s*=\s*[^;]+;\s*')
  if (!$m.Success) { return $out }

  # injeta logo após o uiDefault
  $pos = $m.Index + $m.Length
  $insLines = @(
'  if (uiDefault === "v2") {'
'    redirect("/c/" + slug + "/v2");'
'  }'
''
  )
  $ins = ($insLines -join "`r`n")
  return ($out.Substring(0, $pos) + "`r`n" + $ins + $out.Substring($pos))
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Step D4 — LinhaV2 + fixes lint (v0_105)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que entrou") | Out-Null
$rep.Add("- Componente: LinhaV2 (server-safe; lê linha.md/linha.json ou timeline.*)") | Out-Null
$rep.Add("- Rota: /c/[slug]/v2/linha (padrão, consistente com V2Nav)") | Out-Null
$rep.Add("- Fix lint: Debate page sem any; V2Nav active como string; /c/[slug] usa uiDefault+redirect") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null
$rp = WriteReport "cv-step-d4-linhav2-v0_105.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] D4 aplicado e verificado."