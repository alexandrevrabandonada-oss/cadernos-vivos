# CV — V2 Tijolo D6 — Trilhas V2 (derive) — v0_30
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

$repo = Get-Location
$bootstrap = Join-Path $repo "tools\_bootstrap.ps1"
if (-not (Test-Path -LiteralPath $bootstrap)) { throw "[STOP] tools/_bootstrap.ps1 não encontrado." }
. $bootstrap

Write-Host ("[DIAG] Repo: " + $repo)

# paths
$trilhasLib = Join-Path $repo "src\lib\v2\trilhas.ts"
$indexLib   = Join-Path $repo "src\lib\v2\index.ts"
$listPage   = Join-Path $repo "src\app\c\[slug]\v2\trilhas\page.tsx"
$detailPage = Join-Path $repo "src\app\c\[slug]\v2\trilhas\[id]\page.tsx"

# 1) src/lib/v2/trilhas.ts
if (Test-Path -LiteralPath $trilhasLib) { BackupFile $trilhasLib | Out-Null }
$trilhasLines = @(
'/* eslint-disable @typescript-eslint/consistent-type-imports */',
'',
'export type TrailV2 = {',
'  id: string;',
'  title: string;',
'  summary?: string;',
'  steps?: string[];',
'  tags?: string[];',
'};',
'',
'function isObj(v: unknown): v is Record<string, unknown> {',
'  return !!v && typeof v === "object" && !Array.isArray(v);',
'}',
'',
'function asStr(v: unknown): string {',
'  return typeof v === "string" ? v : "";',
'}',
'',
'function asStrArr(v: unknown): string[] {',
'  if (!Array.isArray(v)) return [];',
'  return v.filter((x) => typeof x === "string").map((x) => String(x).trim()).filter(Boolean);',
'}',
'',
'function normTrail(raw: unknown): TrailV2 | null {',
'  if (!isObj(raw)) return null;',
'  const id = asStr(raw["id"]) || asStr(raw["slug"]) || asStr(raw["key"]);',
'  const title = asStr(raw["title"]) || asStr(raw["name"]) || id;',
'  if (!id) return null;',
'  const summary = asStr(raw["summary"]) || asStr(raw["desc"]) || asStr(raw["description"]);',
'  const steps = asStrArr(raw["steps"]);',
'  const tags = asStrArr(raw["tags"]);',
'  return { id, title, summary: summary || undefined, steps: steps.length ? steps : undefined, tags: tags.length ? tags : undefined };',
'}',
'',
'function trailsFromArray(v: unknown): TrailV2[] {',
'  if (!Array.isArray(v)) return [];',
'  const out: TrailV2[] = [];',
'  for (const it of v) {',
'    const t = normTrail(it);',
'    if (t) out.push(t);',
'  }',
'  return out;',
'}',
'',
'function trailsFromMapNodes(mapa: unknown): TrailV2[] {',
'  if (!isObj(mapa)) return [];',
'  const nodes = mapa["nodes"];',
'  if (!Array.isArray(nodes)) return [];',
'  const out: TrailV2[] = [];',
'  for (const n of nodes) {',
'    if (!isObj(n)) continue;',
'    const tp = asStr(n["type"]);',
'    if (tp !== "trail") continue;',
'    const t = normTrail(n);',
'    if (t) out.push(t);',
'  }',
'  return out;',
'}',
'',
'export function getTrailsV2(caderno: unknown): TrailV2[] {',
'  if (!isObj(caderno)) return [];',
'',
'  // Preferências: caderno.trilhas → panorama.trilhas → meta.trilhas → mapa.nodes(type:"trail")',
'  const direct = trailsFromArray(caderno["trilhas"]);',
'  if (direct.length) return direct;',
'',
'  const panorama = caderno["panorama"];',
'  if (isObj(panorama)) {',
'    const p = trailsFromArray(panorama["trilhas"]);',
'    if (p.length) return p;',
'  }',
'',
'  const meta = caderno["meta"];',
'  if (isObj(meta)) {',
'    const m = trailsFromArray(meta["trilhas"]);',
'    if (m.length) return m;',
'  }',
'',
'  const mapa = caderno["mapa"];',
'  const fromNodes = trailsFromMapNodes(mapa);',
'  return fromNodes;',
'}',
'',
'export function getTrailByIdV2(caderno: unknown, id: string): TrailV2 | null {',
'  const list = getTrailsV2(caderno);',
'  const hit = list.find((t) => t.id === id);',
'  return hit || null;',
'}'
)
WriteLinesUtf8NoBom $trilhasLib $trilhasLines
Write-Host ("[OK] wrote: " + $trilhasLib)

# 2) export no src/lib/v2/index.ts
if (-not (Test-Path -LiteralPath $indexLib)) { throw ("[STOP] Não achei: " + $indexLib) }
$idxRaw = Get-Content -LiteralPath $indexLib -Raw
if ($idxRaw -notmatch 'export\s+\*\s+from\s+["'']\.\/trilhas["'']') {
  $bk = BackupFile $indexLib
  $idxRaw2 = $idxRaw.TrimEnd() + "`n" + 'export * from "./trilhas";' + "`n"
  WriteUtf8NoBom $indexLib $idxRaw2
  Write-Host ("[OK] patched: " + $indexLib + " (export ./trilhas)")
  if ($bk) { Write-Host ("[BK] " + $bk) }
} else {
  Write-Host ("[OK] index.ts já exporta ./trilhas")
}

# 3) page list: /v2/trilhas
if (Test-Path -LiteralPath $listPage) { BackupFile $listPage | Out-Null }
$listLines = @(
'import Link from "next/link";',
'import V2Nav from "@/components/v2/V2Nav";',
'import { loadCadernoV2 } from "@/lib/v2";',
'import { getTrailsV2 } from "@/lib/v2";',
'',
'function asTitle(v: unknown, fallback: string): string {',
'  if (typeof v === "string" && v.trim()) return v.trim();',
'  return fallback;',
'}',
'',
'export default async function Page(props: { params: { slug: string } }) {',
'  const slug = props.params.slug;',
'  const caderno = await loadCadernoV2(slug);',
'  const title = asTitle((caderno as Record<string, unknown>)["title"], slug);',
'  const trails = getTrailsV2(caderno);',
'',
'  return (',
'    <main style={{ maxWidth: 980, margin: "0 auto", padding: 16 }}>',
'      <header style={{ marginBottom: 12 }}>',
'        <div style={{ opacity: 0.7, fontSize: 12 }}>Caderno: {title}</div>',
'        <h1 style={{ margin: "6px 0 10px 0", letterSpacing: 0.2 }}>Trilhas</h1>',
'        <V2Nav slug={slug} active="trilhas" />',
'      </header>',
'',
'      {trails.length === 0 ? (',
'        <section style={{ border: "1px solid rgba(255,255,255,0.10)", borderRadius: 12, padding: 14, opacity: 0.9 }}>',
'          <div style={{ fontWeight: 700, marginBottom: 6 }}>Nenhuma trilha encontrada.</div>',
'          <div style={{ opacity: 0.8, lineHeight: 1.5 }}>',
'            Para aparecer aqui, você pode adicionar <code style={{ opacity: 0.9 }}>trilhas</code> no caderno (meta/panorama) ou criar nodes no mapa com <code style={{ opacity: 0.9 }}>type: "trail"</code>.',
'          </div>',
'          <div style={{ marginTop: 10, display: "flex", gap: 10, flexWrap: "wrap" }}>',
'            <Link href={"/c/" + slug + "/v2"} style={{ textDecoration: "underline" }}>Voltar ao V2 Home</Link>',
'            <Link href={"/c/" + slug + "/v2/mapa"} style={{ textDecoration: "underline" }}>Abrir Mapa</Link>',
'          </div>',
'        </section>',
'      ) : (',
'        <section style={{ display: "grid", gap: 12 }}>',
'          {trails.map((t) => (',
'            <article key={t.id} style={{ border: "1px solid rgba(255,255,255,0.10)", borderRadius: 12, padding: 14 }}>',
'              <div style={{ display: "flex", justifyContent: "space-between", gap: 12, alignItems: "baseline" }}>',
'                <div style={{ fontWeight: 800, letterSpacing: 0.2 }}>{t.title}</div>',
'                <div style={{ opacity: 0.6, fontSize: 12 }}>#{t.id}</div>',
'              </div>',
'              {t.summary ? <div style={{ marginTop: 6, opacity: 0.85, lineHeight: 1.55 }}>{t.summary}</div> : null}',
'              {t.tags && t.tags.length ? (',
'                <div style={{ marginTop: 8, display: "flex", gap: 8, flexWrap: "wrap", opacity: 0.85 }}>',
'                  {t.tags.map((tag) => (',
'                    <span key={tag} style={{ border: "1px solid rgba(255,255,255,0.12)", padding: "3px 8px", borderRadius: 999, fontSize: 12 }}>{tag}</span>',
'                  ))}',
'                </div>',
'              ) : null}',
'              <div style={{ marginTop: 10, display: "flex", gap: 10, flexWrap: "wrap" }}>',
'                <Link href={"/c/" + slug + "/v2/trilhas/" + t.id} style={{ textDecoration: "underline" }}>Abrir trilha</Link>',
'              </div>',
'            </article>',
'          ))}',
'        </section>',
'      )}',
'',
'      <footer style={{ marginTop: 18, opacity: 0.65, fontSize: 12 }}>',
'        <div>V2 • Trilhas derivadas do caderno (sem any).</div>',
'      </footer>',
'    </main>',
'  );',
'}'
)
WriteLinesUtf8NoBom $listPage $listLines
Write-Host ("[OK] wrote: " + $listPage)

# 4) page detail: /v2/trilhas/[id]
if (Test-Path -LiteralPath $detailPage) { BackupFile $detailPage | Out-Null }
$detailLines = @(
'import Link from "next/link";',
'import { notFound } from "next/navigation";',
'import V2Nav from "@/components/v2/V2Nav";',
'import { loadCadernoV2 } from "@/lib/v2";',
'import { getTrailByIdV2 } from "@/lib/v2";',
'',
'function asTitle(v: unknown, fallback: string): string {',
'  if (typeof v === "string" && v.trim()) return v.trim();',
'  return fallback;',
'}',
'',
'export default async function Page(props: { params: { slug: string; id: string } }) {',
'  const slug = props.params.slug;',
'  const id = props.params.id;',
'  const caderno = await loadCadernoV2(slug);',
'  const cTitle = asTitle((caderno as Record<string, unknown>)["title"], slug);',
'  const trail = getTrailByIdV2(caderno, id);',
'  if (!trail) return notFound();',
'',
'  const shareUrl = "/c/" + slug + "/v2/trilhas/" + trail.id;',
'',
'  return (',
'    <main style={{ maxWidth: 980, margin: "0 auto", padding: 16 }}>',
'      <header style={{ marginBottom: 12 }}>',
'        <div style={{ opacity: 0.7, fontSize: 12 }}>Caderno: {cTitle}</div>',
'        <h1 style={{ margin: "6px 0 10px 0", letterSpacing: 0.2 }}>{trail.title}</h1>',
'        <V2Nav slug={slug} active="trilhas" />',
'      </header>',
'',
'      <section style={{ border: "1px solid rgba(255,255,255,0.10)", borderRadius: 12, padding: 14 }}>',
'        {trail.summary ? <div style={{ opacity: 0.9, lineHeight: 1.6 }}>{trail.summary}</div> : null}',
'',
'        {trail.steps && trail.steps.length ? (',
'          <div style={{ marginTop: 12 }}>',
'            <div style={{ fontWeight: 800, marginBottom: 8 }}>Passos</div>',
'            <ol style={{ margin: 0, paddingLeft: 18, opacity: 0.9, lineHeight: 1.7 }}>',
'              {trail.steps.map((s, i) => (',
'                <li key={String(i) + s}>{s}</li>',
'              ))}',
'            </ol>',
'          </div>',
'        ) : null}',
'',
'        {trail.tags && trail.tags.length ? (',
'          <div style={{ marginTop: 12, display: "flex", gap: 8, flexWrap: "wrap", opacity: 0.9 }}>',
'            {trail.tags.map((tag) => (',
'              <span key={tag} style={{ border: "1px solid rgba(255,255,255,0.12)", padding: "3px 8px", borderRadius: 999, fontSize: 12 }}>{tag}</span>',
'            ))}',
'          </div>',
'        ) : null}',
'',
'        <div style={{ marginTop: 14, display: "flex", gap: 12, flexWrap: "wrap" }}>',
'          <Link href={"/c/" + slug + "/v2/trilhas"} style={{ textDecoration: "underline" }}>Voltar</Link>',
'          <Link href={shareUrl} style={{ textDecoration: "underline", opacity: 0.85 }}>Link</Link>',
'        </div>',
'      </section>',
'',
'      <footer style={{ marginTop: 18, opacity: 0.65, fontSize: 12 }}>',
'        <div>V2 • Trilha #{trail.id}</div>',
'      </footer>',
'    </main>',
'  );',
'}'
)
WriteLinesUtf8NoBom $detailPage $detailLines
Write-Host ("[OK] wrote: " + $detailPage)

# sanity: não pode sobrar "as any" nesses arquivos
$sanityFiles = @($trilhasLib, $listPage, $detailPage)
foreach ($f in $sanityFiles) {
  $t = Get-Content -LiteralPath $f -Raw
  if ($t.Contains(" as any") -or $t.Contains("(v as any)")) { throw ("[STOP] achou 'any' em: " + $f) }
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
& $verify

# REPORT
$rep = @(
"# CV — Tijolo D6 v0_30 — Trilhas V2 (derive)",
"",
"## O que entrega",
"- /c/[slug]/v2/trilhas: lista de trilhas",
"- /c/[slug]/v2/trilhas/[id]: detalhe da trilha",
"- lib: getTrailsV2 + getTrailByIdV2 (sem any)",
"",
"## Derivação (ordem)",
"1) caderno.trilhas",
"2) caderno.panorama.trilhas",
"3) caderno.meta.trilhas",
"4) caderno.mapa.nodes com type: ""trail""",
"",
"## Arquivos",
"- src/lib/v2/trilhas.ts (novo)",
"- src/lib/v2/index.ts (export)",
"- src/app/c/[slug]/v2/trilhas/page.tsx (reescrito)",
"- src/app/c/[slug]/v2/trilhas/[id]/page.tsx (reescrito)",
"",
"## Verify",
"- tools/cv-verify.ps1 (Guard → Lint → Build)",
""
) -join "`n"
WriteReport "cv-v2-tijolo-d6-trilhas-v2-derive-v0_30.md" $rep | Out-Null
Write-Host "[OK] D6 v0_30 aplicado e verificado."