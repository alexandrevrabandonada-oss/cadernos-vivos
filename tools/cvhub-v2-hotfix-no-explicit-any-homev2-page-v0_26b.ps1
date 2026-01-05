# CV — V2 Hotfix — remover no-explicit-any (HomeV2 + /v2 page) — v0_26b
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

$repo = Get-Location
$bootstrap = Join-Path $repo "tools\_bootstrap.ps1"
if (-not (Test-Path -LiteralPath $bootstrap)) { throw "[STOP] tools/_bootstrap.ps1 não encontrado." }
. $bootstrap

Write-Host ("[DIAG] Repo: " + $repo)

$homeFile = Join-Path $repo "src\components\v2\HomeV2.tsx"
$v2PageFile = Join-Path $repo "src\app\c\[slug]\v2\page.tsx"

EnsureDir (Split-Path -Parent $homeFile)
EnsureDir (Split-Path -Parent $v2PageFile)

# 1) HomeV2.tsx (sem any)
$bk1 = BackupFile $homeFile

$homeLines = @(
'import Link from "next/link";',
'',
'type Props = {',
'  slug: string;',
'  title?: string;',
'  panorama?: unknown;',
'};',
'',
'function asObj(v: unknown): Record<string, unknown> | null {',
'  return v && typeof v === "object" && !Array.isArray(v) ? (v as Record<string, unknown>) : null;',
'}',
'function asStr(v: unknown): string {',
'  return typeof v === "string" ? v : "";',
'}',
'function asArr(v: unknown): unknown[] {',
'  return Array.isArray(v) ? v : [];',
'}',
'',
'export default function HomeV2(props: Props) {',
'  const slug = props.slug;',
'  const title = props.title && props.title.trim().length ? props.title : "Caderno";',
'  const pano: Record<string, unknown> = asObj(props.panorama) || {};',
'',
'  const hotRaw = pano["hot"];',
'  const hotArr = asArr(hotRaw)',
'    .map((x) => asStr(x))',
'    .filter((s) => s.trim().length)',
'    .slice(0, 6);',
'',
'  const fallbackHot = [',
'    "Siga o fio pelo Mapa (nós, conexões, camadas)",',
'    "Cheque Provas/Acervo (documentos e fontes)",',
'    "Entre no Debate (registrar, perguntar, conectar)",',
'  ];',
'',
'  const hot = hotArr.length ? hotArr : fallbackHot;',
'',
'  const card = (href: string, k: string, desc: string) => (',
'    <Link',
'      key={k}',
'      href={href}',
'      style={{',
'        display: "block",',
'        padding: 14,',
'        borderRadius: 14,',
'        border: "1px solid rgba(255,255,255,0.10)",',
'        background: "rgba(255,255,255,0.04)",',
'        textDecoration: "none",',
'      }}',
'    >',
'      <div style={{ fontSize: 12, opacity: 0.65, letterSpacing: 0.6 }}>PORTA</div>',
'      <div style={{ marginTop: 6, fontSize: 18, fontWeight: 700 }}>{k}</div>',
'      <div style={{ marginTop: 6, fontSize: 13, opacity: 0.8, lineHeight: 1.4 }}>{desc}</div>',
'    </Link>',
'  );',
'',
'  return (',
'    <div',
'      style={{',
'        padding: 16,',
'        borderRadius: 18,',
'        border: "1px solid rgba(255,255,255,0.08)",',
'        background: "linear-gradient(180deg, rgba(255,255,255,0.06), rgba(255,255,255,0.02))",',
'      }}',
'    >',
'      <header style={{ display: "flex", justifyContent: "space-between", gap: 12, flexWrap: "wrap" }}>',
'        <div>',
'          <div style={{ fontSize: 12, opacity: 0.7, letterSpacing: 0.8 }}>V2 • CONCRETO ZEN</div>',
'          <div style={{ marginTop: 6, fontSize: 22, fontWeight: 800 }}>{title}</div>',
'          <div style={{ marginTop: 6, opacity: 0.75, fontSize: 13, lineHeight: 1.4 }}>',
'            Três portas para entrar no universo. Tudo conectado: mapa → provas → debate.',
'          </div>',
'        </div>',
'        <div style={{ display: "flex", alignItems: "flex-start", gap: 10, flexWrap: "wrap" }}>',
'          <Link href={"/c/" + slug} style={{ textDecoration: "underline", opacity: 0.85 }}>',
'            Ver V1',
'          </Link>',
'          <Link href={"/c/" + slug + "/status"} style={{ textDecoration: "underline", opacity: 0.85 }}>',
'            Status',
'          </Link>',
'        </div>',
'      </header>',
'',
'      <section style={{ marginTop: 14 }}>',
'        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))", gap: 12 }}>',
'          {card("/c/" + slug + "/v2/mapa", "Mapa", "Canvas + painel + dock. Navegue pelos nós e conexões.")}',
'          {card("/c/" + slug + "/v2/provas", "Provas", "Documentos, links e trechos — base pra não virar opinião solta.")}',
'          {card("/c/" + slug + "/v2/debate", "Debate", "Conversa em camadas. Perguntas, respostas, sínteses.")}',
'        </div>',
'      </section>',
'',
'      <section style={{ marginTop: 14, display: "flex", gap: 10, flexWrap: "wrap" }}>',
'        <Link href={"/c/" + slug + "/v2/linha-do-tempo"} style={{ textDecoration: "underline", opacity: 0.9 }}>',
'          Linha do tempo',
'        </Link>',
'        <Link href={"/c/" + slug + "/v2/trilhas"} style={{ textDecoration: "underline", opacity: 0.9 }}>',
'          Trilhas',
'        </Link>',
'      </section>',
'',
'      <section style={{ marginTop: 14 }}>',
'        <div style={{ fontSize: 12, opacity: 0.7, letterSpacing: 0.8 }}>FIOS QUENTES</div>',
'        <ul style={{ marginTop: 8, paddingLeft: 18, opacity: 0.85, lineHeight: 1.6 }}>',
'          {hot.map((h, i) => (',
'            <li key={i}>{h}</li>',
'          ))}',
'        </ul>',
'      </section>',
'',
'      <footer style={{ marginTop: 14, opacity: 0.6, fontSize: 12 }}>',
'        Dica: se algo quebrar, rode <code>tools/cv-verify.ps1</code> (guard + lint + build).',
'      </footer>',
'    </div>',
'  );',
'}'
)

WriteUtf8NoBom $homeFile ($homeLines -join "`n")
Write-Host ("[OK] wrote: " + $homeFile)
if ($bk1) { Write-Host ("[BK] " + $bk1) }

# 2) /v2/page.tsx (sem any)
$bk2 = BackupFile $v2PageFile

$pageLines = @(
'import V2Nav from "@/components/v2/V2Nav";',
'import HomeV2 from "@/components/v2/HomeV2";',
'import { loadCadernoV2 } from "@/lib/v2";',
'',
'function asObj(v: unknown): Record<string, unknown> | null {',
'  return v && typeof v === "object" && !Array.isArray(v) ? (v as Record<string, unknown>) : null;',
'}',
'function asStr(v: unknown): string {',
'  return typeof v === "string" ? v : "";',
'}',
'',
'export default async function Page(props: { params: { slug: string } }) {',
'  const slug = props.params.slug;',
'  const data: unknown = await loadCadernoV2(slug);',
'  const root = asObj(data);',
'  const meta = root ? asObj(root["meta"]) : null;',
'  const title = (meta && asStr(meta["title"]).trim().length) ? asStr(meta["title"]) : "Caderno";',
'  const panorama = root ? root["panorama"] : null;',
'',
'  return (',
'    <main style={{ padding: 16 }}>',
'      <V2Nav slug={slug} active="home" />',
'      <section style={{ marginTop: 14 }}>',
'        <HomeV2 slug={slug} title={title} panorama={panorama} />',
'      </section>',
'    </main>',
'  );',
'}'
)

WriteUtf8NoBom $v2PageFile ($pageLines -join "`n")
Write-Host ("[OK] wrote: " + $v2PageFile)
if ($bk2) { Write-Host ("[BK] " + $bk2) }

# 3) VERIFY
RunCmd "pwsh" @("-NoProfile","-ExecutionPolicy","Bypass","-File",(Join-Path $repo "tools\cv-verify.ps1"))

# 4) REPORT
$report = @(
"# CV — Hotfix v0_26b — remove no-explicit-any (HomeV2 + /v2)",
"",
"## Causa raiz",
"- PowerShell é case-insensitive: `$home` conflita com `$HOME` (read-only).",
"- ESLint @typescript-eslint/no-explicit-any não permite (data as any) / (pano as any).",
"",
"## Fix",
"- Renomeou variáveis PowerShell para `$homeFile` e `$v2PageFile`.",
"- HomeV2: Record<string, unknown> + pano['hot'] (sem any).",
"- /v2 page: helpers asObj/asStr e extração segura (sem any).",
"",
"## Verify",
"- tools/cv-verify.ps1 (guard + lint + build)",
""
) -join "`n"

WriteReport "cv-v2-hotfix-no-explicit-any-homev2-page-v0_26b.md" $report | Out-Null
Write-Host "[OK] v0_26b aplicado e verificado."