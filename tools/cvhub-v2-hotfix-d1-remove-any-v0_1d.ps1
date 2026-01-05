# CV — V2 — Hotfix D1: remover "any" nas páginas V2 — v0_1d
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

function EnsureDir($p){ if(-not(Test-Path -LiteralPath $p)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function WriteUtf8NoBom($path,$text){
  EnsureDir (Split-Path -Parent $path)
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($path,$text,$enc)
}
function BackupFile($path){
  if(-not(Test-Path -LiteralPath $path)){ return $null }
  $bkRoot = Join-Path (Get-Location) "tools\_patch_backup"
  EnsureDir $bkRoot
  $stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
  $name = (Split-Path -Leaf $path)
  if ($name -match '\.tsx?$') { $name = $name + ".bak" }
  $dest = Join-Path $bkRoot ($stamp + "-" + $name)
  Copy-Item -LiteralPath $path -Destination $dest -Force
  return $dest
}
function Run([string]$exe,[string[]]$a){
  Write-Host ("[RUN] " + $exe + " " + ($a -join " "))
  & $exe @a
  if($LASTEXITCODE -ne 0){ throw ("[STOP] falhou (exit " + $LASTEXITCODE + "): " + $exe + " " + ($a -join " ")) }
}

$repo = Get-Location
Write-Host ("[DIAG] Repo: " + $repo)

$cmd = Get-Command "npm.cmd" -ErrorAction SilentlyContinue
$npmExe = if ($cmd) { $cmd.Source } else { "npm.cmd" }
Write-Host ("[DIAG] npm: " + $npmExe)

$v2HomePath   = Join-Path $repo "src\app\c\[slug]\v2\page.tsx"
$v2MapaPath   = Join-Path $repo "src\app\c\[slug]\v2\mapa\page.tsx"
$v2DebatePath = Join-Path $repo "src\app\c\[slug]\v2\debate\page.tsx"
$v2ProvasPath = Join-Path $repo "src\app\c\[slug]\v2\provas\page.tsx"

Write-Host ("[DIAG] v2 home: " + $v2HomePath)
Write-Host ("[DIAG] v2 mapa: " + $v2MapaPath)
Write-Host ("[DIAG] v2 debate: " + $v2DebatePath)
Write-Host ("[DIAG] v2 provas: " + $v2ProvasPath)

# -------------------------
# PATCH 1: Home V2 sem "any"
# -------------------------
EnsureDir (Split-Path -Parent $v2HomePath)
$bk1 = BackupFile $v2HomePath

$homeLines = @(
'import Link from "next/link";',
'import { loadCadernoV2 } from "@/lib/v2";',
'import type { UiDefault } from "@/lib/v2/types";',
'',
'type HotWire = { label: string; text: string };',
'',
'function asObj(v: unknown): Record<string, unknown> | null {',
'  if (!v || typeof v !== "object") return null;',
'  return v as Record<string, unknown>;',
'}',
'function asStr(v: unknown): string | null {',
'  return typeof v === "string" ? v : null;',
'}',
'function asUiDefault(v: unknown): UiDefault | null {',
'  return v === "v1" || v === "v2" ? v : null;',
'}',
'',
'function extractHotWires(md: string): HotWire[] {',
'  const out: HotWire[] = [];',
'  const lines = (md || "").split(/\r?\n/);',
'',
'  const clean = (s: string) => s.replace(/^\s*[-*]\s+/, "").trim();',
'  const isHeading = (s: string) => /^#{1,6}\s+/.test(s);',
'  const isHr = (s: string) => /^\s*---+\s*$/.test(s);',
'',
'  for (let i = 0; i < lines.length; i++) {',
'    const line = lines[i].trim();',
'    if (!line || isHr(line)) continue;',
'    if (line.startsWith("## ") || line.startsWith("### ")) {',
'      const label = line.replace(/^#{2,3}\s+/, "").trim() || "Fio";',
'      let text = "";',
'      for (let j = i + 1; j < lines.length; j++) {',
'        const nxt = lines[j].trim();',
'        if (!nxt || isHr(nxt)) continue;',
'        if (isHeading(nxt)) break;',
'        text = clean(nxt);',
'        if (text) break;',
'      }',
'      if (label && text) out.push({ label, text });',
'      if (out.length >= 3) break;',
'    }',
'  }',
'',
'  if (out.length === 0) {',
'    const picks: string[] = [];',
'    for (let i = 0; i < lines.length; i++) {',
'      const line = lines[i].trim();',
'      if (!line || isHr(line) || isHeading(line)) continue;',
'      picks.push(clean(line));',
'      if (picks.length >= 3) break;',
'    }',
'    for (let i = 0; i < picks.length; i++) {',
'      out.push({ label: "Fio " + (i + 1), text: picks[i] });',
'    }',
'  }',
'',
'  return out;',
'}',
'',
'export default async function Page({ params }: { params: Promise<{ slug: string }> }) {',
'  const { slug } = await params;',
'',
'  let title = slug;',
'  let subtitle: string | null = null;',
'  let uiDefault: UiDefault = "v2";',
'  let panorama = "";',
'',
'  try {',
'    const c = await loadCadernoV2(slug);',
'    const cObj = asObj(c);',
'    const metaObj = asObj(cObj ? cObj["meta"] : null);',
'',
'    title = asStr(metaObj ? metaObj["title"] : null) || slug;',
'    subtitle = asStr(metaObj ? metaObj["subtitle"] : null);',
'',
'    const uiObj = asObj(metaObj ? metaObj["ui"] : null);',
'    uiDefault = asUiDefault(uiObj ? uiObj["default"] : null) || "v2";',
'',
'    panorama = asStr(cObj ? cObj["panorama"] : null) || "";',
'  } catch {',
'    // ok',
'  }',
'',
'  const doors = [',
'    { href: "/c/" + slug + "/v2/mapa", title: "Mapa", desc: "nós + fios + camadas" },',
'    { href: "/c/" + slug + "/v2/debate", title: "Debate", desc: "posições + perguntas + síntese" },',
'    { href: "/c/" + slug + "/v2/provas", title: "Provas", desc: "acervo + evidências + filtros" },',
'  ];',
'',
'  const fios = extractHotWires(panorama);',
'',
'  return (',
'    <main style={{ padding: 24, maxWidth: 1040, margin: "0 auto" }}>',
'      <header style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", gap: 16, flexWrap: "wrap" }}>',
'        <div>',
'          <div style={{ opacity: 0.75, fontSize: 12, letterSpacing: "0.08em", textTransform: "uppercase" }}>Concreto Zen • V2</div>',
'          <h1 style={{ fontSize: 30, fontWeight: 900, letterSpacing: "-0.03em", marginTop: 6 }}>{title}</h1>',
'          {subtitle ? <p style={{ marginTop: 6, opacity: 0.85 }}>{subtitle}</p> : null}',
'        </div>',
'        <nav style={{ display: "flex", gap: 12, flexWrap: "wrap", alignItems: "center" }}>',
'          <span style={{ opacity: 0.65, fontSize: 12 }}>meta.ui.default: <b>{uiDefault}</b></span>',
'          <Link href={"/c/" + slug} style={{ textDecoration: "underline" }}>← V1</Link>',
'        </nav>',
'      </header>',
'',
'      <section style={{ marginTop: 18, display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))", gap: 12 }}>',
'        {doors.map((d) => (',
'          <Link key={d.href} href={d.href} style={{',
'            textDecoration: "none",',
'            border: "1px solid rgba(255,255,255,0.14)",',
'            borderRadius: 14,',
'            padding: 14,',
'            display: "block",',
'          }}>',
'            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", gap: 10 }}>',
'              <div style={{ fontSize: 18, fontWeight: 900, letterSpacing: "-0.02em" }}>{d.title}</div>',
'              <div style={{ opacity: 0.55, fontSize: 12 }}>entrar →</div>',
'            </div>',
'            <div style={{ marginTop: 8, opacity: 0.8, fontSize: 13 }}>{d.desc}</div>',
'          </Link>',
'        ))}',
'      </section>',
'',
'      <section style={{ marginTop: 16, border: "1px solid rgba(255,255,255,0.12)", borderRadius: 14, padding: 14 }}>',
'        <div style={{ display: "flex", justifyContent: "space-between", gap: 12, flexWrap: "wrap", alignItems: "baseline" }}>',
'          <h2 style={{ fontSize: 16, fontWeight: 900, margin: 0, letterSpacing: "-0.01em" }}>Fios quentes (Panorama)</h2>',
'          <span style={{ opacity: 0.6, fontSize: 12 }}>puxados automaticamente do panorama.md</span>',
'        </div>',
'        {fios.length ? (',
'          <div style={{ marginTop: 10, display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(240px, 1fr))", gap: 10 }}>',
'            {fios.map((f, idx) => (',
'              <div key={idx} style={{ border: "1px solid rgba(255,255,255,0.10)", borderRadius: 12, padding: 12 }}>',
'                <div style={{ opacity: 0.65, fontSize: 12, textTransform: "uppercase", letterSpacing: "0.08em" }}>{f.label}</div>',
'                <div style={{ marginTop: 6, fontSize: 14, opacity: 0.9 }}>{f.text}</div>',
'              </div>',
'            ))}',
'          </div>',
'        ) : (',
'          <p style={{ marginTop: 10, opacity: 0.75 }}>',
'            Ainda não tem “fios” detectáveis. Coloca alguns ## títulos no panorama.md e aparece aqui.',
'          </p>',
'        )}',
'      </section>',
'',
'      <footer style={{ marginTop: 18, opacity: 0.6, fontSize: 12 }}>',
'        Próximo: Tijolo D2 (Mapa V2: canvas + painel + dock).',
'      </footer>',
'    </main>',
'  );',
'}',
''
) -join "`n"

WriteUtf8NoBom $v2HomePath $homeLines
Write-Host "[OK] patched: Home V2 (sem any)"
if ($bk1) { Write-Host ("[BK] " + $bk1) }

# -------------------------
# PATCH 2: Placeholders sem "any"
# -------------------------
function WritePlaceholder([string]$path,[string]$title,[string]$hint){
  EnsureDir (Split-Path -Parent $path)
  $bk = BackupFile $path

  $lines = @(
'import Link from "next/link";',
'import { loadCadernoV2 } from "@/lib/v2";',
'',
'function asObj(v: unknown): Record<string, unknown> | null {',
'  if (!v || typeof v !== "object") return null;',
'  return v as Record<string, unknown>;',
'}',
'function asStr(v: unknown): string | null {',
'  return typeof v === "string" ? v : null;',
'}',
'',
'export default async function Page({ params }: { params: Promise<{ slug: string }> }) {',
'  const { slug } = await params;',
'  let cTitle = slug;',
'  try {',
'    const c = await loadCadernoV2(slug);',
'    const cObj = asObj(c);',
'    const metaObj = asObj(cObj ? cObj["meta"] : null);',
'    cTitle = asStr(metaObj ? metaObj["title"] : null) || slug;',
'  } catch {',
'    // ok',
'  }',
'  return (',
'    <main style={{ padding: 24, maxWidth: 1040, margin: "0 auto" }}>',
'      <header style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", gap: 16, flexWrap: "wrap" }}>',
'        <div>',
'          <div style={{ opacity: 0.75, fontSize: 12, letterSpacing: "0.08em", textTransform: "uppercase" }}>Concreto Zen • V2</div>',
'          <h1 style={{ fontSize: 26, fontWeight: 900, letterSpacing: "-0.03em", marginTop: 6 }}>' + $title + '</h1>',
'          <p style={{ marginTop: 6, opacity: 0.85 }}>{cTitle}</p>',
'        </div>',
'        <nav style={{ display: "flex", gap: 12, flexWrap: "wrap" }}>',
'          <Link href={"/c/" + slug + "/v2"} style={{ textDecoration: "underline" }}>← Home V2</Link>',
'          <Link href={"/c/" + slug} style={{ textDecoration: "underline" }}>V1</Link>',
'        </nav>',
'      </header>',
'      <section style={{ marginTop: 16, border: "1px solid rgba(255,255,255,0.12)", borderRadius: 14, padding: 14 }}>',
'        <p style={{ margin: 0, opacity: 0.8 }}>' + $hint + '</p>',
'      </section>',
'    </main>',
'  );',
'}',
''
  ) -join "`n"

  WriteUtf8NoBom $path $lines
  Write-Host ("[OK] patched placeholder: " + $path)
  if ($bk) { Write-Host ("[BK] " + $bk) }
}

WritePlaceholder $v2MapaPath "Mapa V2" "Em breve: canvas + painel lateral + dock (Tijolo D2)."
WritePlaceholder $v2DebatePath "Debate V2" "Em breve: perguntas + posições + provas (Tijolo D3)."
WritePlaceholder $v2ProvasPath "Provas V2" "Em breve: galeria + filtros + preview (Tijolo D4)."

# -------------------------
# VERIFY
# -------------------------
Run $npmExe @("run","lint")
Run $npmExe @("run","build")

# -------------------------
# REPORT
# -------------------------
$reports = Join-Path $repo "reports"
EnsureDir $reports
$reportPath = Join-Path $reports "cv-v2-hotfix-d1-remove-any-v0_1d.md"
$report = @(
  '# CV — V2 — Hotfix D1 — remover any (ESLint no-explicit-any)',
  '',
  '## Fix',
  '- Removeu cast "as any" das páginas V2 (Home/Mapa/Debate/Provas).',
  '- Substituiu por unknown + guards (asObj/asStr/asUiDefault).',
  '',
  '## Arquivos',
  '- src/app/c/[slug]/v2/page.tsx',
  '- src/app/c/[slug]/v2/mapa/page.tsx',
  '- src/app/c/[slug]/v2/debate/page.tsx',
  '- src/app/c/[slug]/v2/provas/page.tsx',
  '',
  '## Verify',
  '- npm run lint',
  '- npm run build',
  ''
) -join "`n"
WriteUtf8NoBom $reportPath $report
Write-Host ("[OK] Report: " + $reportPath)
Write-Host "[OK] Hotfix v0_1d aplicado."