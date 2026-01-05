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

# DIAG: confirma se getAcervo existe mesmo
$lib = Join-Path $repo "src\lib\cadernos.ts"
if (Test-Path -LiteralPath $lib) {
  $libRaw = Get-Content -LiteralPath $lib -Raw
  $hasGetAcervo = ($libRaw -match "export\s+(async\s+)?function\s+getAcervo\b") -or ($libRaw -match "export\s*\{\s*[^}]*\bgetAcervo\b")
  Write-Host ("[DIAG] cadernos.ts has getAcervo export? " + $hasGetAcervo)
} else {
  Write-Host ("[DIAG] cadernos.ts not found at: " + $lib)
}

# PATCH: reescreve a página /c/[slug]/v2/provas
$pageRel = "src\app\c\[slug]\v2\provas\page.tsx"

$page = @(
  'import { notFound } from "next/navigation";',
  'import type { CSSProperties } from "react";',
  'import { getCaderno } from "@/lib/cadernos";',
  'import V2Nav from "@/components/v2/V2Nav";',
  'import { ProvasV2 } from "@/components/v2/ProvasV2";',
  '',
  'type AccentStyle = CSSProperties & Record<"--accent", string>;',
  '',
  'function extractAcervoItems(data: unknown): unknown[] {',
  '  if (!data || typeof data !== "object") return [];',
  '  const r = data as Record<string, unknown>;',
  '',
  '  const direct = r["acervoItems"];',
  '  if (Array.isArray(direct)) return direct;',
  '',
  '  const ac = r["acervo"];',
  '  if (Array.isArray(ac)) return ac;',
  '  if (ac && typeof ac === "object") {',
  '    const ar = ac as Record<string, unknown>;',
  '    const items = ar["items"];',
  '    if (Array.isArray(items)) return items;',
  '  }',
  '',
  '  // fallback extra: alguns formatos podem retornar "provas" diretamente',
  '  const provas = r["provas"];',
  '  if (Array.isArray(provas)) return provas;',
  '',
  '  return [];',
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
  '',
  '  const items = extractAcervoItems(data);',
  '',
  '  return (',
  '    <main style={{ padding: 14, maxWidth: 1100, margin: "0 auto", ...s }}>',
  '      <V2Nav slug={slug} active="provas" />',
  '      <div style={{ marginTop: 12 }}>',
  '        <ProvasV2 slug={slug} title={title} items={items} />',
  '      </div>',
  '    </main>',
  '  );',
  '}'
)

WriteFileLines $pageRel $page

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Hotfix — V2 /provas sem getAcervo (v0_59)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que mudou") | Out-Null
$rep.Add("- Remove import getAcervo (nao existe em src/lib/cadernos.ts).") | Out-Null
$rep.Add("- /v2/provas agora usa getCaderno(slug) e extrai itens do acervo de forma tolerante (acervoItems | acervo.items | acervo | provas).") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null

$rp = WriteReport "cv-hotfix-v2-provas-remove-getacervo-v0_59.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Hotfix aplicado e verificado."