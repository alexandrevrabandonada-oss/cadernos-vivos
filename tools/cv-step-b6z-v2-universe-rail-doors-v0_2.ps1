# cv-step-b6z-v2-universe-rail-doors-v0_2
$ErrorActionPreference = "Stop"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Write-Host ("== cv-step-b6z-v2-universe-rail-doors-v0_2 == " + $stamp)

$repoRoot = (Resolve-Path ".").Path

# ------------------------------------------------------------
# bootstrap
# ------------------------------------------------------------
$boot = Join-Path $repoRoot "tools\_bootstrap.ps1"
if (Test-Path -LiteralPath $boot) {
  . $boot
} else {
  function EnsureDir([string]$p){ [IO.Directory]::CreateDirectory($p) | Out-Null }
  function WriteUtf8NoBom([string]$p,[string]$c){ $enc=New-Object System.Text.UTF8Encoding($false); [IO.File]::WriteAllText($p,$c,$enc) }
  function BackupFile([string]$p){
    $bkDir = Join-Path $repoRoot "tools\_patch_backup"
    EnsureDir $bkDir
    $leaf = Split-Path -Leaf $p
    $dest = Join-Path $bkDir ($stamp + "-" + $leaf + ".bak")
    Copy-Item -LiteralPath $p -Destination $dest -Force
    return $dest
  }
}

function RunNpm([string[]]$npmArgs) {
  $npm = (Get-Command npm.cmd -ErrorAction Stop).Path
  $out = (& $npm @npmArgs 2>&1 | Out-String)
  return @{ out=$out; code=$LASTEXITCODE }
}

function InferActive([string]$abs) {
  $p = $abs.Replace("\","/").ToLowerInvariant()
  if ($p -match "/v2/mapa/page\.tsx$") { return "mapa" }
  if ($p -match "/v2/linha-do-tempo/page\.tsx$") { return "linha-do-tempo" }
  if ($p -match "/v2/linha/page\.tsx$") { return "linha" }
  if ($p -match "/v2/provas/page\.tsx$") { return "provas" }
  if ($p -match "/v2/trilhas/\[id\]/page\.tsx$") { return "trilhas" }
  if ($p -match "/v2/trilhas/page\.tsx$") { return "trilhas" }
  if ($p -match "/v2/debate/page\.tsx$") { return "debate" }
  if ($p -match "/v2/page\.tsx$") { return "hub" }
  return "hub"
}

Write-Host ("[DIAG] Repo: " + $repoRoot)

# ------------------------------------------------------------
# PATCH A: component Cv2UniverseRail
# ------------------------------------------------------------
$compRel = "src\components\v2\Cv2UniverseRail.tsx"
$compAbs = Join-Path $repoRoot $compRel
EnsureDir (Split-Path -Parent $compAbs)

$comp = @(
'import Link from "next/link";',
'',
'type DoorKey = "hub" | "mapa" | "linha" | "linha-do-tempo" | "provas" | "trilhas" | "debate";',
'',
'type Door = {',
'  key: DoorKey;',
'  label: string;',
'  hint: string;',
'  href: (slug: string) => string;',
'};',
'',
'const DOORS: Door[] = [',
'  { key: "hub", label: "Hub", hint: "Visão geral do universo", href: (slug) => "/c/" + slug + "/v2" },',
'  { key: "mapa", label: "Mapa", hint: "Eixo de exploração (map-first)", href: (slug) => "/c/" + slug + "/v2/mapa" },',
'  { key: "linha", label: "Linha", hint: "Narrativa em blocos", href: (slug) => "/c/" + slug + "/v2/linha" },',
'  { key: "linha-do-tempo", label: "Tempo", hint: "Cronologia e eventos", href: (slug) => "/c/" + slug + "/v2/linha-do-tempo" },',
'  { key: "provas", label: "Provas", hint: "Fontes, anexos, evidências", href: (slug) => "/c/" + slug + "/v2/provas" },',
'  { key: "trilhas", label: "Trilhas", hint: "Caminhos guiados", href: (slug) => "/c/" + slug + "/v2/trilhas" },',
'  { key: "debate", label: "Debate", hint: "Camadas de conversa", href: (slug) => "/c/" + slug + "/v2/debate" },',
'];',
'',
'export default function Cv2UniverseRail(props: { slug: string; active?: string; current?: string; title?: string }) {',
'  const activeRaw = (props.active ?? props.current ?? "hub").toString();',
'  const active = (DOORS.some(d => d.key === (activeRaw as DoorKey)) ? (activeRaw as DoorKey) : "hub");',
'  const idx = Math.max(0, DOORS.findIndex(d => d.key === active));',
'  const prev = idx > 0 ? DOORS[idx - 1] : undefined;',
'  const next = idx >= 0 && idx < DOORS.length - 1 ? DOORS[idx + 1] : undefined;',
'',
'  return (',
'    <aside className="cv2-rail" data-cv2-static="1" aria-label="Navegação do universo">',
'      <div className="cv2-rail__top">',
'        <div className="cv2-rail__kicker">Concreto Zen</div>',
'        <div className="cv2-rail__title">{props.title ? props.title : "Universo"}</div>',
'      </div>',
'',
'      <nav className="cv2-rail__nav">',
'        {DOORS.map((d) => {',
'          const on = d.key === active;',
'          const cls = on ? "cv2-rail__link cv2-rail__link--on" : "cv2-rail__link";',
'          return (',
'            <Link key={d.key} className={cls} href={d.href(props.slug)} title={d.hint}>',
'              <span className="cv2-rail__dot" aria-hidden="true" />',
'              <span className="cv2-rail__label">{d.label}</span>',
'              <span className="cv2-rail__hint">{d.hint}</span>',
'            </Link>',
'          );',
'        })}',
'      </nav>',
'',
'      <div className="cv2-rail__cta">',
'        <Link className="cv2-rail__ctaLink" href={"/c/" + props.slug + "/v2/mapa"}>',
'          Mapa é o eixo →',
'        </Link>',
'      </div>',
'',
'      <div className="cv2-rail__next">',
'        <div className="cv2-rail__nextTitle">Próximas portas</div>',
'        <div className="cv2-rail__nextRow">',
'          {prev ? <Link className="cv2-rail__pill" href={prev.href(props.slug)}>← {prev.label}</Link> : <span className="cv2-rail__pill cv2-rail__pill--off">←</span>}',
'          {next ? <Link className="cv2-rail__pill" href={next.href(props.slug)}>{next.label} →</Link> : <span className="cv2-rail__pill cv2-rail__pill--off">→</span>}',
'        </div>',
'      </div>',
'    </aside>',
'  );',
'}',
''
) -join "`n"

if (-not (Test-Path -LiteralPath $compAbs)) {
  WriteUtf8NoBom $compAbs ($comp.TrimEnd() + "`n")
  Write-Host ("[PATCH] " + $compRel)
} else {
  $existing = Get-Content -LiteralPath $compAbs -Raw
  if ($existing -notmatch "Cv2UniverseRail") {
    $bk = BackupFile $compAbs
    WriteUtf8NoBom $compAbs ($comp.TrimEnd() + "`n")
    Write-Host ("[PATCH] " + $compRel + " (overwrite missing/old)")
    Write-Host ("[BK]    tools/_patch_backup/" + (Split-Path -Leaf $bk))
  } else {
    Write-Host ("[SKIP] " + $compRel + " já existe.")
  }
}

# ------------------------------------------------------------
# PATCH B: globals.css (layout + rail)
# ------------------------------------------------------------
$globalsRel = "src\app\globals.css"
$globalsAbs = Join-Path $repoRoot $globalsRel
if (-not (Test-Path -LiteralPath $globalsAbs)) { throw ("[STOP] não achei: " + $globalsAbs) }

$g = Get-Content -LiteralPath $globalsAbs -Raw
$marker = "/* CV2 UNIVERSE RAIL v0_1 */"
if ($g -notmatch [regex]::Escape($marker)) {
  $css = @(
'',
$marker,
'.cv2-layout{display:grid;grid-template-columns:280px 1fr;gap:16px;align-items:start;}',
'.cv2-rail{position:sticky;top:12px;align-self:start;border:1px solid rgba(255,255,255,.08);border-radius:14px;padding:12px;background:rgba(0,0,0,.35);backdrop-filter:saturate(1.2) blur(10px);}',
'.cv2-rail__kicker{font-size:12px;letter-spacing:.08em;text-transform:uppercase;opacity:.7;}',
'.cv2-rail__title{font-size:14px;font-weight:700;line-height:1.2;margin-top:2px;}',
'.cv2-rail__nav{display:grid;gap:8px;margin-top:10px;}',
'.cv2-rail__link{display:grid;grid-template-columns:10px 1fr;gap:10px;padding:10px;border-radius:12px;text-decoration:none;border:1px solid rgba(255,255,255,.06);}',
'.cv2-rail__link:hover{border-color:rgba(255,255,255,.14);transform:translateY(-1px);}',
'.cv2-rail__link--on{border-color:rgba(247,198,0,.35);box-shadow:0 0 0 1px rgba(247,198,0,.25) inset;}',
'.cv2-rail__dot{width:10px;height:10px;border-radius:999px;margin-top:4px;background:rgba(255,255,255,.25);}',
'.cv2-rail__link--on .cv2-rail__dot{background:rgba(247,198,0,.9);}',
'.cv2-rail__label{font-weight:700;font-size:13px;line-height:1.1;}',
'.cv2-rail__hint{display:block;font-size:12px;opacity:.75;margin-top:2px;line-height:1.2;}',
'.cv2-rail__cta{margin-top:12px;padding-top:10px;border-top:1px dashed rgba(255,255,255,.14);}',
'.cv2-rail__ctaLink{display:inline-block;text-decoration:none;font-weight:700;font-size:12px;padding:8px 10px;border-radius:999px;border:1px solid rgba(247,198,0,.25);}',
'.cv2-rail__ctaLink:hover{border-color:rgba(247,198,0,.5);}',
'.cv2-rail__next{margin-top:12px;}',
'.cv2-rail__nextTitle{font-size:12px;opacity:.75;margin-bottom:6px;}',
'.cv2-rail__nextRow{display:flex;gap:8px;flex-wrap:wrap;}',
'.cv2-rail__pill{display:inline-block;text-decoration:none;font-size:12px;padding:7px 10px;border-radius:999px;border:1px solid rgba(255,255,255,.12);}',
'.cv2-rail__pill:hover{border-color:rgba(255,255,255,.22);}',
'.cv2-rail__pill--off{opacity:.35;}',
"@media (max-width: 900px){",
'  .cv2-layout{grid-template-columns:1fr;}',
'  .cv2-rail{position:relative;top:auto;}',
'}',
''
) -join "`n"
  $bk2 = BackupFile $globalsAbs
  WriteUtf8NoBom $globalsAbs (($g.TrimEnd() + $css).TrimEnd() + "`n")
  Write-Host ("[PATCH] " + $globalsRel + " (append rail css)")
  Write-Host ("[BK]    tools/_patch_backup/" + (Split-Path -Leaf $bk2))
} else {
  Write-Host ("[SKIP] globals.css já tem marker CV2 UNIVERSE RAIL v0_1")
}

# ------------------------------------------------------------
# PATCH C: apply rail in pages V2 (skip filter + skip map)
# ------------------------------------------------------------
$v2Root = Join-Path $repoRoot "src\app\c\[slug]\v2"
$pages = Get-ChildItem -LiteralPath $v2Root -Recurse -Filter "page.tsx" | ForEach-Object { $_.FullName }

$patched = New-Object System.Collections.Generic.List[string]

foreach ($abs in $pages) {
  $raw = Get-Content -LiteralPath $abs -Raw
  if (-not $raw) { continue }

  if ($raw -match "Cv2MapRail") { continue }
  if ($raw -match "Cv2DomFilterClient") { continue }
  if ($raw -match "Cv2UniverseRail") { continue }
  if ($raw -notmatch "<main") { continue }
  if ($raw -notmatch "</main>") { continue }

  $active = InferActive $abs

  $lines = $raw -split "`r?`n"
  $importLine = 'import Cv2UniverseRail from "@/components/v2/Cv2UniverseRail";'
  $hasImport = $false
  foreach($l in $lines){ if ($l.Trim() -eq $importLine) { $hasImport = $true; break } }

  if (-not $hasImport) {
    $lastImport = -1
    for($i=0;$i -lt $lines.Count;$i++){
      if ($lines[$i].TrimStart().StartsWith("import ")) { $lastImport = $i }
    }
    if ($lastImport -ge 0) {
      $new = New-Object System.Collections.Generic.List[string]
      for($i=0;$i -lt $lines.Count;$i++){
        $new.Add($lines[$i]) | Out-Null
        if ($i -eq $lastImport) { $new.Add($importLine) | Out-Null }
      }
      $lines = $new.ToArray()
    }
  }

  $raw2 = ($lines -join "`n")

  $injectA = '<div className="cv2-layout">' + "`n" + '  <Cv2UniverseRail slug={slug} active="' + $active + '" />' + "`n" + '  <main'
  $raw2 = [regex]::Replace($raw2, "<main", $injectA, 1)
  $raw2 = [regex]::Replace($raw2, "</main>", "</main>`n</div>", 1)

  $bk = BackupFile $abs
  $rel = $abs.Substring($repoRoot.Length).TrimStart("\")
  Write-Host ("[PATCH] " + $rel + " (rail + layout)")
  Write-Host ("[BK]    tools/_patch_backup/" + (Split-Path -Leaf $bk))
  WriteUtf8NoBom $abs ($raw2.TrimEnd() + "`n")
  $patched.Add($rel) | Out-Null
}

if ($patched.Count -eq 0) {
  Write-Host "[WARN] Nenhuma page.tsx V2 elegível foi patchada (talvez todas tenham filtro/mapa ou já tenham rail)."
} else {
  Write-Host ("[DIAG] pages patched: " + $patched.Count)
}

# ------------------------------------------------------------
# VERIFY
# ------------------------------------------------------------
$verify = Join-Path $repoRoot "tools\cv-verify.ps1"
if (Test-Path -LiteralPath $verify) {
  Write-Host ("[RUN] " + $verify)
  & $verify
  if ($LASTEXITCODE -ne 0) { throw ("[STOP] cv-verify falhou (exit=" + $LASTEXITCODE + ")") }
}

Write-Host "[RUN] npm run lint"
$r1 = RunNpm @("run","lint")
Write-Host $r1.out
if ($r1.code -ne 0) { throw ("[STOP] lint falhou (exit=" + $r1.code + ")") }

Write-Host "[RUN] npm run build"
$r2 = RunNpm @("run","build")
Write-Host $r2.out
if ($r2.code -ne 0) { throw ("[STOP] build falhou (exit=" + $r2.code + ")") }

# ------------------------------------------------------------
# REPORT
# ------------------------------------------------------------
$repDir = Join-Path $repoRoot "reports"
EnsureDir $repDir
$rep = Join-Path $repDir ($stamp + "-cv-step-b6z-v2-universe-rail.md")

$body = @(
("# CV B6Z — V2 Universe Rail (Concreto Zen) — " + $stamp),
"",
("Repo: " + $repoRoot),
"",
"## PATCH",
("- component: " + $compRel),
("- css: " + $globalsRel),
"Pages patched:",
($patched | ForEach-Object { "  - " + $_ }),
"",
"## VERIFY",
("- lint exit: " + $r1.code),
("- build exit: " + $r2.code)
) -join "`n"

WriteUtf8NoBom $rep ($body + "`n")
Write-Host ("[REPORT] reports/" + (Split-Path -Leaf $rep))
Write-Host "[OK] B6Z concluído (Rail do Universo nas portas V2 elegíveis)."