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

# HomeV2Hub.tsx — server-safe, exporta HubStats e aceita mapa/stats
$hubLines = @(
  'import Link from "next/link";',
  'import type { CSSProperties } from "react";',
  '',
  'type AnyObj = Record<string, unknown>;',
  '',
  'export type HubStats = {',
  '  nodes?: number;',
  '  proofs?: number;',
  '  trails?: number;',
  '  updatedAt?: string;',
  '};',
  '',
  'function isObj(v: unknown): v is AnyObj {',
  '  return !!v && typeof v === "object" && !Array.isArray(v);',
  '}',
  '',
  'function countFromMapa(mapa: unknown): number | undefined {',
  '  if (!mapa) return undefined;',
  '  if (Array.isArray(mapa)) return mapa.length;',
  '  if (isObj(mapa)) {',
  '    const nodes = (mapa as AnyObj)["nodes"];',
  '    if (Array.isArray(nodes)) return nodes.length;',
  '    const items = (mapa as AnyObj)["items"];',
  '    if (Array.isArray(items)) return items.length;',
  '    const timeline = (mapa as AnyObj)["timeline"];',
  '    if (Array.isArray(timeline)) return timeline.length;',
  '  }',
  '  return undefined;',
  '}',
  '',
  'const cardBase: CSSProperties = {',
  '  display: "block",',
  '  border: "1px solid rgba(255,255,255,0.12)",',
  '  borderRadius: 14,',
  '  padding: 14,',
  '  textDecoration: "none",',
  '  color: "inherit",',
  '  background: "rgba(0,0,0,0.22)",',
  '};',
  '',
  'export default function HomeV2Hub(props: { slug: string; title: string; mapa?: unknown; stats?: HubStats }) {',
  '  const { slug, title, mapa, stats } = props;',
  '  const nodes = typeof stats?.nodes === "number" ? stats.nodes : countFromMapa(mapa);',
  '  const proofs = stats?.proofs;',
  '  const trails = stats?.trails;',
  '',
  '  const grid: CSSProperties = {',
  '    display: "grid",',
  '    gap: 12,',
  '    gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))",',
  '    marginTop: 12,',
  '  };',
  '',
  '  const small: CSSProperties = { fontSize: 12, opacity: 0.78, marginTop: 8 };',
  '  const h: CSSProperties = { fontSize: 18, fontWeight: 800, letterSpacing: "-0.2px", marginTop: 6 };',
  '',
  '  return (',
  '    <section aria-label={"Hub V2: " + title}>',
  '      <div style={{ fontSize: 12, opacity: 0.75 }}>Concreto Zen • V2</div>',
  '      <div style={{ fontSize: 26, fontWeight: 900, letterSpacing: "-0.6px", marginTop: 6 }}>{title}</div>',
  '',
  '      <div style={grid}>',
  '        <Link href={"/c/" + slug + "/v2/mapa"} style={cardBase}>',
  '          <div style={{ fontSize: 12, opacity: 0.8 }}>Mapa</div>',
  '          <div style={h}>Explorar conexões</div>',
  '          <div style={small}>{typeof nodes === "number" ? (nodes + " nós detectados") : "abrir o mapa do caderno"}</div>',
  '        </Link>',
  '',
  '        <Link href={"/c/" + slug + "/v2/linha"} style={cardBase}>',
  '          <div style={{ fontSize: 12, opacity: 0.8 }}>Linha</div>',
  '          <div style={h}>Linha do tempo</div>',
  '          <div style={small}>ver eventos, etapas e marcos</div>',
  '        </Link>',
  '',
  '        <Link href={"/c/" + slug + "/v2/provas"} style={cardBase}>',
  '          <div style={{ fontSize: 12, opacity: 0.8 }}>Provas</div>',
  '          <div style={h}>Fontes e evidências</div>',
  '          <div style={small}>{typeof proofs === "number" ? (proofs + " itens") : "organizar referências e links"}</div>',
  '        </Link>',
  '',
  '        <Link href={"/c/" + slug + "/v2/trilhas"} style={cardBase}>',
  '          <div style={{ fontSize: 12, opacity: 0.8 }}>Trilhas</div>',
  '          <div style={h}>Trilhas práticas</div>',
  '          <div style={small}>{typeof trails === "number" ? (trails + " trilhas") : "passo a passo, missões e tarefas"}</div>',
  '        </Link>',
  '',
  '        <Link href={"/c/" + slug} style={{ ...cardBase, background: "rgba(255,255,255,0.06)" }}>',
  '          <div style={{ fontSize: 12, opacity: 0.85 }}>Voltar</div>',
  '          <div style={h}>Abrir versão V1</div>',
  '          <div style={small}>comparar e manter compatibilidade</div>',
  '        </Link>',
  '      </div>',
  '    </section>',
  '  );',
  '}'
)

WriteRel "src\components\v2\HomeV2Hub.tsx" $hubLines

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Fix — HomeV2Hub props mapa/stats (v0_98)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que foi corrigido") | Out-Null
$rep.Add("- HomeV2Hub exporta HubStats e aceita mapa/stats opcionais (corrige build de /v2/page).") | Out-Null
$rep.Add("- Evita variável reservada do PowerShell ($HOME).") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null
$rp = WriteReport "cv-fix-homev2hub-props-v0_98.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Fix aplicado e verificado."