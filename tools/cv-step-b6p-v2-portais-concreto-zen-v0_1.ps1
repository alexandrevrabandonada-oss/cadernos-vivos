# cv-step-b6p-v2-portais-concreto-zen-v0_1
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = (Get-Location).Path
$stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")

# Preferir bootstrap se existir
$boot = Join-Path $repoRoot "tools\_bootstrap.ps1"
if (Test-Path -LiteralPath $boot) { . $boot }

function EnsureDirLocal([string]$p) { if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function WriteUtf8NoBomLocal([string]$file, [string]$content) {
  $dir = Split-Path -Parent $file
  if ($dir) { EnsureDirLocal $dir }
  [IO.File]::WriteAllText($file, $content, [Text.UTF8Encoding]::new($false))
}
function BackupFileLocal([string]$file) {
  $bkDir = Join-Path $repoRoot "tools\_patch_backup"
  EnsureDirLocal $bkDir
  $leaf = (Split-Path -Leaf $file) -replace '[\\\/:]', '_'
  $bk = Join-Path $bkDir ("$stamp-$leaf.bak")
  Copy-Item -LiteralPath $file -Destination $bk -Force
  return $bk
}

function EnsureDir([string]$p) { if (Get-Command EnsureDir -ErrorAction SilentlyContinue) { Microsoft.PowerShell.Utility\Write-Output $null } ; EnsureDirLocal $p }
function WriteUtf8NoBom([string]$file,[string]$content) { WriteUtf8NoBomLocal $file $content }
function Write-Utf8NoBom([string]$file,[string]$content) { WriteUtf8NoBomLocal $file $content }
function BackupFile([string]$file) { return (BackupFileLocal $file) }
function Backup-File([string]$file) { return (BackupFileLocal $file) }

# ------------------------------------------------------------
# DIAG
# ------------------------------------------------------------
Write-Host ("== cv-step-b6p-v2-portais-concreto-zen-v0_1 == " + $stamp)
Write-Host ("[DIAG] Repo: " + $repoRoot)

$v2Dir = Join-Path $repoRoot "src\app\c\[slug]\v2"
if (-not (Test-Path -LiteralPath $v2Dir)) { throw "[STOP] não achei src/app/c/[slug]/v2" }

$pages = Get-ChildItem -LiteralPath $v2Dir -Recurse -File -Filter page.tsx
Write-Host ("[DIAG] pages.tsx: " + $pages.Count)

# ------------------------------------------------------------
# PATCH 1: Ensure V2Portals.tsx (canônico)
# ------------------------------------------------------------
$portalsRel = "src\components\v2\V2Portals.tsx"
$portals = Join-Path $repoRoot $portalsRel

$portalsLines = @(
'import Link from "next/link";',
'',
'export type V2PortalItem = { href: string; label: string; desc?: string; hot?: boolean };',
'',
'function clamp(n: number, a: number, b: number) { return Math.max(a, Math.min(b, n)); }',
'',
'function itemsFor(slug: string, current?: string): V2PortalItem[] {',
'  const base = "/c/" + encodeURIComponent(slug) + "/v2";',
'  const all: V2PortalItem[] = [',
'    { href: base, label: "Hub", desc: "Visão geral do universo", hot: current !== "hub" },',
'    { href: base + "/mapa", label: "Mapa", desc: "Explorar por lugares/portas", hot: current !== "mapa" },',
'    { href: base + "/linha", label: "Linha", desc: "Fatos e nós principais", hot: current !== "linha" },',
'    { href: base + "/linha-do-tempo", label: "Linha do tempo", desc: "Ordem, causa, contexto", hot: current !== "linha-do-tempo" },',
'    { href: base + "/provas", label: "Provas", desc: "Fontes e evidências", hot: current !== "provas" },',
'    { href: base + "/trilhas", label: "Trilhas", desc: "Caminhos guiados", hot: current !== "trilhas" },',
'    { href: base + "/debate", label: "Debate", desc: "Camadas de conversa", hot: current !== "debate" },',
'  ];',
'  return all.filter(i => i.hot);',
'}',
'',
'export default function V2Portals(props: { slug: string; current?: string; title?: string }) {',
'  const slug = props.slug;',
'  const current = props.current;',
'  const title = (typeof props.title === "string" && props.title.trim().length) ? props.title.trim() : "Próximas portas";',
'  const items = itemsFor(slug, current);',
'  const count = clamp(items.length, 3, 8);',
'  return (',
'    <section style={{ marginTop: 18, paddingTop: 14, borderTop: "1px solid rgba(255,255,255,0.10)" }} aria-label="Portais">', 
'      <div style={{ display: "flex", alignItems: "baseline", justifyContent: "space-between", gap: 12 }}>',
'        <h2 style={{ margin: 0, fontSize: 14, letterSpacing: 0.3, opacity: 0.92 }}>{title}</h2>',
'        <span style={{ fontSize: 12, opacity: 0.65 }}>Concreto Zen • navegação por portas</span>',
'      </div>',
'      <div style={{ marginTop: 10, display: "grid", gap: 10, gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))" }}>',
'        {items.slice(0, count).map((it) => (',
'          <Link key={it.href} href={it.href} style={{',
'            display: "block",',
'            textDecoration: "none",',
'            color: "inherit",',
'            border: "1px solid rgba(255,255,255,0.10)",',
'            borderRadius: 12,',
'            padding: 12,',
'            background: "rgba(0,0,0,0.22)",',
'          }}>',
'            <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 10 }}>',
'              <strong style={{ fontSize: 13, letterSpacing: 0.2 }}>{it.label}</strong>',
'              <span style={{ fontSize: 12, opacity: 0.65 }}>→</span>',
'            </div>',
'            {it.desc ? <div style={{ marginTop: 6, fontSize: 12, opacity: 0.72, lineHeight: 1.25 }}>{it.desc}</div> : null}',
'          </Link>',
'        ))}',
'      </div>',
'    </section>',
'  );',
'}'
)

$needWritePortals = $true
if (Test-Path -LiteralPath $portals) {
  $existing = Get-Content -Raw -LiteralPath $portals
  if ($existing -match "export\s+default\s+function\s+V2Portals" -and $existing -match "itemsFor") { $needWritePortals = $false }
}
if ($needWritePortals) {
  if (Test-Path -LiteralPath $portals) {
    $bk = Backup-File $portals
    Write-Host ("[BK]    tools\_patch_backup\" + (Split-Path -Leaf $bk))
  }
  WriteUtf8NoBom $portals ($portalsLines -join "`n")
  Write-Host ("[PATCH] " + $portalsRel)
} else {
  Write-Host "[SKIP] V2Portals.tsx já parece canônico"
}

# ------------------------------------------------------------
# PATCH 2: Inject V2Portals into V2 pages (safe)
# ------------------------------------------------------------
$patched = @()

function GuessCurrent([string]$fullPath) {
  $rel = $fullPath.Substring($repoRoot.Length + 1).Replace("\","/")
  if ($rel -match "/v2/page\.tsx$") { return "hub" }
  if ($rel -match "/v2/mapa/page\.tsx$") { return "mapa" }
  if ($rel -match "/v2/linha-do-tempo/page\.tsx$") { return "linha-do-tempo" }
  if ($rel -match "/v2/linha/page\.tsx$") { return "linha" }
  if ($rel -match "/v2/provas/page\.tsx$") { return "provas" }
  if ($rel -match "/v2/trilhas/page\.tsx$") { return "trilhas" }
  if ($rel -match "/v2/trilhas/\[id\]/page\.tsx$") { return "trilhas" }
  if ($rel -match "/v2/debate/page\.tsx$") { return "debate" }
  return ""
}

foreach ($f in $pages) {
  $raw = Get-Content -Raw -LiteralPath $f.FullName
  if ($raw -match "<V2Portals\b") { continue }

  $lines = $raw -split "`r?`n"

  # ensure import
  $hasImport = ($raw -match 'from\s+"@/components/v2/V2Portals"')
  if (-not $hasImport) {
    $lastImp = -1
    for ($i=0; $i -lt $lines.Length; $i++) {
      if ($lines[$i].TrimStart().StartsWith("import ")) { $lastImp = $i }
    }
    if ($lastImp -ge 0) {
      $new = @()
      if ($lastImp -gt 0) { $new += $lines[0..$lastImp] } else { $new += $lines[0] }
      $new += 'import V2Portals from "@/components/v2/V2Portals";'
      if ($lastImp + 1 -le $lines.Length-1) { $new += $lines[($lastImp+1)..($lines.Length-1)] }
      $lines = $new
    }
  }

  # insert before </main>
  $closeIdx = -1
  for ($i=$lines.Length-1; $i -ge 0; $i--) {
    if ($lines[$i] -match "^\s*</main>\s*$") { $closeIdx = $i; break }
  }
  if ($closeIdx -lt 0) {
    Write-Host ("[WARN] sem </main>: " + $f.FullName.Substring($repoRoot.Length+1))
    continue
  }

  $indent = ([regex]::Match($lines[$closeIdx], '^\s*')).Value
  $current = GuessCurrent $f.FullName
  $ins = $indent + '<V2Portals slug={slug} current="' + $current + '" />'

  $new2 = @()
  if ($closeIdx -gt 0) { $new2 += $lines[0..($closeIdx-1)] }
  $new2 += $ins
  $new2 += $lines[$closeIdx..($lines.Length-1)]
  $p2 = ($new2 -join "`n")

  if ($p2 -ne $raw) {
    $bk = Backup-File $f.FullName
    WriteUtf8NoBom $f.FullName $p2
    $rel = $f.FullName.Substring($repoRoot.Length+1)
    $patched += $rel
    Write-Host ("[PATCH] " + $rel)
    Write-Host ("[BK]    tools\_patch_backup\" + (Split-Path -Leaf $bk))
  }
}

# ------------------------------------------------------------
# VERIFY (npm via cmd.exe para não dar "Unknown command")
# ------------------------------------------------------------
$npmPath = (where.exe npm | Select-Object -First 1)
if (-not $npmPath) { $npmPath = "npm" }

Write-Host "[RUN] npm run lint"
$lintOut = (cmd.exe /d /s /c "`"$npmPath`" run lint" 2>&1 | Out-String)
$lintExit = $LASTEXITCODE
if ($lintExit -ne 0) { Write-Host $lintOut; throw ("[STOP] lint falhou (exit=" + $lintExit + ")") }

Write-Host "[RUN] npm run build"
$buildOut = (cmd.exe /d /s /c "`"$npmPath`" run build" 2>&1 | Out-String)
$buildExit = $LASTEXITCODE
if ($buildExit -ne 0) { Write-Host $buildOut; throw ("[STOP] build falhou (exit=" + $buildExit + ")") }

# ------------------------------------------------------------
# REPORT
# ------------------------------------------------------------
$repDir = Join-Path $repoRoot "reports"
EnsureDirLocal $repDir
$rep = Join-Path $repDir ($stamp + "-cv-b6p-v2-portais-concreto-zen.md")

$body = @(
  ("# CV B6P — V2 Portais Concreto Zen — " + $stamp),
  "",
  ("Repo: " + $repoRoot),
  "",
  "## PATCH",
  ("- Ensured: " + $portalsRel),
  "- Patched pages:",
  ($patched | ForEach-Object { "  - " + $_ }),
  "",
  "## VERIFY",
  ("- lint exit: " + $lintExit),
  ("- build exit: " + $buildExit),
  "",
  "--- LINT OUTPUT START ---",
  $lintOut.TrimEnd(),
  "--- LINT OUTPUT END ---",
  "",
  "--- BUILD OUTPUT START ---",
  $buildOut.TrimEnd(),
  "--- BUILD OUTPUT END ---",
  ""
) -join "`n"

WriteUtf8NoBomLocal $rep $body
Write-Host ("[REPORT] reports\" + (Split-Path -Leaf $rep))
Write-Host "[OK] B6P concluído (Portais Concreto Zen injetados nas páginas V2)."