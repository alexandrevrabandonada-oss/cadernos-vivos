# cv-step-b6x-v2-mapfirst-cta-everywhere-v0_1
$ErrorActionPreference = "Stop"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Write-Host ("== cv-step-b6x-v2-mapfirst-cta-everywhere-v0_1 == " + $stamp)

$repoRoot = (Resolve-Path ".").Path

# bootstrap
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

Write-Host ("[DIAG] Repo: " + $repoRoot)

# ------------------------------------------------------------
# PATCH: component
# ------------------------------------------------------------
$compRel = "src/components/v2/Cv2MapFirstCta.tsx"
$compAbs = Join-Path $repoRoot $compRel
EnsureDir (Split-Path -Parent $compAbs)

if (-not (Test-Path -LiteralPath $compAbs)) {
  $lines = @(
    'import Link from "next/link";',
    '',
    'type Props = {',
    '  slug: string;',
    '  current?: string;',
    '  title?: string;',
    '};',
    '',
    'export default function Cv2MapFirstCta(props: Props) {',
    '  const current = (props.current || "").trim();',
    '  if (current === "mapa") return null;',
    '  const href = "/c/" + props.slug + "/v2/mapa";',
    '  return (',
    '    <div className="cv2-mapfirst" role="note" aria-label="Comece pelo Mapa">',
    '      <div className="cv2-mapfirst__inner">',
    '        <div className="cv2-mapfirst__mark" aria-hidden="true">◎</div>',
    '        <div className="cv2-mapfirst__text">',
    '          <div className="cv2-mapfirst__title">Comece pelo Mapa</div>',
    '          <div className="cv2-mapfirst__sub">É onde as portas se conectam e a história ganha chão.</div>',
    '        </div>',
    '        <div className="cv2-mapfirst__actions">',
    '          <Link className="cv2-mapfirst__btn" href={href}>Abrir mapa</Link>',
    '        </div>',
    '      </div>',
    '    </div>',
    '  );',
    '}'
  )
  WriteUtf8NoBom $compAbs (($lines -join "`n") + "`n")
  Write-Host ("[PATCH] " + $compRel + " (new)")
} else {
  Write-Host ("[SKIP] " + $compRel + " já existe")
}

# ------------------------------------------------------------
# PATCH: globals.css (append)
# ------------------------------------------------------------
$globalsRel = "src/app/globals.css"
$globalsAbs = Join-Path $repoRoot $globalsRel
if (-not (Test-Path -LiteralPath $globalsAbs)) { throw ("[STOP] não achei: " + $globalsRel) }

$g = Get-Content -LiteralPath $globalsAbs -Raw
if (-not $g) { throw "[STOP] globals.css vazio" }

if ($g -notmatch "CV2_MAPFIRST_CTA") {
  $bk = BackupFile $globalsAbs
  Write-Host ("[BK]    tools/_patch_backup/" + (Split-Path -Leaf $bk))

  $css = @(
    '',
    '/* CV2_MAPFIRST_CTA v0_1 */',
    '.cv2-mapfirst{',
    '  margin: 10px 0 14px;',
    '  border: 1px solid rgba(0,0,0,.14);',
    '  border-radius: 14px;',
    '  background: rgba(255,255,255,.72);',
    '  backdrop-filter: blur(6px);',
    '}',
    '.cv2-mapfirst__inner{',
    '  display:flex;',
    '  align-items:center;',
    '  gap:12px;',
    '  padding: 10px 12px;',
    '}',
    '.cv2-mapfirst__mark{',
    '  width: 34px;',
    '  height: 34px;',
    '  border-radius: 999px;',
    '  display:flex;',
    '  align-items:center;',
    '  justify-content:center;',
    '  border: 1px solid rgba(0,0,0,.18);',
    '  background: rgba(247,198,0,.18);',
    '  font-weight: 800;',
    '}',
    '.cv2-mapfirst__text{ flex: 1; min-width: 0; }',
    '.cv2-mapfirst__title{ font-weight: 900; letter-spacing: .2px; }',
    '.cv2-mapfirst__sub{ font-size: 12.5px; opacity: .78; }',
    '.cv2-mapfirst__actions{ display:flex; gap:10px; }',
    '.cv2-mapfirst__btn{',
    '  display:inline-flex;',
    '  align-items:center;',
    '  gap:8px;',
    '  padding: 8px 10px;',
    '  border-radius: 12px;',
    '  border: 1px solid rgba(0,0,0,.20);',
    '  background: rgba(0,0,0,.88);',
    '  color: #fff;',
    '  text-decoration:none;',
    '  font-weight: 800;',
    '}',
    '.cv2-mapfirst__btn:hover{ filter: brightness(1.05); }',
    '@media (max-width: 900px){',
    '  .cv2-mapfirst__inner{ align-items:flex-start; }',
    '  .cv2-mapfirst__actions{ width:100%; }',
    '  .cv2-mapfirst__btn{ width:100%; justify-content:center; }',
    '}',
    '/* /CV2_MAPFIRST_CTA */'
  ) -join "`n"

  WriteUtf8NoBom $globalsAbs ($g.TrimEnd() + $css + "`n")
  Write-Host ("[PATCH] " + $globalsRel + " (append CV2_MAPFIRST_CTA)")
} else {
  Write-Host ("[SKIP] " + $globalsRel + " já tem CV2_MAPFIRST_CTA")
}

# ------------------------------------------------------------
# PATCH: pages V2 (inject import + component after V2QuickNav)
# ------------------------------------------------------------
$v2Root = Join-Path $repoRoot "src/app/c/[slug]/v2"
if (-not (Test-Path -LiteralPath $v2Root)) { throw ("[STOP] não achei: " + $v2Root) }

$pages = Get-ChildItem -LiteralPath $v2Root -Recurse -Filter "page.tsx" | ForEach-Object { $_.FullName }
if (-not $pages -or $pages.Count -eq 0) { throw "[STOP] não achei pages V2" }

$patched = New-Object System.Collections.Generic.List[string]

function InferCurrent([string]$abs) {
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

foreach ($abs in $pages) {
  $cur = InferCurrent $abs
  if ($cur -eq "mapa") { continue } # o próprio mapa não precisa CTA

  $raw = Get-Content -LiteralPath $abs -Raw
  if (-not $raw) { continue }

  if ($raw -match "Cv2MapFirstCta") { continue } # idempotente

  $bk = BackupFile $abs
  $rel = $abs.Substring($repoRoot.Length).TrimStart("\")
  Write-Host ("[BK]    tools/_patch_backup/" + (Split-Path -Leaf $bk))

  $lines = $raw -split "`r?`n"

  # inject import after last import line
  $importLine = 'import Cv2MapFirstCta from "@/components/v2/Cv2MapFirstCta";'
  $lastImport = -1
  for ($i=0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match "^\s*import\s+") { $lastImport = $i }
  }
  if ($lastImport -ge 0) {
    $before = @()
    if ($lastImport -ge 0) { $before = $lines[0..$lastImport] }
    $after = @()
    if ($lastImport + 1 -le $lines.Count-1) { $after = $lines[($lastImport+1)..($lines.Count-1)] }

    $already = $before -join "`n"
    if ($already -notmatch [Regex]::Escape($importLine)) {
      $lines = @($before + @($importLine) + $after)
    }
  }

  # inject after V2QuickNav
  $out = New-Object System.Collections.Generic.List[string]
  $injected = $false
  foreach ($ln in $lines) {
    $out.Add($ln) | Out-Null
    if (-not $injected -and $ln -match "<V2QuickNav\b") {
      $indent = ([Regex]::Match($ln, "^\s*")).Value
      $out.Add(($indent + '<Cv2MapFirstCta slug={slug} current="' + $cur + '" />')) | Out-Null
      $injected = $true
    }
  }

  if (-not $injected) {
    # fallback: after V2Nav
    $out2 = New-Object System.Collections.Generic.List[string]
    $done2 = $false
    foreach ($ln in $out) {
      $out2.Add($ln) | Out-Null
      if (-not $done2 -and $ln -match "<V2Nav\b") {
        $indent = ([Regex]::Match($ln, "^\s*")).Value
        $out2.Add(($indent + '<Cv2MapFirstCta slug={slug} current="' + $cur + '" />')) | Out-Null
        $done2 = $true
      }
    }
    $out = $out2
  }

  WriteUtf8NoBom $abs (($out -join "`n").TrimEnd() + "`n")
  $patched.Add($rel) | Out-Null
  Write-Host ("[PATCH] " + $rel + " (insert map-first CTA)")
}

Write-Host ("[DIAG] patched pages: " + $patched.Count)

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
$rep = Join-Path $repDir ($stamp + "-cv-b6x-v2-mapfirst-cta-everywhere.md")

$body = @(
("# CV B6X — V2 Map-first CTA em todas as páginas V2 — " + $stamp),
"",
("Repo: " + $repoRoot),
"",
"## PATCH",
("- component: " + $compRel),
("- css: " + $globalsRel),
"Patched pages:",
($patched | ForEach-Object { "  - " + $_ }),
"",
"## VERIFY",
("- lint exit: " + $r1.code),
("- build exit: " + $r2.code)
) -join "`n"

WriteUtf8NoBom $rep ($body + "`n")
Write-Host ("[REPORT] reports/" + (Split-Path -Leaf $rep))
Write-Host "[OK] B6X concluído (CTA map-first injetado + lint/build ok)."