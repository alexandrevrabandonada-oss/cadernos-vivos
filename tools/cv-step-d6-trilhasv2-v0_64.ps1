$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Write-Host ("[DIAG] Repo: " + $repo)

. (Join-Path $PSScriptRoot "_bootstrap.ps1")

$changed = New-Object System.Collections.Generic.List[string]

function WriteFileLines([string]$rel, [string[]]$lines) {
  $fullp = Join-Path $repo $rel
  EnsureDir (Split-Path -Parent $fullp) | Out-Null
  $bk = $null
  if (Test-Path -LiteralPath $fullp) { $bk = BackupFile $fullp }
  $content = $lines -join "`r`n"
  WriteUtf8NoBom $fullp $content
  Write-Host ("[OK] wrote: " + $fullp)
  if ($bk) { Write-Host ("[BK] " + $bk) }
  $script:changed.Add($fullp) | Out-Null
}

function PatchText([string]$rel, [scriptblock]$mutate) {
  $fullp = Join-Path $repo $rel
  if (!(Test-Path -LiteralPath $fullp)) { Write-Host ("[WARN] nao achei para patch: " + $fullp); return }
  $raw = Get-Content -LiteralPath $fullp -Raw
  if ($null -eq $raw) { Write-Host ("[WARN] leitura nula: " + $fullp); return }

  $next = & $mutate $raw
  if ($null -eq $next) { Write-Host "[WARN] mutate retornou null"; return }

  if ($next -ne $raw) {
    $bk = BackupFile $fullp
    WriteUtf8NoBom $fullp $next
    Write-Host ("[OK] patched: " + $fullp)
    Write-Host ("[BK] " + $bk)
    $script:changed.Add($fullp) | Out-Null
  } else {
    Write-Host ("[OK] sem mudanca: " + $fullp)
  }
}

# 1) Component: src/components/v2/TrilhasV2.tsx
$trilhasComp = @(
  'import React from "react";',
  '',
  'type AnyObj = Record<string, unknown>;',
  '',
  'function isObj(v: unknown): v is AnyObj {',
  '  return !!v && typeof v === "object" && !Array.isArray(v);',
  '}',
  '',
  'function asStr(v: unknown, fallback: string): string {',
  '  return typeof v === "string" && v.trim() ? v : fallback;',
  '}',
  '',
  'function pick(v: unknown, keys: string[]): unknown {',
  '  if (!isObj(v)) return undefined;',
  '  for (const k of keys) {',
  '    const got = (v as AnyObj)[k];',
  '    if (got !== undefined) return got;',
  '  }',
  '  return undefined;',
  '}',
  '',
  'function toSteps(v: unknown): string[] {',
  '  if (!v) return [];',
  '  if (Array.isArray(v)) {',
  '    return v',
  '      .filter((x) => typeof x === "string")',
  '      .map((x) => (x as string).trim())',
  '      .filter(Boolean);',
  '  }',
  '  if (isObj(v)) {',
  '    const s = pick(v, ["steps", "passos", "itens", "items", "lista"]);',
  '    if (Array.isArray(s)) {',
  '      return s',
  '        .filter((x) => typeof x === "string")',
  '        .map((x) => (x as string).trim())',
  '        .filter(Boolean);',
  '    }',
  '  }',
  '  return [];',
  '}',
  '',
  'export type Trail = {',
  '  id: string;',
  '  title: string;',
  '  description?: string;',
  '  steps?: string[];',
  '  source?: "trilhas" | "mapa";',
  '};',
  '',
  'function normalizeArr(arr: unknown[], source: "trilhas" | "mapa"): Trail[] {',
  '  const out: Trail[] = [];',
  '  for (let i = 0; i < arr.length; i++) {',
  '    const it = arr[i];',
  '    if (!it) continue;',
  '    if (isObj(it)) {',
  '      const id = asStr(pick(it, ["id", "slug", "key"]), "t" + String(i + 1));',
  '      const title = asStr(pick(it, ["title", "titulo", "name", "nome"]), "Trilha " + String(i + 1));',
  '      const description = pick(it, ["description", "descricao", "desc", "resumo"]);',
  '      const steps = toSteps(pick(it, ["steps", "passos", "itens", "items", "lista"]));',
  '      out.push({',
  '        id,',
  '        title,',
  '        description: typeof description === "string" ? description : undefined,',
  '        steps: steps.length ? steps : undefined,',
  '        source,',
  '      });',
  '      continue;',
  '    }',
  '    if (typeof it === "string" && it.trim()) {',
  '      out.push({ id: "t" + String(i + 1), title: it.trim(), source });',
  '    }',
  '  }',
  '  return out;',
  '}',
  '',
  'function trailsFromTrilhas(raw: unknown): Trail[] {',
  '  if (!raw) return [];',
  '  if (Array.isArray(raw)) return normalizeArr(raw, "trilhas");',
  '  if (isObj(raw)) {',
  '    const maybe = pick(raw, ["trilhas", "trails", "items", "lista"]);',
  '    if (Array.isArray(maybe)) return normalizeArr(maybe, "trilhas");',
  '  }',
  '  return [];',
  '}',
  '',
  'function trailsFromMapa(mapa: unknown): Trail[] {',
  '  if (!mapa) return [];',
  '  if (Array.isArray(mapa)) {',
  '    const nodes = mapa;',
  '    const onlyTrail = nodes.filter((n) => {',
  '      if (!isObj(n)) return false;',
  '      const t = pick(n, ["type", "kind", "nodeType"]);',
  '      return typeof t === "string" && t.toLowerCase() === "trail";',
  '    });',
  '    return normalizeArr(onlyTrail, "mapa");',
  '  }',
  '  if (isObj(mapa)) {',
  '    const nodes = pick(mapa, ["nodes", "items", "timeline"]);',
  '    if (Array.isArray(nodes)) {',
  '      const onlyTrail = nodes.filter((n) => {',
  '        if (!isObj(n)) return false;',
  '        const t = pick(n, ["type", "kind", "nodeType"]);',
  '        return typeof t === "string" && t.toLowerCase() === "trail";',
  '      });',
  '      return normalizeArr(onlyTrail, "mapa");',
  '    }',
  '  }',
  '  return [];',
  '}',
  '',
  'export function TrilhasV2(props: { slug: string; title: string; trilhas?: unknown; mapa?: unknown }) {',
  '  const fromTrilhas = trailsFromTrilhas(props.trilhas);',
  '  const trails = fromTrilhas.length ? fromTrilhas : trailsFromMapa(props.mapa);',
  '',
  '  return (',
  '    <div style={{ display: "grid", gap: 12 }}>',
  '      <header',
  '        style={{',
  '          border: "1px solid rgba(255,255,255,0.10)",',
  '          borderRadius: 14,',
  '          padding: 12,',
  '          background: "rgba(0,0,0,0.22)",',
  '        }}',
  '      >',
  '        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 12, flexWrap: "wrap" }}>',
  '          <div style={{ display: "flex", flexDirection: "column", gap: 2 }}>',
  '            <div style={{ fontSize: 12, opacity: 0.75 }}>Trilhas V2</div>',
  '            <div style={{ fontSize: 16, fontWeight: 900 }}>{props.title}</div>',
  '          </div>',
  '          <span',
  '            style={{',
  '              fontSize: 12,',
  '              opacity: 0.85,',
  '              padding: "6px 10px",',
  '              borderRadius: 999,',
  '              border: "1px solid rgba(255,255,255,0.12)",',
  '            }}',
  '          >',
  '            {trails.length} trilha(s)',
  '          </span>',
  '        </div>',
  '      </header>',
  '',
  '      {trails.length === 0 ? (',
  '        <div',
  '          style={{',
  '            borderRadius: 14,',
  '            padding: 12,',
  '            border: "1px solid rgba(255,255,255,0.10)",',
  '            background: "rgba(0,0,0,0.18)",',
  '            fontSize: 13,',
  '            lineHeight: 1.45,',
  '            opacity: 0.95,',
  '          }}',
  '        >',
  '          Ainda não tem trilhas aqui. Você pode criar um <b>trilhas.json</b> no caderno (normalize layer lê como <code>trilhas</code>),',
  '          ou marcar nós do mapa com <code>{`type: "trail"`}</code> (best-effort).',
  '        </div>',
  '      ) : (',
  '        <div style={{ display: "grid", gap: 10 }}>',
  '          {trails.map((t) => (',
  '            <section',
  '              key={t.id}',
  '              id={t.id}',
  '              style={{',
  '                borderRadius: 14,',
  '                padding: 12,',
  '                border: "1px solid rgba(255,255,255,0.10)",',
  '                background: "rgba(0,0,0,0.18)",',
  '              }}',
  '            >',
  '              <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", gap: 12, flexWrap: "wrap" }}>',
  '                <div style={{ display: "flex", flexDirection: "column", gap: 6, minWidth: 240 }}>',
  '                  <div style={{ display: "flex", alignItems: "center", gap: 8, flexWrap: "wrap" }}>',
  '                    <span',
  '                      style={{',
  '                        fontSize: 12,',
  '                        fontWeight: 900,',
  '                        padding: "5px 10px",',
  '                        borderRadius: 999,',
  '                        border: "1px solid rgba(255,255,255,0.12)",',
  '                        background: "rgba(255,255,255,0.06)",',
  '                      }}',
  '                    >',
  '                      #{t.id}',
  '                    </span>',
  '                    <div style={{ fontSize: 14, fontWeight: 900 }}>{t.title}</div>',
  '                  </div>',
  '                  {t.description ? (',
  '                    <div style={{ fontSize: 13, lineHeight: 1.45, opacity: 0.95, whiteSpace: "pre-wrap" }}>{t.description}</div>',
  '                  ) : null}',
  '                </div>',
  '',
  '                <div style={{ display: "flex", alignItems: "center", gap: 8, flexWrap: "wrap", justifyContent: "flex-end" }}>',
  '                  <span style={{ fontSize: 12, opacity: 0.7 }}>origem: {t.source ?? "?"}</span>',
  '                </div>',
  '              </div>',
  '',
  '              {t.steps && t.steps.length ? (',
  '                <ul style={{ marginTop: 10, paddingLeft: 18, display: "grid", gap: 6 }}>',
  '                  {t.steps.map((s, i) => (',
  '                    <li key={t.id + "-" + String(i)} style={{ fontSize: 13, lineHeight: 1.45, opacity: 0.95 }}>',
  '                      {s}',
  '                    </li>',
  '                  ))}',
  '                </ul>',
  '              ) : null}',
  '            </section>',
  '          ))}',
  '        </div>',
  '      )}',
  '    </div>',
  '  );',
  '}'
)
WriteFileLines "src\components\v2\TrilhasV2.tsx" $trilhasComp

# 2) Page: src/app/c/[slug]/v2/trilhas/page.tsx
$page = @(
  'import { notFound } from "next/navigation";',
  'import type { CSSProperties } from "react";',
  'import V2Nav from "@/components/v2/V2Nav";',
  'import { TrilhasV2 } from "@/components/v2/TrilhasV2";',
  'import { loadCadernoV2 } from "@/lib/v2";',
  '',
  'type AccentStyle = CSSProperties & Record<"--accent", string>;',
  '',
  'type Meta = { title?: string; accent?: string };',
  'type V2Data = { meta?: Meta; mapa?: unknown; trilhas?: unknown };',
  '',
  'export default async function Page({ params }: { params: Promise<{ slug: string }> }) {',
  '  const { slug } = await params;',
  '',
  '  let data: Awaited<ReturnType<typeof loadCadernoV2>>;',
  '  try {',
  '    data = await loadCadernoV2(slug);',
  '  } catch (e) {',
  '    const err = e as { code?: string };',
  '    if (err && err.code === "ENOENT") return notFound();',
  '    throw e;',
  '  }',
  '',
  '  const d = data as unknown as V2Data;',
  '  const title = d.meta?.title ?? slug;',
  '  const accent = d.meta?.accent ?? "#F7C600";',
  '  const s: AccentStyle = { ["--accent"]: accent } as AccentStyle;',
  '',
  '  return (',
  '    <main style={{ padding: 14, maxWidth: 1100, margin: "0 auto", ...s }}>',
  '      <V2Nav slug={slug} active={"trilhas" as unknown as never} />',
  '      <div style={{ marginTop: 12 }}>',
  '        <TrilhasV2 slug={slug} title={title} trilhas={d.trilhas} mapa={d.mapa} />',
  '      </div>',
  '    </main>',
  '  );',
  '}'
)
WriteFileLines "src\app\c\[slug]\v2\trilhas\page.tsx" $page

# 3) Best-effort: add "Trilhas" tab into V2Nav (only if structure looks like object list)
$navRel = "src\components\v2\V2Nav.tsx"
PatchText $navRel {
  param($raw)

  if ($raw.IndexOf("/v2/trilhas") -ge 0) { return $raw }

  # Heuristica: se nao tem "key:" provavelmente nao eh lista de objetos → nao arrisca
  if ($raw.IndexOf("key:") -lt 0) {
    Write-Host "[WARN] V2Nav nao parece ser lista de objetos (key:). Nao vou patchar automatico."
    return $raw
  }

  $lines = $raw -split "(`r`n|`n|`r)"
  $idx = -1
  for ($i=0; $i -lt $lines.Length; $i++) {
    $ln = $lines[$i]
    if ($ln -like "*\/v2\/linha*" -or $ln -like "*\/v2\/linha-do-tempo*" -or $ln -like "*key:*linha*") { $idx = $i; break }
  }
  if ($idx -lt 0) {
    Write-Host "[WARN] nao achei ancora /v2/linha no V2Nav; nao inseri aba Trilhas."
    return $raw
  }

  $j = $idx
  while ($j -lt $lines.Length -and ($lines[$j] -notmatch "\}\s*,?\s*$")) { $j++ }
  if ($j -ge $lines.Length) {
    Write-Host "[WARN] nao achei fim do objeto para inserir; skip."
    return $raw
  }

  $slugExpr = "slug"
  if (($raw.IndexOf("props.slug") -ge 0) -and ($raw -notmatch "\(\s*\{\s*slug")) { $slugExpr = "props.slug" }

  $indent = [regex]::Match($lines[$j], "^\s*").Value
  $newLine = $indent + '{ key: "trilhas", label: "Trilhas", href: "/c/" + ' + $slugExpr + ' + "/v2/trilhas" },'

  $out = New-Object System.Collections.Generic.List[string]
  for ($k=0; $k -le $j; $k++) { $out.Add($lines[$k]) | Out-Null }
  $out.Add($newLine) | Out-Null
  for ($k=$j+1; $k -lt $lines.Length; $k++) { $out.Add($lines[$k]) | Out-Null }

  return ($out -join "`r`n")
}

# 4) VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# 5) REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Step D6 — Trilhas V2 (v0_64)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que entrou") | Out-Null
$rep.Add("- Componente `TrilhasV2`: renderiza trilhas (de `trilhas` ou derivadas do `mapa` via `type: trail`).") | Out-Null
$rep.Add("- Rota `/c/[slug]/v2/trilhas`: carrega via `loadCadernoV2`, aplica `--accent` e usa `V2Nav`.") | Out-Null
$rep.Add("- Best-effort: tenta adicionar aba Trilhas no `V2Nav` se for lista de objetos.") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null

$rp = WriteReport "cv-step-d6-trilhasv2-v0_64.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Step D6 aplicado e verificado."