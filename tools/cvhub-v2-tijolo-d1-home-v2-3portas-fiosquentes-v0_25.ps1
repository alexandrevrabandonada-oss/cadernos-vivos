# CV — V2 Tijolo D1 — Home V2 (3 portas + fios quentes) — v0_25
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

$repo = Get-Location
$bootstrap = Join-Path $repo "tools\_bootstrap.ps1"
if (-not (Test-Path -LiteralPath $bootstrap)) { throw "[STOP] tools/_bootstrap.ps1 não encontrado. Rode o tijolo infra antes." }
. $bootstrap

Write-Host ("[DIAG] Repo: " + $repo)

# Paths
$comp = Join-Path $repo "src\components\v2\HomeV2.tsx"
$page = Join-Path $repo "src\app\c\[slug]\v2\page.tsx"

if (-not (Test-Path -LiteralPath (Join-Path $repo "src"))) { throw "[STOP] não achei src/" }
EnsureDir (Split-Path -Parent $comp)
EnsureDir (Split-Path -Parent $page)

# 1) Component: HomeV2
$bk1 = BackupFile $comp

$compLines = @(
"import Link from ""next/link"";",
"",
"type Props = {",
"  slug: string;",
"  title?: string;",
"  panorama?: unknown;",
"};",
"",
"function asObj(v: unknown): Record<string, unknown> | null {",
"  return v && typeof v === ""object"" && !Array.isArray(v) ? (v as Record<string, unknown>) : null;",
"}",
"function asStr(v: unknown): string {",
"  return typeof v === ""string"" ? v : """";",
"}",
"function asArr(v: unknown): unknown[] {",
"  return Array.isArray(v) ? v : [];",
"}",
"",
"export default function HomeV2(props: Props) {",
"  const slug = props.slug;",
"  const title = props.title && props.title.trim().length ? props.title : ""Caderno"";",
"  const pano = asObj(props.panorama) || {};",
"  const hotRaw = (pano as any).hot; // unknown",
"  const hotArr = asArr(hotRaw)",
"    .map((x) => asStr(x))",
"    .filter((s) => s.trim().length)",
"    .slice(0, 6);",
"",
"  const fallbackHot = [",
"    ""Siga o fio pelo Mapa (nós, conexões, camadas)"",",
"    ""Cheque Provas/Acervo (documentos e fontes)"",",
"    ""Entre no Debate (registrar, perguntar, conectar)"",",
"  ];",
"",
"  const hot = hotArr.length ? hotArr : fallbackHot;",
"",
"  const card = (href: string, k: string, desc: string) => (",
"    <Link",
"      key={k}",
"      href={href}",
"      style={{",
"        display: ""block"",",
"        padding: 14,",
"        borderRadius: 14,",
"        border: ""1px solid rgba(255,255,255,0.10)"",",
"        background: ""rgba(255,255,255,0.04)"",",
"        textDecoration: ""none"",",
"      }}",
"    >",
"      <div style={{ fontSize: 12, opacity: 0.65, letterSpacing: 0.6 }}>PORTA</div>",
"      <div style={{ marginTop: 6, fontSize: 18, fontWeight: 700 }}>{k}</div>",
"      <div style={{ marginTop: 6, fontSize: 13, opacity: 0.8, lineHeight: 1.4 }}>{desc}</div>",
"    </Link>",
"  );",
"",
"  return (",
"    <div",
"      style={{",
"        padding: 16,",
"        borderRadius: 18,",
"        border: ""1px solid rgba(255,255,255,0.08)"",",
"        background: ""linear-gradient(180deg, rgba(255,255,255,0.06), rgba(255,255,255,0.02))"",",
"      }}",
"    >",
"      <header style={{ display: ""flex"", justifyContent: ""space-between"", gap: 12, flexWrap: ""wrap"" }}>",
"        <div>",
"          <div style={{ fontSize: 12, opacity: 0.7, letterSpacing: 0.8 }}>V2 • CONCRETO ZEN</div>",
"          <div style={{ marginTop: 6, fontSize: 22, fontWeight: 800 }}>{title}</div>",
"          <div style={{ marginTop: 6, opacity: 0.75, fontSize: 13, lineHeight: 1.4 }}>",
"            Três portas para entrar no universo. Tudo conectado: mapa → provas → debate.",
"          </div>",
"        </div>",
"        <div style={{ display: ""flex"", alignItems: ""flex-start"", gap: 10, flexWrap: ""wrap"" }}>",
"          <Link href={""/c/"" + slug} style={{ textDecoration: ""underline"", opacity: 0.85 }}>",
"            Ver V1",
"          </Link>",
"          <Link href={""/c/"" + slug + ""/status""} style={{ textDecoration: ""underline"", opacity: 0.85 }}>",
"            Status",
"          </Link>",
"        </div>",
"      </header>",
"",
"      <section style={{ marginTop: 14 }}>",
"        <div style={{ display: ""grid"", gridTemplateColumns: ""repeat(auto-fit, minmax(220px, 1fr))"", gap: 12 }}>",
"          {card(""/c/"" + slug + ""/v2/mapa"", ""Mapa"", ""Canvas + painel + dock. Navegue pelos nós e conexões."")}",
"          {card(""/c/"" + slug + ""/v2/provas"", ""Provas"", ""Documentos, links e trechos — base pra não virar opinião solta."")}",
"          {card(""/c/"" + slug + ""/v2/debate"", ""Debate"", ""Conversa em camadas. Perguntas, respostas, sínteses."")}",
"        </div>",
"      </section>",
"",
"      <section style={{ marginTop: 14, display: ""flex"", gap: 10, flexWrap: ""wrap"" }}>",
"        <Link href={""/c/"" + slug + ""/v2/linha-do-tempo""} style={{ textDecoration: ""underline"", opacity: 0.9 }}>",
"          Linha do tempo",
"        </Link>",
"        <Link href={""/c/"" + slug + ""/v2/trilhas""} style={{ textDecoration: ""underline"", opacity: 0.9 }}>",
"          Trilhas",
"        </Link>",
"      </section>",
"",
"      <section style={{ marginTop: 14 }}>",
"        <div style={{ fontSize: 12, opacity: 0.7, letterSpacing: 0.8 }}>FIOS QUENTES</div>",
"        <ul style={{ marginTop: 8, paddingLeft: 18, opacity: 0.85, lineHeight: 1.6 }}>",
"          {hot.map((h, i) => (",
"            <li key={i}>{h}</li>",
"          ))}",
"        </ul>",
"      </section>",
"",
"      <footer style={{ marginTop: 14, opacity: 0.6, fontSize: 12 }}>",
"        Dica: se algo quebrar, rode <code>tools/cv-verify.ps1</code> (guard + lint + build).",
"      </footer>",
"    </div>",
"  );",
"}"
)

WriteUtf8NoBom $comp ($compLines -join "`n")
Write-Host ("[OK] wrote: " + $comp)
if ($bk1) { Write-Host ("[BK] " + $bk1) }

# 2) Page: /c/[slug]/v2 (Home)
$bk2 = BackupFile $page

$pageLines = @(
"import V2Nav from ""@/components/v2/V2Nav"";",
"import HomeV2 from ""@/components/v2/HomeV2"";",
"import { loadCadernoV2 } from ""@/lib/v2"";",
"",
"export default async function Page(props: { params: { slug: string } }) {",
"  const slug = props.params.slug;",
"  const data = await loadCadernoV2(slug);",
"  const title = (data && (data as any).meta && (data as any).meta.title) ? String((data as any).meta.title) : ""Caderno"";",
"  const panorama = data ? (data as any).panorama : null;",
"",
"  return (",
"    <main style={{ padding: 16 }}>",
"      <V2Nav slug={slug} active=""home"" />",
"      <section style={{ marginTop: 14 }}>",
"        <HomeV2 slug={slug} title={title} panorama={panorama} />",
"      </section>",
"    </main>",
"  );",
"}"
)

WriteUtf8NoBom $page ($pageLines -join "`n")
Write-Host ("[OK] wrote: " + $page)
if ($bk2) { Write-Host ("[BK] " + $bk2) }

# 3) VERIFY
RunCmd "pwsh" @("-NoProfile","-ExecutionPolicy","Bypass","-File",(Join-Path $repo "tools\cv-verify.ps1"))

# 4) REPORT
$report = @(
"# CV — V2 Tijolo D1 v0_25 — Home V2 (3 portas + fios quentes)",
"",
"## O que entrou",
"- Componente: src/components/v2/HomeV2.tsx",
"- Página: src/app/c/[slug]/v2/page.tsx",
"",
"## UX",
"- 3 portas principais: Mapa / Provas / Debate",
"- Links rápidos: Linha do tempo / Trilhas",
"- Fios quentes: lê panorama.hot (se existir) ou usa fallback",
"",
"## Verify",
"- tools/cv-verify.ps1 (guard + lint + build)",
""
) -join "`n"

WriteReport "cv-v2-tijolo-d1-home-v2-3portas-fiosquentes-v0_25.md" $report | Out-Null
Write-Host "[OK] v0_25 aplicado e verificado."