# CV — V2 — Tijolo C — Shell V2 placeholder (/c/[slug]/v2) — v0_1
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
$npm = if ($cmd) { $cmd.Source } else { "npm.cmd" }
Write-Host ("[DIAG] npm: " + $npm)

$page = Join-Path $repo "src\app\c\[slug]\v2\page.tsx"
$libIndex = Join-Path $repo "src\lib\v2\index.ts"
Write-Host ("[DIAG] v2 page: " + $page)
Write-Host ("[DIAG] v2 index: " + $libIndex)

# PATCH: garantir export loadCadernoV2 (não destrutivo: só anexa se faltar)
if (Test-Path -LiteralPath $libIndex) {
  $raw = Get-Content -LiteralPath $libIndex -Raw
  if ($raw -notmatch 'loadCadernoV2') {
    $bk = BackupFile $libIndex
    $raw2 = $raw.TrimEnd() + "`n`nexport { loadCadernoV2 } from './load';`n"
    WriteUtf8NoBom $libIndex $raw2
    Write-Host "[OK] patched: src/lib/v2/index.ts (export loadCadernoV2)"
    if ($bk) { Write-Host ("[BK] " + $bk) }
  } else {
    Write-Host "[OK] src/lib/v2/index.ts já exporta loadCadernoV2"
  }
} else {
  EnsureDir (Split-Path -Parent $libIndex)
  WriteUtf8NoBom $libIndex "export { loadCadernoV2 } from './load';`n"
  Write-Host "[OK] wrote: src/lib/v2/index.ts"
}

# PATCH: criar página V2 placeholder
EnsureDir (Split-Path -Parent $page)
$bk2 = BackupFile $page

$codePage = @"
import Link from 'next/link';
import { loadCadernoV2 } from '@/lib/v2';

export default async function Page({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;

  let metaTitle = slug;
  let uiDefault: string = 'v2';

  try {
    const c = await loadCadernoV2(slug);
    metaTitle = c?.meta?.title || slug;
    uiDefault = c?.meta?.ui?.default || 'v2';
  } catch {
    // placeholder: se ainda não houver conteúdo V2 pro slug, não quebra
  }

  return (
    <main style={{ padding: 24, maxWidth: 980, margin: '0 auto' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: 16, flexWrap: 'wrap' }}>
        <h1 style={{ fontSize: 28, fontWeight: 800, letterSpacing: '-0.02em' }}>V2 — Concreto Zen</h1>
        <div style={{ display: 'flex', gap: 12 }}>
          <Link href={'/c/' + slug} style={{ textDecoration: 'underline' }}>← Voltar pra V1</Link>
        </div>
      </div>

      <p style={{ marginTop: 10, opacity: 0.85 }}>
        Placeholder do shell V2. Próximo tijolo: Home V2 (3 portas + fios quentes).
      </p>

      <div style={{ marginTop: 18, padding: 16, border: '1px solid rgba(255,255,255,0.15)', borderRadius: 12 }}>
        <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
          <span><b>slug:</b> {slug}</span>
          <span><b>title:</b> {metaTitle}</span>
          <span><b>meta.ui.default:</b> {uiDefault}</span>
        </div>
      </div>
    </main>
  );
}
"@

WriteUtf8NoBom $page $codePage
Write-Host "[OK] wrote: src/app/c/[slug]/v2/page.tsx"
if ($bk2) { Write-Host ("[BK] " + $bk2) }

# VERIFY
Run $npm @("run","lint")
Run $npm @("run","build")

# REPORT
$reports = Join-Path $repo "reports"
EnsureDir $reports
$reportPath = Join-Path $reports "cv-v2-tijolo-c-shell-v2-placeholder-v0_1.md"
$report = @(
  "# CV — V2 — Tijolo C — Shell V2 placeholder",
  "",
  "## O que entrou",
  "- Rota: /c/[slug]/v2 (placeholder)",
  "- Garantia de export: loadCadernoV2 em src/lib/v2/index.ts",
  "",
  "## Verify",
  "- npm run lint",
  "- npm run build",
  ""
) -join "`n"
WriteUtf8NoBom $reportPath $report
Write-Host ("[OK] Report: " + $reportPath)
Write-Host "[OK] Tijolo C aplicado."