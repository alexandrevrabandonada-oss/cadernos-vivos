# CV — Tijolo V2 — V2Nav + corrigir hrefs /c//v2 no MapaV2 + Linha do Tempo V2 — v0_16
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

function EnsureDir([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}
function WriteUtf8NoBom([string]$path, [string]$text) {
  EnsureDir (Split-Path -Parent $path)
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($path, $text, $enc)
}
function WriteLines([string]$path, [string[]]$lines) {
  WriteUtf8NoBom $path ($lines -join "`n")
}
function BackupFile([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) { return $null }
  $bkRoot = Join-Path (Get-Location) "tools\_patch_backup"
  EnsureDir $bkRoot
  $stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
  $name = (Split-Path -Leaf $path)
  if ($name -match '\.tsx?$') { $name = $name + ".bak" }
  $dest = Join-Path $bkRoot ($stamp + "-" + $name)
  Copy-Item -LiteralPath $path -Destination $dest -Force
  return $dest
}
function RunCmd([string]$Exe, [string[]]$CmdArgs) {
  Write-Host ("[RUN] " + $Exe + " " + ($CmdArgs -join " "))
  & $Exe @CmdArgs
  if ($LASTEXITCODE -ne 0) { throw ("[STOP] falhou (exit " + $LASTEXITCODE + "): " + $Exe + " " + ($CmdArgs -join " ")) }
}
function EnsureDefaultExport([string]$filePath, [string]$symbol) {
  if (-not (Test-Path -LiteralPath $filePath)) { return }
  $raw = Get-Content -LiteralPath $filePath -Raw
  if ($raw -match 'export\s+default') { return }
  if ($raw -match ('\b' + [regex]::Escape($symbol) + '\b')) {
    $raw2 = $raw.TrimEnd() + "`n`nexport default " + $symbol + ";`n"
    WriteUtf8NoBom $filePath $raw2
    Write-Host ("[OK] appended default export: " + (Split-Path -Leaf $filePath) + " -> " + $symbol)
  }
}

$repo = Get-Location
Write-Host ("[DIAG] Repo: " + $repo)

$cmd = Get-Command "npm.cmd" -ErrorAction SilentlyContinue
$npm = if ($cmd) { $cmd.Source } else { "npm.cmd" }
Write-Host ("[DIAG] npm: " + $npm)

# -------------------------
# PATHS
# -------------------------
$v2Nav = Join-Path $repo "src\components\v2\V2Nav.tsx"
$mapComp = Join-Path $repo "src\components\v2\MapaV2.tsx"

$homeV2   = Join-Path $repo "src\app\c\[slug]\v2\page.tsx"
$mapaV2   = Join-Path $repo "src\app\c\[slug]\v2\mapa\page.tsx"
$debateV2 = Join-Path $repo "src\app\c\[slug]\v2\debate\page.tsx"
$provasV2 = Join-Path $repo "src\app\c\[slug]\v2\provas\page.tsx"
$linhaV2  = Join-Path $repo "src\app\c\[slug]\v2\linha-do-tempo\page.tsx"

Write-Host ("[DIAG] V2Nav: " + $v2Nav)
Write-Host ("[DIAG] MapaV2 comp: " + $mapComp)

# -------------------------
# PATCH 1 — Criar V2Nav (nav padrão, sem risco de /c//v2)
# -------------------------
$bkNav = if (Test-Path -LiteralPath $v2Nav) { BackupFile $v2Nav } else { $null }
EnsureDir (Split-Path -Parent $v2Nav)

$navLines = @(
'import Link from "next/link";',
'',
'type Active = "home" | "mapa" | "debate" | "provas" | "linha" | "trilhas";',
'',
'export default function V2Nav(props: { slug: string; active?: Active }) {',
'  const slug = props.slug;',
'  const a = props.active || "home";',
'',
'  const base = "/c/" + slug + "/v2";',
'  const items: Array<{ key: Active; label: string; href: string }> = [',
'    { key: "home",   label: "V2 Home",        href: base },',
'    { key: "mapa",   label: "Mapa",           href: base + "/mapa" },',
'    { key: "linha",  label: "Linha do tempo", href: base + "/linha-do-tempo" },',
'    { key: "debate", label: "Debate",         href: base + "/debate" },',
'    { key: "provas", label: "Provas",         href: base + "/provas" },',
'    { key: "trilhas",label: "Trilhas",        href: base + "/trilhas" }',
'  ];',
'',
'  return (',
'    <nav style={{',
'      display: "flex",',
'      gap: 10,',
'      flexWrap: "wrap",',
'      padding: "10px 0",',
'      borderBottom: "1px solid rgba(255,255,255,0.08)",',
'      marginBottom: 12,',
'      opacity: 0.92',
'    }}>',
'      {items.map((it) => {',
'        const on = it.key === a;',
'        return (',
'          <Link',
'            key={it.key}',
'            href={it.href}',
'            style={{',
'              textDecoration: "none",',
'              padding: "6px 10px",',
'              borderRadius: 10,',
'              border: "1px solid rgba(255,255,255,0.12)",',
'              background: on ? "rgba(255,255,255,0.08)" : "transparent",',
'              color: "inherit"',
'            }}',
'          >',
'            {it.label}',
'          </Link>',
'        );',
'      })}',
'    </nav>',
'  );',
'}',
''
)
WriteLines $v2Nav $navLines
Write-Host "[OK] wrote: src/components/v2/V2Nav.tsx"
if ($bkNav) { Write-Host ("[BK] " + $bkNav) }

# -------------------------
# PATCH 2 — Corrigir hrefs quebrados dentro do componente MapaV2.tsx (se existirem)
# -------------------------
if (Test-Path -LiteralPath $mapComp) {
  $bkMap = BackupFile $mapComp
  $raw = Get-Content -LiteralPath $mapComp -Raw
  $raw2 = $raw

  $raw2 = $raw2.Replace('href={/c//v2}',        'href={"/c/" + slug + "/v2"}')
  $raw2 = $raw2.Replace('href={/c//v2/debate}', 'href={"/c/" + slug + "/v2/debate"}')
  $raw2 = $raw2.Replace('href={/c//v2/provas}', 'href={"/c/" + slug + "/v2/provas"}')
  $raw2 = $raw2.Replace('href={/c//v2/trilhas}','href={"/c/" + slug + "/v2/trilhas"}')
  $raw2 = $raw2.Replace('href={/c//v2/mapa}',   'href={"/c/" + slug + "/v2/mapa"}')
  $raw2 = $raw2.Replace('href={/c//v2/linha-do-tempo}','href={"/c/" + slug + "/v2/linha-do-tempo"}')

  if ($raw2 -ne $raw) {
    WriteUtf8NoBom $mapComp $raw2
    Write-Host "[OK] patched: src/components/v2/MapaV2.tsx (hrefs corrigidos com slug)"
    if ($bkMap) { Write-Host ("[BK] " + $bkMap) }
  } else {
    Write-Host "[OK] MapaV2.tsx: nenhuma ocorrência href={/c//v2...} encontrada."
  }

  EnsureDefaultExport $mapComp "MapaV2"
} else {
  Write-Host "[WARN] src/components/v2/MapaV2.tsx não encontrado (pulando PATCH 2)."
}

# -------------------------
# PATCH 3 — Criar rota Linha do Tempo V2 (D5) e reescrever pages V2 para usar V2Nav
# -------------------------
function WriteV2Page([string]$filePath, [string[]]$lines) {
  EnsureDir (Split-Path -Parent $filePath)
  $bk = if (Test-Path -LiteralPath $filePath) { BackupFile $filePath } else { $null }
  WriteLines $filePath $lines
  Write-Host ("[OK] wrote: " + $filePath)
  if ($bk) { Write-Host ("[BK] " + $bk) }
}

# Home V2
$homeLines = @(
'import Link from "next/link";',
'import V2Nav from "@/components/v2/V2Nav";',
'import { loadCadernoV2 } from "@/lib/v2";',
'',
'export default async function Page(props: { params: { slug: string } }) {',
'  const slug = props.params.slug;',
'  const caderno = await loadCadernoV2(slug);',
'  const title = caderno?.meta?.title || slug;',
'  const subtitle = caderno?.meta?.subtitle || null;',
'',
'  return (',
'    <main style={{ padding: 18 }}>',
'      <header>',
'        <h1 style={{ margin: 0, fontSize: 22, letterSpacing: 0.2 }}>{title}</h1>',
'        {subtitle ? (',
'          <p style={{ margin: "6px 0 0 0", opacity: 0.75 }}>{subtitle}</p>',
'        ) : null}',
'      </header>',
'',
'      <V2Nav slug={slug} active="home" />',
'',
'      <section style={{ display: "grid", gap: 12, marginTop: 10 }}>',
'        <Link href={"/c/" + slug + "/v2/mapa"} style={{ textDecoration: "none", border: "1px solid rgba(255,255,255,0.12)", borderRadius: 16, padding: 14 }}>',
'          <div style={{ fontSize: 14, opacity: 0.7 }}>Porta 1</div>',
'          <div style={{ fontSize: 18, marginTop: 2 }}>Mapa</div>',
'          <div style={{ marginTop: 6, opacity: 0.7, lineHeight: 1.35 }}>Navegação por nós e conexões — o caderno como rede viva.</div>',
'        </Link>',
'',
'        <Link href={"/c/" + slug + "/v2/linha-do-tempo"} style={{ textDecoration: "none", border: "1px solid rgba(255,255,255,0.12)", borderRadius: 16, padding: 14 }}>',
'          <div style={{ fontSize: 14, opacity: 0.7 }}>Porta 2</div>',
'          <div style={{ fontSize: 18, marginTop: 2 }}>Linha do tempo</div>',
'          <div style={{ marginTop: 6, opacity: 0.7, lineHeight: 1.35 }}>Eventos derivados do mapa — continuidade, memória, causa e efeito.</div>',
'        </Link>',
'',
'        <Link href={"/c/" + slug + "/v2/debate"} style={{ textDecoration: "none", border: "1px solid rgba(255,255,255,0.12)", borderRadius: 16, padding: 14 }}>',
'          <div style={{ fontSize: 14, opacity: 0.7 }}>Porta 3</div>',
'          <div style={{ fontSize: 18, marginTop: 2 }}>Debate</div>',
'          <div style={{ marginTop: 6, opacity: 0.7, lineHeight: 1.35 }}>Perguntas e disputas do caderno — com trilhas para ação.</div>',
'        </Link>',
'      </section>',
'',
'      <footer style={{ marginTop: 16, opacity: 0.6, fontSize: 12 }}>',
'        <div style={{ display: "flex", gap: 10, flexWrap: "wrap" }}>',
'          <Link href={"/c/" + slug} style={{ textDecoration: "underline", color: "inherit" }}>Ver V1</Link>',
'          <Link href={"/c/" + slug + "/v2/provas"} style={{ textDecoration: "underline", color: "inherit" }}>Provas</Link>',
'          <Link href={"/c/" + slug + "/v2/trilhas"} style={{ textDecoration: "underline", color: "inherit" }}>Trilhas</Link>',
'        </div>',
'      </footer>',
'    </main>',
'  );',
'}',
''
)
WriteV2Page $homeV2 $homeLines

# Mapa V2 page (usa V2Nav e MapaV2 component)
$mapPageLines = @(
'import Link from "next/link";',
'import V2Nav from "@/components/v2/V2Nav";',
'import { loadCadernoV2 } from "@/lib/v2";',
'import MapaV2 from "@/components/v2/MapaV2";',
'',
'export default async function Page(props: { params: { slug: string } }) {',
'  const slug = props.params.slug;',
'  const caderno = await loadCadernoV2(slug);',
'  const title = caderno?.meta?.title || slug;',
'  const mapa = caderno?.mapa ?? null;',
'',
'  return (',
'    <main style={{ padding: 18 }}>',
'      <header style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", gap: 12 }}>',
'        <div>',
'          <h1 style={{ margin: 0, fontSize: 20 }}>Mapa — {title}</h1>',
'          <p style={{ margin: "6px 0 0 0", opacity: 0.7 }}>Canvas + painel + dock (V2 Concreto Zen).</p>',
'        </div>',
'        <Link href={"/c/" + slug + "/v2"} style={{ textDecoration: "underline", color: "inherit", opacity: 0.85 }}>Voltar</Link>',
'      </header>',
'',
'      <V2Nav slug={slug} active="mapa" />',
'      <MapaV2 slug={slug} mapa={mapa} />',
'    </main>',
'  );',
'}',
''
)
WriteV2Page $mapaV2 $mapPageLines

# Debate V2 page
$debateLines = @(
'import Link from "next/link";',
'import V2Nav from "@/components/v2/V2Nav";',
'import { loadCadernoV2 } from "@/lib/v2";',
'import DebateV2 from "@/components/v2/DebateV2";',
'',
'export default async function Page(props: { params: { slug: string } }) {',
'  const slug = props.params.slug;',
'  const caderno = await loadCadernoV2(slug);',
'  const title = caderno?.meta?.title || slug;',
'  const debate = caderno?.debate ?? null;',
'',
'  return (',
'    <main style={{ padding: 18 }}>',
'      <header style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", gap: 12 }}>',
'        <div>',
'          <h1 style={{ margin: 0, fontSize: 20 }}>Debate — {title}</h1>',
'          <p style={{ margin: "6px 0 0 0", opacity: 0.7 }}>Perguntas, tensões e caminhos.</p>',
'        </div>',
'        <Link href={"/c/" + slug + "/v2"} style={{ textDecoration: "underline", color: "inherit", opacity: 0.85 }}>Voltar</Link>',
'      </header>',
'',
'      <V2Nav slug={slug} active="debate" />',
'      <DebateV2 slug={slug} title={title} debate={debate} />',
'    </main>',
'  );',
'}',
''
)
WriteV2Page $debateV2 $debateLines
EnsureDefaultExport (Join-Path $repo "src\components\v2\DebateV2.tsx") "DebateV2"

# Provas V2 page
$provasLines = @(
'import Link from "next/link";',
'import V2Nav from "@/components/v2\V2Nav";',
'import { loadCadernoV2 } from "@/lib/v2";',
'import ProvasV2 from "@/components/v2\ProvasV2";',
'',
'export default async function Page(props: { params: { slug: string } }) {',
'  const slug = props.params.slug;',
'  const caderno = await loadCadernoV2(slug);',
'  const title = caderno?.meta?.title || slug;',
'  const acervo = caderno?.acervo ?? null;',
'',
'  return (',
'    <main style={{ padding: 18 }}>',
'      <header style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", gap: 12 }}>',
'        <div>',
'          <h1 style={{ margin: 0, fontSize: 20 }}>Provas — {title}</h1>',
'          <p style={{ margin: "6px 0 0 0", opacity: 0.7 }}>Acervo, links, documentos e rastros.</p>',
'        </div>',
'        <Link href={"/c/" + slug + "/v2"} style={{ textDecoration: "underline", color: "inherit", opacity: 0.85 }}>Voltar</Link>',
'      </header>',
'',
'      <V2Nav slug={slug} active="provas" />',
'      <ProvasV2 slug={slug} title={title} acervo={acervo} />',
'    </main>',
'  );',
'}',
''
)
# Corrige barras em imports (Windows path não pode vazar pro TS)
$provasLines = $provasLines | ForEach-Object { $_.Replace('"\V2Nav"', '"/V2Nav"').Replace('"\ProvasV2"', '"/ProvasV2"') }
WriteV2Page $provasV2 $provasLines
EnsureDefaultExport (Join-Path $repo "src\components\v2\ProvasV2.tsx") "ProvasV2"

# Linha do Tempo V2 page
$linhaLines = @(
'import Link from "next/link";',
'import V2Nav from "@/components/v2/V2Nav";',
'import { loadCadernoV2 } from "@/lib/v2";',
'import TimelineV2 from "@/components/v2/TimelineV2";',
'',
'export default async function Page(props: { params: { slug: string } }) {',
'  const slug = props.params.slug;',
'  const caderno = await loadCadernoV2(slug);',
'  const title = caderno?.meta?.title || slug;',
'  const mapa = caderno?.mapa ?? null;',
'',
'  return (',
'    <main style={{ padding: 18 }}>',
'      <header style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", gap: 12 }}>',
'        <div>',
'          <h1 style={{ margin: 0, fontSize: 20 }}>Linha do tempo — {title}</h1>',
'          <p style={{ margin: "6px 0 0 0", opacity: 0.7 }}>Derivada do mapa (eventos e datas).</p>',
'        </div>',
'        <Link href={"/c/" + slug + "/v2"} style={{ textDecoration: "underline", color: "inherit", opacity: 0.85 }}>Voltar</Link>',
'      </header>',
'',
'      <V2Nav slug={slug} active="linha" />',
'      <TimelineV2 slug={slug} title={title} mapa={mapa} />',
'    </main>',
'  );',
'}',
''
)
WriteV2Page $linhaV2 $linhaLines
EnsureDefaultExport (Join-Path $repo "src\components\v2\TimelineV2.tsx") "TimelineV2"

# -------------------------
# DIAG scan: garantir que não sobrou href={/c//v2...} em src
# -------------------------
Write-Host "[DIAG] scan src por href={/c//v2..."
$hits = Select-String -Path (Join-Path $repo "src\**\*.tsx") -SimpleMatch -Pattern 'href={/c//v2' -ErrorAction SilentlyContinue
if ($hits) {
  Write-Host "[WARN] Ainda existem ocorrências:"
  $hits | ForEach-Object { Write-Host (" - " + $_.Path + ":" + $_.LineNumber) }
} else {
  Write-Host "[OK] Nenhuma ocorrência encontrada."
}

# -------------------------
# VERIFY
# -------------------------
RunCmd $npm @("run","lint")
RunCmd $npm @("run","build")

# -------------------------
# REPORT
# -------------------------
EnsureDir (Join-Path $repo "reports")
$reportPath = Join-Path $repo "reports\cv-v2-tijolo-v2nav-hrefs-timeline-v0_16.md"
$report = @(
  '# CV — Tijolo v0_16 — V2Nav + hrefs corrigidos + Linha do Tempo V2',
  '',
  '## O que foi feito',
  '- Criou src/components/v2/V2Nav.tsx (nav padrão do V2).',
  '- Corrigiu hrefs quebrados dentro de src/components/v2/MapaV2.tsx (quando existiam).',
  '- Reescreveu pages do V2 para usar V2Nav e evitar regressão de href.',
  '- Criou /c/[slug]/v2/linha-do-tempo (D5) renderizando TimelineV2.',
  '- Garantiu export default (sem quebrar imports antigos).',
  '',
  '## Verify',
  '- npm run lint',
  '- npm run build',
  ''
) -join "`n"
WriteUtf8NoBom $reportPath $report
Write-Host ("[OK] Report: " + $reportPath)
Write-Host "[OK] v0_16 aplicado."