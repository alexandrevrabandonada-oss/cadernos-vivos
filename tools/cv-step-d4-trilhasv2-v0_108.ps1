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
# 1) TrilhasV2 (server-safe)
# Lê:
# - content/cadernos/{slug}/trilhas.md|mdx|txt
# - trilhas.json (fallback: trails.json / kanban.json)
# Estrutura JSON aceita:
# - array: [{ title, desc, steps:[...], tags:[...] }]
# - object: { items:[...]} ou { trilhas:[...]} ou { trails:[...]}
# - kanban opcional: { today:[...], week:[...], month:[...] }
# ---------------------------
$trilhasComp = @(
  'import Link from "next/link";'
  'import type { CSSProperties } from "react";'
  'import fs from "node:fs/promises";'
  'import path from "node:path";'
  ''
  'type AnyObj = Record<string, unknown>;'
  'type TrailItem = {'
  '  title?: string;'
  '  desc?: string;'
  '  steps?: string[];'
  '  tags?: string[];'
  '  kind?: string;'
  '};'
  'type Kanban = { today?: TrailItem[]; week?: TrailItem[]; month?: TrailItem[] };'
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
  'function normalizeItem(v: unknown): TrailItem {'
  '  if (!isObj(v)) return { title: s(v) || "Trilha" };'
  '  const o = v as AnyObj;'
  '  return {'
  '    title: s(o["title"]) || s(o["name"]) || s(o["id"]) || "Trilha",'
  '    desc: s(o["desc"]) || s(o["description"]) || s(o["body"]) || s(o["text"]) || "",'
  '    steps: arrStr(o["steps"]) || arrStr(o["tasks"]) || arrStr(o["items"]),'
  '    tags: arrStr(o["tags"]),'
  '    kind: s(o["kind"]) || s(o["type"]),'
  '  };'
  '}'
  ''
  'function pickArray(parsed: unknown): unknown[] | null {'
  '  if (!parsed) return null;'
  '  if (Array.isArray(parsed)) return parsed;'
  '  if (isObj(parsed)) {'
  '    const o = parsed as AnyObj;'
  '    const a1 = o["items"]; if (Array.isArray(a1)) return a1;'
  '    const a2 = o["trilhas"]; if (Array.isArray(a2)) return a2;'
  '    const a3 = o["trails"]; if (Array.isArray(a3)) return a3;'
  '  }'
  '  return null;'
  '}'
  ''
  'function pickKanban(parsed: unknown): Kanban | null {'
  '  if (!isObj(parsed)) return null;'
  '  const o = parsed as AnyObj;'
  '  const kb = o["kanban"];'
  '  const root = isObj(kb) ? (kb as AnyObj) : o;'
  '  const today = root["today"];'
  '  const week = root["week"];'
  '  const month = root["month"];'
  '  const out: Kanban = {};'
  '  if (Array.isArray(today)) out.today = today.map(normalizeItem);'
  '  if (Array.isArray(week)) out.week = week.map(normalizeItem);'
  '  if (Array.isArray(month)) out.month = month.map(normalizeItem);'
  '  const hasAny = !!(out.today?.length || out.week?.length || out.month?.length);'
  '  return hasAny ? out : null;'
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
  'function trailCard(it: TrailItem, idx: number): JSX.Element {'
  '  const title = it.title || ("Trilha " + String(idx + 1));'
  '  const steps = it.steps || [];'
  '  return ('
  '    <div key={title + "-" + String(idx)} style={{ padding: 12, borderRadius: 12, border: "1px solid rgba(255,255,255,0.10)", background: "rgba(0,0,0,0.18)" }}>'
  '      <div style={{ display: "flex", gap: 10, flexWrap: "wrap", alignItems: "baseline" }}>'
  '        <div style={{ fontSize: 14, fontWeight: 850 }}>{title}</div>'
  '        {it.kind ? <div style={{ fontSize: 11, opacity: 0.75 }}>({it.kind})</div> : null}'
  '        {steps.length ? <div style={{ fontSize: 11, opacity: 0.75 }}>{steps.length} passos</div> : null}'
  '      </div>'
  '      {it.desc ? <div style={{ marginTop: 8, fontSize: 13, opacity: 0.86, whiteSpace: "pre-wrap" }}>{it.desc}</div> : null}'
  '      {it.tags && it.tags.length ? ('
  '        <div style={{ marginTop: 10, display: "flex", gap: 6, flexWrap: "wrap" }}>'
  '          {it.tags.map((t) => ('
  '            <span key={t} style={{ fontSize: 11, padding: "3px 8px", borderRadius: 999, border: "1px solid rgba(255,255,255,0.12)", opacity: 0.8 }}>{t}</span>'
  '          ))}'
  '        </div>'
  '      ) : null}'
  '      {steps.length ? ('
  '        <ol style={{ marginTop: 10, paddingLeft: 18, opacity: 0.92, fontSize: 13, lineHeight: 1.6 }}>'
  '          {steps.map((st, sidx) => <li key={String(sidx)} style={{ marginTop: 4 }}>{st}</li>)}'
  '        </ol>'
  '      ) : null}'
  '    </div>'
  '  );'
  '}'
  ''
  'export default async function TrilhasV2(props: { slug: string; title?: string }) {'
  '  const { slug } = props;'
  '  const root = path.join(process.cwd(), "content", "cadernos", slug);'
  ''
  '  const md ='
  '    (await readOptional(path.join(root, "trilhas.md"))) ||'
  '    (await readOptional(path.join(root, "trilhas.mdx"))) ||'
  '    (await readOptional(path.join(root, "trilhas.txt"))) ||'
  '    (await readOptional(path.join(root, "trails.md"))) ||'
  '    (await readOptional(path.join(root, "kanban.md")));'
  ''
  '  const rawJson ='
  '    (await readOptional(path.join(root, "trilhas.json"))) ||'
  '    (await readOptional(path.join(root, "trails.json"))) ||'
  '    (await readOptional(path.join(root, "kanban.json")));'
  ''
  '  let items: TrailItem[] = [];'
  '  let kanban: Kanban | null = null;'
  '  if (rawJson) {'
  '    try {'
  '      const parsed = JSON.parse(rawJson) as unknown;'
  '      const arr = pickArray(parsed);'
  '      if (arr) items = arr.map(normalizeItem);'
  '      kanban = pickKanban(parsed);'
  '    } catch {'
  '      items = [];'
  '      kanban = null;'
  '    }'
  '  }'
  ''
  '  const wrap: CSSProperties = { marginTop: 12, display: "grid", gap: 12 };'
  '  const small: CSSProperties = { fontSize: 12, opacity: 0.78 };'
  '  const h2: CSSProperties = { fontSize: 18, fontWeight: 900, letterSpacing: "-0.2px", marginTop: 2 };'
  ''
  '  return ('
  '    <section aria-label="Trilhas V2" style={wrap}>'
  '      <div style={card}>'
  '        <div style={{ fontSize: 12, opacity: 0.75 }}>Concreto Zen • Trilhas</div>'
  '        <div style={{ fontSize: 22, fontWeight: 950, letterSpacing: "-0.4px", marginTop: 6 }}>Trilhas práticas</div>'
  '        <div style={{ marginTop: 8, fontSize: 13, opacity: 0.82 }}>'
  '          Aqui entram roteiros (passo a passo), missões e tarefas do caderno. JSON vira cards; MD vira texto-base.'
  '        </div>'
  '        <div style={{ marginTop: 12, display: "flex", gap: 10, flexWrap: "wrap" }}>'
  '          <Link href={"/c/" + slug + "/v2"} style={btn}>Voltar pro Hub V2</Link>'
  '          <Link href={"/c/" + slug} style={{ ...btn, background: "rgba(0,0,0,0.18)" }}>Abrir V1</Link>'
  '        </div>'
  '      </div>'
  ''
  '      {md ? ('
  '        <article style={card}>'
  '          <div style={small}>Fonte: trilhas.md / kanban.md</div>'
  '          <div style={h2}>Texto-base</div>'
  '          <pre style={{ marginTop: 12, whiteSpace: "pre-wrap", lineHeight: 1.55, fontSize: 13, opacity: 0.92 }}>{md}</pre>'
  '        </article>'
  '      ) : null}'
  ''
  '      {(!md && kanban) ? ('
  '        <article style={card}>'
  '          <div style={small}>Fonte: kanban.json / trilhas.json</div>'
  '          <div style={h2}>Kanban</div>'
  '          <div style={{ marginTop: 12, display: "grid", gap: 12, gridTemplateColumns: "repeat(auto-fit, minmax(240px, 1fr))" }}>'
  '            <div>'
  '              <div style={{ fontSize: 12, opacity: 0.78, marginBottom: 8 }}>Hoje</div>'
  '              <div style={{ display: "grid", gap: 10 }}>'
  '                {(kanban.today && kanban.today.length) ? kanban.today.map((it, idx) => trailCard(it, idx)) : <div style={{ opacity: 0.7, fontSize: 13 }}>vazio</div>}'
  '              </div>'
  '            </div>'
  '            <div>'
  '              <div style={{ fontSize: 12, opacity: 0.78, marginBottom: 8 }}>Essa semana</div>'
  '              <div style={{ display: "grid", gap: 10 }}>'
  '                {(kanban.week && kanban.week.length) ? kanban.week.map((it, idx) => trailCard(it, idx)) : <div style={{ opacity: 0.7, fontSize: 13 }}>vazio</div>}'
  '              </div>'
  '            </div>'
  '            <div>'
  '              <div style={{ fontSize: 12, opacity: 0.78, marginBottom: 8 }}>Esse mês</div>'
  '              <div style={{ display: "grid", gap: 10 }}>'
  '                {(kanban.month && kanban.month.length) ? kanban.month.map((it, idx) => trailCard(it, idx)) : <div style={{ opacity: 0.7, fontSize: 13 }}>vazio</div>}'
  '              </div>'
  '            </div>'
  '          </div>'
  '        </article>'
  '      ) : null}'
  ''
  '      {(!md && !kanban && items.length) ? ('
  '        <article style={card}>'
  '          <div style={small}>Fonte: trilhas.json</div>'
  '          <div style={h2}>Trilhas</div>'
  '          <div style={{ display: "grid", gap: 10, marginTop: 12 }}>'
  '            {items.map((it, idx) => trailCard(it, idx))}'
  '          </div>'
  '        </article>'
  '      ) : null}'
  ''
  '      {(!md && !kanban && items.length === 0) ? ('
  '        <div style={card}>'
  '          <div style={h2}>Ainda vazio</div>'
  '          <div style={{ marginTop: 8, fontSize: 13, opacity: 0.82 }}>'
  '            Crie <code>{"content/cadernos/" + slug + "/trilhas.json"}</code> (ou <code>kanban.json</code>) para alimentar esta tela.'
  '          </div>'
  '        </div>'
  '      ) : null}'
  '    </section>'
  '  );'
  '}'
)

WriteRel "src\components\v2\TrilhasV2.tsx" $trilhasComp

# ---------------------------
# 2) /v2/trilhas page
# ---------------------------
$trilhasPage = @(
  'import { getCaderno } from "@/lib/cadernos";'
  'import V2Nav from "@/components/v2/V2Nav";'
  'import TrilhasV2 from "@/components/v2/TrilhasV2";'
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
  '      <V2Nav slug={slug} active="trilhas" />'
  '      <div style={{ marginTop: 12 }}>'
  '        <TrilhasV2 slug={slug} title={title} />'
  '      </div>'
  '    </main>'
  '  );'
  '}'
)

WriteRel "src\app\c\[slug]\v2\trilhas\page.tsx" $trilhasPage

# ---------------------------
# 3) /c/[slug]/page.tsx — usar uiDefault + redirect (zera warnings)
# ---------------------------
PatchText "src\app\c\[slug]\page.tsx" {
  param($s)
  $out = $s

  # 3.1) garantir redirect importado de next/navigation
  $lines = $out -split "`n"
  $foundNav = $false
  for ($i=0; $i -lt $lines.Length; $i++) {
    $ln = $lines[$i]
    if ($ln -match 'from\s+"next/navigation"' -or $ln -match "from\s+'next/navigation'") {
      $foundNav = $true
      if ($ln -notmatch '\bredirect\b') {
        $lb = $ln.IndexOf('{')
        $rb = $ln.IndexOf('}')
        if ($lb -ge 0 -and $rb -gt $lb) {
          $inner = $ln.Substring($lb + 1, $rb - $lb - 1).Trim()
          if ($inner.Length -eq 0) {
            $newInner = 'redirect'
          } else {
            $inner2 = $inner.TrimEnd()
            if ($inner2.EndsWith(',')) { $newInner = ($inner2 + ' redirect') }
            else { $newInner = ($inner2 + ', redirect') }
          }
          $prefix = $ln.Substring(0, $lb)
          $suffix = $ln.Substring($rb + 1)
          $lines[$i] = ($prefix + '{ ' + $newInner + ' }' + $suffix)
        }
      }
    }
  }
  if (-not $foundNav) {
    # se não havia import do next/navigation, adiciona no topo
    $lines = @('import { redirect } from "next/navigation";') + $lines
  }
  $out = ($lines -join "`n")

  # 3.2) inserir redirect após const uiDefault (se ainda não existe)
  if ($out.IndexOf('uiDefault === "v2"') -ge 0 -and $out.IndexOf('redirect("/c/" + slug + "/v2")') -ge 0) {
    return $out
  }

  $m = [regex]::Match($out, 'const\s+uiDefault\s*=\s*[^;]+;\s*')
  if (-not $m.Success) { return $out }

  $pos = $m.Index + $m.Length
  $ins = @(
    '  if (uiDefault === "v2") {'
    '    redirect("/c/" + slug + "/v2");'
    '  }'
    ''
  ) -join "`r`n"

  return ($out.Substring(0, $pos) + "`r`n" + $ins + $out.Substring($pos))
}

# ---------------------------
# 4) Opcional: garantir HomeV2Hub tem card Trilhas (normalmente já tem)
# ---------------------------
PatchText "src\components\v2\HomeV2Hub.tsx" {
  param($s)
  $out = $s
  if ($out.IndexOf('/v2/trilhas') -ge 0) { return $out }
  return $out
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Step D4 — TrilhasV2 (v0_108)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que entrou") | Out-Null
$rep.Add("- Nova rota: /c/[slug]/v2/trilhas") | Out-Null
$rep.Add("- Componente TrilhasV2 (server-safe; lê trilhas.md ou trilhas.json/kanban.json)") | Out-Null
$rep.Add("- /c/[slug]/page.tsx agora usa uiDefault + redirect (zera warnings do lint)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null
$rp = WriteReport "cv-step-d4-trilhasv2-v0_108.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] D4 aplicado e verificado."