$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Write-Host ("[DIAG] Repo: " + $repo)

. (Join-Path $PSScriptRoot "_bootstrap.ps1")

$changed = New-Object System.Collections.Generic.List[string]

function WriteFileLines([string]$rel, [string[]]$lines) {
  $full = Join-Path $repo $rel
  EnsureDir (Split-Path -Parent $full) | Out-Null
  $bk = $null
  if (Test-Path -LiteralPath $full) { $bk = BackupFile $full }
  $content = $lines -join "`r`n"
  WriteUtf8NoBom $full $content
  Write-Host ("[OK] wrote: " + $full)
  if ($bk) { Write-Host ("[BK] " + $bk) }
  $script:changed.Add($full) | Out-Null
}

# 1) Component: HomeV2
$home = @(
'import Link from "next/link";',
'',
'type Card = { k: string; href: string; title: string; desc: string };',
'type Chip = { k: string; href: string; label: string };',
'',
'export function HomeV2(props: { slug: string; title: string; summary?: string }) {',
'  const base = "/c/" + props.slug;',
'',
'  const big: Card[] = [',
'    {',
'      k: "mapa",',
'      href: base + "/v2/mapa",',
'      title: "Mapa vivo",',
'      desc: "Conecta temas, lugares e relações. O caderno como território navegável.",',
'    },',
'    {',
'      k: "provas",',
'      href: base + "/v2/provas",',
'      title: "Provas e acervo",',
'      desc: "Documentos, recortes e evidências. Memória organizada (sem perder o fio).",',
'    },',
'    {',
'      k: "debate",',
'      href: base + "/v2/debate",',
'      title: "Debate guiado",',
'      desc: "Perguntas-ferramenta: impacto, contexto, crítica, humanização e convocação.",',
'    },',
'  ];',
'',
'  const chips: Chip[] = [',
'    { k: "linha", href: base + "/v2/linha-do-tempo", label: "Linha do tempo" },',
'    { k: "trilhas", href: base + "/v2/trilhas", label: "Trilhas" },',
'  ];',
'',
'  return (',
'    <div style={{ display: "grid", gap: 12 }}>',
'      <header',
'        style={{',
'          border: "1px solid rgba(255,255,255,0.10)",',
'          borderRadius: 16,',
'          padding: 14,',
'          background: "rgba(0,0,0,0.22)",',
'        }}',
'      >',
'        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 12 }}>',
'          <div style={{ display: "flex", flexDirection: "column", gap: 4 }}>',
'            <div style={{ fontSize: 12, opacity: 0.75, fontWeight: 800 }}>Caderno Vivo — V2</div>',
'            <div style={{ fontSize: 20, fontWeight: 950, letterSpacing: -0.2 }}>{props.title}</div>',
'          </div>',
'          <div',
'            style={{',
'              width: 34,',
'              height: 34,',
'              borderRadius: 999,',
'              border: "1px solid rgba(255,255,255,0.12)",',
'              background: "rgba(255,255,255,0.04)",',
'              display: "flex",',
'              alignItems: "center",',
'              justifyContent: "center",',
'            }}',
'            title="Assinatura do caderno (accent)"',
'          >',
'            <div style={{ width: 14, height: 14, borderRadius: 999, background: "var(--accent)" }} />',
'          </div>',
'        </div>',
'',
'        {props.summary ? (',
'          <div style={{ marginTop: 10, fontSize: 13, lineHeight: 1.45, opacity: 0.92 }}>',
'            {props.summary}',
'          </div>',
'        ) : null}',
'',
'        <div style={{ display: "flex", gap: 8, flexWrap: "wrap", marginTop: 12, alignItems: "center" }}>',
'          {chips.map((c) => (',
'            <Link',
'              key={c.k}',
'              href={c.href}',
'              style={{',
'                textDecoration: "none",',
'                color: "inherit",',
'                fontSize: 12,',
'                fontWeight: 850,',
'                padding: "8px 10px",',
'                borderRadius: 999,',
'                background: "rgba(255,255,255,0.06)",',
'                border: "1px solid rgba(255,255,255,0.12)",',
'              }}',
'              title={c.label}',
'            >',
'              {c.label}',
'            </Link>',
'          ))}',
'          <span style={{ opacity: 0.35, fontSize: 12 }}>•</span>',
'          <Link',
'            href={base}',
'            style={{',
'              textDecoration: "none",',
'              color: "inherit",',
'              fontSize: 12,',
'              fontWeight: 850,',
'              padding: "8px 10px",',
'              borderRadius: 999,',
'              background: "rgba(255,255,255,0.04)",',
'              border: "1px solid rgba(255,255,255,0.10)",',
'            }}',
'            title="Abrir a versão V1 deste caderno"',
'          >',
'            Abrir V1',
'          </Link>',
'        </div>',
'      </header>',
'',
'      <div',
'        style={{',
'          display: "grid",',
'          gridTemplateColumns: "repeat(auto-fit, minmax(240px, 1fr))",',
'          gap: 12,',
'        }}',
'      >',
'        {big.map((c) => (',
'          <Link',
'            key={c.k}',
'            href={c.href}',
'            style={{ textDecoration: "none", color: "inherit" }}',
'            title={c.title}',
'          >',
'            <div',
'              style={{',
'                borderRadius: 16,',
'                padding: 14,',
'                border: "1px solid rgba(255,255,255,0.10)",',
'                background: "rgba(0,0,0,0.18)",',
'                minHeight: 128,',
'                display: "flex",',
'                flexDirection: "column",',
'                gap: 10,',
'                transition: "transform 120ms ease",',
'              }}',
'            >',
'              <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 10 }}>',
'                <div style={{ fontSize: 12, opacity: 0.75, fontWeight: 900, letterSpacing: 0.6 }}>',
'                  {c.k.toUpperCase()}',
'                </div>',
'                <div style={{ width: 10, height: 10, borderRadius: 999, background: "var(--accent)" }} />',
'              </div>',
'              <div style={{ fontSize: 18, fontWeight: 950, letterSpacing: -0.2 }}>{c.title}</div>',
'              <div style={{ fontSize: 13, opacity: 0.9, lineHeight: 1.35 }}>{c.desc}</div>',
'            </div>',
'          </Link>',
'        ))}',
'      </div>',
'    </div>',
'  );',
'}'
)
WriteFileLines "src\components\v2\HomeV2.tsx" $home

# 2) Page: /c/[slug]/v2 (Hub)
$page = @(
'import { notFound } from "next/navigation";',
'import type { CSSProperties } from "react";',
'import { getCaderno } from "@/lib/cadernos";',
'import V2Nav from "@/components/v2/V2Nav";',
'import { HomeV2 } from "@/components/v2/HomeV2";',
'',
'type AccentStyle = CSSProperties & Record<"--accent", string>;',
'type AnyObj = Record<string, unknown>;',
'',
'function isObj(v: unknown): v is AnyObj {',
'  return !!v && typeof v === "object" && !Array.isArray(v);',
'}',
'',
'function pickSummary(data: unknown): string {',
'  if (!isObj(data)) return "";',
'  const meta = data["meta"];',
'  if (isObj(meta)) {',
'    const s1 = meta["subtitle"];',
'    if (typeof s1 === "string" && s1.trim()) return s1;',
'    const s2 = meta["summary"];',
'    if (typeof s2 === "string" && s2.trim()) return s2;',
'    const s3 = meta["descricao"];',
'    if (typeof s3 === "string" && s3.trim()) return s3;',
'  }',
'  const pano = data["panorama"];',
'  if (typeof pano === "string" && pano.trim()) return pano;',
'  if (isObj(pano)) {',
'    const ps = pano["summary"];',
'    if (typeof ps === "string" && ps.trim()) return ps;',
'    const pt = pano["texto"];',
'    if (typeof pt === "string" && pt.trim()) return pt;',
'  }',
'  return "";',
'}',
'',
'export default async function Page({ params }: { params: Promise<{ slug: string }> }) {',
'  const { slug } = await params;',
'',
'  let data: Awaited<ReturnType<typeof getCaderno>>;',
'  try {',
'    data = await getCaderno(slug);',
'  } catch (e) {',
'    const err = e as { code?: string };',
'    if (err && err.code === "ENOENT") return notFound();',
'    throw e;',
'  }',
'',
'  const title = data.meta?.title ?? slug;',
'  const accent = data.meta?.accent ?? "#F7C600";',
'  const s: AccentStyle = { ["--accent"]: accent } as AccentStyle;',
'  const summary = pickSummary(data as unknown);',
'',
'  return (',
'    <main style={{ padding: 14, maxWidth: 1100, margin: "0 auto", ...s }}>',
'      <V2Nav slug={slug} />',
'      <div style={{ marginTop: 12 }}>',
'        <HomeV2 slug={slug} title={title} summary={summary} />',
'      </div>',
'    </main>',
'  );',
'}'
)
WriteFileLines "src\app\c\[slug]\v2\page.tsx" $page

# 3) VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# 4) REPORT (sem quotes/backticks perigosos)
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Step D1 — Home V2 Hub (v0_70)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que entrou") | Out-Null
$rep.Add("- Hub V2 em /c/[slug]/v2 com 3 portas (Mapa, Provas, Debate).") | Out-Null
$rep.Add("- Atalhos para Linha do tempo e Trilhas, e link para abrir V1.") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null

$rp = WriteReport "cv-step-d1-homev2-hub-v0_70.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Step D1 aplicado e verificado."