$ErrorActionPreference = "Stop"

function _NowTag { Get-Date -Format "yyyyMMdd-HHmmss" }

# --- Bootstrap (preferencial) ---
$boot = Join-Path $PSScriptRoot "_bootstrap.ps1"
if (Test-Path $boot) { . $boot }

# --- Fallbacks (se bootstrap nao existir) ---
if (-not (Get-Command EnsureDir -ErrorAction SilentlyContinue)) {
  function EnsureDir([string]$p) { if (-not (Test-Path $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
}
if (-not (Get-Command WriteUtf8NoBom -ErrorAction SilentlyContinue)) {
  function WriteUtf8NoBom([string]$p, [string]$t) {
    EnsureDir (Split-Path -Parent $p)
    [IO.File]::WriteAllText($p, $t, [Text.UTF8Encoding]::new($false))
  }
}
if (-not (Get-Command BackupFile -ErrorAction SilentlyContinue)) {
  function BackupFile([string]$p) {
    if (-not (Test-Path $p)) { return $null }
    $bkDir = Join-Path $PSScriptRoot "_patch_backup"
    EnsureDir $bkDir
    $ts = Get-Date -Format "yyyyMMdd-HHmmss"
    $leaf = Split-Path -Leaf $p
    $dst = Join-Path $bkDir ($ts + "-" + $leaf + ".bak")
    Copy-Item $p $dst -Force
    return $dst
  }
}

function _FirstGlobalsCss([string]$root) {
  $p1 = Join-Path $root "src\app\globals.css"
  if (Test-Path $p1) { return $p1 }
  $hits = Get-ChildItem -Path (Join-Path $root "src") -Recurse -File -Filter "globals.css" -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($hits) { return $hits.FullName }
  return $null
}

function _FindHubPage([string]$root) {
  $base = Join-Path $root "src\app\c\[slug]\v2"
  if (-not (Test-Path $base)) { return $null }

  $prefer = @(
    (Join-Path $base "page.tsx"),
    (Join-Path $base "hub\page.tsx"),
    (Join-Path $base "home\page.tsx")
  )
  foreach ($p in $prefer) { if (Test-Path $p) { return $p } }

  $pages = Get-ChildItem -Path $base -Recurse -File -Filter "page.tsx" -ErrorAction SilentlyContinue
  if (-not $pages) { return $null }

  $scored = @()
  foreach ($f in $pages) {
    $rel = $f.FullName.Substring($root.Length + 1).Replace("\","/")
    $score = 0

    if ($rel -match '^src/app/c/\[slug\]/v2/page\.tsx$') { $score += 50 }
    if ($rel -match '/v2/hub/page\.tsx$') { $score += 40 }
    if ($rel -match '/v2/home/page\.tsx$') { $score += 35 }

    if ($rel -notmatch '/v2/(mapa|linha|linha-do-tempo|provas|trilhas|debate)/') { $score += 6 }

    $txt = Get-Content -Raw $f.FullName
    if ($txt -match 'Núcleo do universo') { $score += 12 }
    if ($txt -match 'Explore o universo') { $score += 10 }
    if ($txt -match '<V2Nav') { $score += 6 }
    if ($txt -match '<V2QuickNav') { $score += 4 }
    if ($txt -match '<V2Portals') { $score += 4 }

    $scored += [pscustomobject]@{ Path=$f.FullName; Rel=$rel; Score=$score }
  }

  $top = $scored | Sort-Object Score -Descending | Select-Object -First 5
  Write-Host "[DIAG] hub candidates (top 5):"
  foreach ($t in $top) { Write-Host ("  - " + $t.Score + "  " + $t.Rel) }

  $best = $scored | Sort-Object Score -Descending | Select-Object -First 1
  if ($best -and $best.Score -ge 10) { return $best.Path }
  return $null
}

function _InsertImportAfterImports([string]$raw, [string]$importLine) {
  if ($raw -like ("*" + $importLine + "*")) { return $raw }
  $lines = $raw -split "(`r`n|`n)"
  $lastImp = -1
  for ($i=0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*import\s+') { $lastImp = $i }
    elseif ($lastImp -ge 0 -and $lines[$i].Trim() -eq "") { break }
  }
  if ($lastImp -lt 0) {
    return ($importLine + "`r`n" + $raw)
  }
  $out = New-Object System.Collections.Generic.List[string]
  for ($i2=0; $i2 -lt $lines.Count; $i2++) {
    $out.Add($lines[$i2])
    if ($i2 -eq $lastImp) { $out.Add($importLine) }
  }
  return ($out -join "`r`n")
}

function _InjectJsxNear([string]$raw, [string]$jsx) {
  if ($raw -like "*CV2_MINDMAP_HUB*") { return $raw }

  $lines = $raw -split "(`r`n|`n)"
  $out = New-Object System.Collections.Generic.List[string]
  $inserted = $false

  # 1) antes de "Núcleo do universo"
  for ($i=0; $i -lt $lines.Count; $i++) {
    if (-not $inserted -and $lines[$i] -match 'Núcleo do universo') {
      $out.Add("      {/* CV2_MINDMAP_HUB */}")
      $out.Add($jsx)
      $inserted = $true
    }
    $out.Add($lines[$i])
  }

  if ($inserted) { return ($out -join "`r`n") }

  # fallback 2) depois de <V2QuickNav
  $out.Clear()
  for ($j=0; $j -lt $lines.Count; $j++) {
    $out.Add($lines[$j])
    if (-not $inserted -and $lines[$j] -match '<V2QuickNav') {
      $out.Add("      {/* CV2_MINDMAP_HUB */}")
      $out.Add($jsx)
      $inserted = $true
    }
  }
  if ($inserted) { return ($out -join "`r`n") }

  # fallback 3) depois de <V2Nav
  $out.Clear()
  for ($k=0; $k -lt $lines.Count; $k++) {
    $out.Add($lines[$k])
    if (-not $inserted -and $lines[$k] -match '<V2Nav') {
      $out.Add("      {/* CV2_MINDMAP_HUB */}")
      $out.Add($jsx)
      $inserted = $true
    }
  }
  if ($inserted) { return ($out -join "`r`n") }

  # fallback 4) depois da primeira <main
  $out.Clear()
  for ($m=0; $m -lt $lines.Count; $m++) {
    $out.Add($lines[$m])
    if (-not $inserted -and $lines[$m] -match '<main') {
      $out.Add("      {/* CV2_MINDMAP_HUB */}")
      $out.Add($jsx)
      $inserted = $true
    }
  }
  return ($out -join "`r`n")
}

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ts = _NowTag
Write-Host ("== cv-step-b5d-v2-hub-mindmap-v0_2 == " + $ts)
Write-Host ("[DIAG] Repo: " + $root)

$globals = _FirstGlobalsCss $root
if (-not $globals) { throw "[STOP] nao achei globals.css em src/" }

$hubPage = _FindHubPage $root
if (-not $hubPage) { throw "[STOP] nao consegui localizar o Hub V2 (page.tsx) em src/app/c/[slug]/v2/**" }

Write-Host ("[DIAG] Hub escolhido: " + $hubPage)

$compOut = Join-Path $root "src\components\v2\Cv2MindmapHubClient.tsx"

# -------------------------
# PATCH 1: component (additive)
# -------------------------
if (-not (Test-Path $compOut)) {
  $lines = @(
    '"use client";',
    '',
    'import * as React from "react";',
    '',
    'type NodeId = "mapa" | "linha" | "provas" | "trilhas" | "debate";',
    'type NodeDef = {',
    '  id: NodeId;',
    '  label: string;',
    '  desc: string;',
    '  href: string;',
    '  x: number; // 0..100',
    '  y: number; // 0..100',
    '};',
    '',
    'export default function Cv2MindmapHubClient(props: { slug: string; title?: string }) {',
    '  const slug = props.slug;',
    '  const title = props.title ?? props.slug;',
    '',
    '  const nodes: NodeDef[] = React.useMemo(() => ([',
    '    { id: "mapa",   label: "Mapa",   desc: "Explorar por lugares e conexões", href: "/c/" + slug + "/v2/mapa",            x: 50, y: 44 },',
    '    { id: "linha",  label: "Linha",  desc: "Narrativa em fluxo (o que levou ao quê)", href: "/c/" + slug + "/v2/linha",    x: 22, y: 52 },',
    '    { id: "provas", label: "Provas", desc: "Fontes, documentos e checagens", href: "/c/" + slug + "/v2/provas",           x: 78, y: 52 },',
    '    { id: "trilhas",label: "Trilhas",desc: "Caminhos de leitura (do básico ao avançado)", href: "/c/" + slug + "/v2/trilhas", x: 30, y: 74 },',
    '    { id: "debate", label: "Debate", desc: "Perguntas e conversa em camadas", href: "/c/" + slug + "/v2/debate",           x: 70, y: 74 }',
    '  ] as NodeDef[]), [slug]);',
    '',
    '  const [active, setActive] = React.useState<number>(0);',
    '  const refs = React.useRef<Array<HTMLAnchorElement | null>>([]);',
    '',
    '  function focus(i: number) {',
    '    const idx = (i + nodes.length) % nodes.length;',
    '    setActive(idx);',
    '    requestAnimationFrame(() => {',
    '      const el = refs.current[idx];',
    '      if (el) el.focus();',
    '    });',
    '  }',
    '',
    '  const onKeyDown = React.useCallback((e: React.KeyboardEvent) => {',
    '    const k = e.key;',
    '    if (k === "ArrowRight") { e.preventDefault(); focus(active + 1); }',
    '    else if (k === "ArrowLeft") { e.preventDefault(); focus(active - 1); }',
    '    else if (k === "ArrowUp") { e.preventDefault(); focus(0); }',
    '    else if (k === "ArrowDown") { e.preventDefault(); focus(3); }',
    '    else if (k === "Enter" || k === " ") {',
    '      e.preventDefault();',
    '      const el = refs.current[active];',
    '      if (el) el.click();',
    '    }',
    '  }, [active, nodes.length]);',
    '',
    '  const cx = (base: string, isActive: boolean) => (isActive ? (base + " cv2-card--active") : base);',
    '',
    '  const cx0 = 50;',
    '  const cy0 = 22;',
    '',
    '  return (',
    '    <section className="cv2-mindmap" aria-label="Mapa mental do caderno">',
    '      <div',
    '        className="cv2-mindmapFrame"',
    '        tabIndex={0}',
    '        role="application"',
    '        aria-roledescription="Mapa mental navegável"',
    '        onKeyDown={onKeyDown}',
    '      >',
    '        <svg className="cv2-mindmapSvg" viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true">',
    '          {nodes.map((n) => (',
    '            <line key={n.id} x1={cx0} y1={cy0} x2={n.x} y2={n.y} className="cv2-mindmapLine" />',
    '          ))}',
    '          <circle cx={cx0} cy={cy0} r="1.6" className="cv2-mindmapDot" />',
    '        </svg>',
    '',
    '        <div className="cv2-mindmapCenter">',
    '          <div className="cv2-card cv2-mindmapCenterCard">',
    '            <div className="cv2-cardTitle">{title}</div>',
    '            <div className="cv2-cardDesc">Escolha uma porta para entrar no universo</div>',
    '            <div className="cv2-mindmapHint">Dica: setas navegam • Enter abre</div>',
    '          </div>',
    '        </div>',
    '',
    '        {nodes.map((n, i) => (',
    '          <div key={n.id} className="cv2-mindmapNode" style={{ left: n.x + "%", top: n.y + "%" }}>',
    '            <a',
    '              href={n.href}',
    '              className={cx("cv2-card", i === active)}',
    '              ref={(el) => { refs.current[i] = el; }}',
    '              onFocus={() => setActive(i)}',
    '              aria-label={n.label + ": " + n.desc}',
    '            >',
    '              <div className="cv2-cardTitle">{n.label}</div>',
    '              <div className="cv2-cardDesc">{n.desc}</div>',
    '            </a>',
    '          </div>',
    '        ))}',
    '      </div>',
    '    </section>',
    '  );',
    '}'
  )
  WriteUtf8NoBom $compOut (($lines -join "`r`n") + "`r`n")
  Write-Host ("[PATCH] wrote -> " + $compOut)
} else {
  Write-Host ("[SKIP] component exists -> " + $compOut)
}

# -------------------------
# PATCH 2: globals.css (additive)
# -------------------------
$cssMarker = "/* CV2 mindmap hub v0_1 */"
$cssRaw = Get-Content -Raw $globals
if ($cssRaw -notlike ("*" + $cssMarker + "*")) {
  $bk = BackupFile $globals
  if ($bk) { Write-Host ("[BK] " + $bk) }

  $css = @(
    '',
    $cssMarker,
    '.cv2-mindmap{ margin-top:12px; }',
    '.cv2-mindmapFrame{ position:relative; min-height:420px; border:1px solid rgba(255,255,255,.10); border-radius:14px; background:rgba(0,0,0,.22); overflow:hidden; outline:none; }',
    '.cv2-mindmapFrame:focus{ box-shadow:0 0 0 2px var(--accent, #F7C600); }',
    '.cv2-mindmapSvg{ position:absolute; inset:0; width:100%; height:100%; pointer-events:none; }',
    '.cv2-mindmapLine{ stroke: rgba(247,198,0,.38); stroke-width:0.5; }',
    '.cv2-mindmapDot{ fill: var(--accent, #F7C600); opacity:.9; }',
    '.cv2-mindmapCenter{ position:absolute; left:50%; top:22%; transform:translate(-50%,-50%); width:min(520px, 92%); }',
    '.cv2-mindmapCenterCard{ text-align:center; }',
    '.cv2-mindmapHint{ margin-top:10px; font-size:12px; opacity:.85; }',
    '.cv2-mindmapNode{ position:absolute; transform:translate(-50%,-50%); width:min(340px, 46vw); }',
    '.cv2-card--active{ box-shadow:0 0 0 2px var(--accent, #F7C600); }',
    ''
  ) -join "`r`n"

  WriteUtf8NoBom $globals ($cssRaw + $css)
  Write-Host ("[PATCH] globals.css appended -> " + $globals)
} else {
  Write-Host "[SKIP] globals.css already has mindmap block."
}

# -------------------------
# PATCH 3: inject into HUB page
# -------------------------
$raw = Get-Content -Raw $hubPage
$changed = $false

$importLine = 'import Cv2MindmapHubClient from "@/components/v2/Cv2MindmapHubClient";'
if ($raw -notlike ("*" + $importLine + "*")) {
  $bk2 = BackupFile $hubPage
  if ($bk2) { Write-Host ("[BK] " + $bk2) }
  $raw = _InsertImportAfterImports $raw $importLine
  $changed = $true
  Write-Host "[PATCH] added import Cv2MindmapHubClient"
}

if ($raw -notlike "*CV2_MINDMAP_HUB*") {
  $jsx = '      <Cv2MindmapHubClient slug={slug} />'
  $raw2 = _InjectJsxNear $raw $jsx
  if ($raw2 -ne $raw) {
    $raw = $raw2
    $changed = $true
    Write-Host "[PATCH] injected <Cv2MindmapHubClient slug={slug} />"
  }
}

if ($changed) {
  WriteUtf8NoBom $hubPage $raw
  Write-Host ("[OK] patched: " + $hubPage)
} else {
  Write-Host "[SKIP] hub already patched."
}

# -------------------------
# VERIFY
# -------------------------
$verify = Join-Path $root "tools\cv-verify.ps1"
if (Test-Path $verify) {
  Write-Host ("[RUN] " + $verify)
  & pwsh -NoProfile -ExecutionPolicy Bypass -File $verify
  if ($LASTEXITCODE -ne 0) { throw ("[STOP] cv-verify falhou (exit=" + $LASTEXITCODE + ")") }
} else {
  $npm = (Get-Command npm.cmd -ErrorAction Stop).Path
  Write-Host "[RUN] npm run lint"
  & $npm run lint
  if ($LASTEXITCODE -ne 0) { throw ("[STOP] lint falhou (exit=" + $LASTEXITCODE + ")") }
  Write-Host "[RUN] npm run build"
  & $npm run build
  if ($LASTEXITCODE -ne 0) { throw ("[STOP] build falhou (exit=" + $LASTEXITCODE + ")") }
}

# -------------------------
# REPORT
# -------------------------
$repDir = Join-Path $root "reports"
EnsureDir $repDir
$rep = Join-Path $repDir ("cv-step-b5d-v2-hub-mindmap-" + $ts + ".md")
$repText = @(
  "# CV — Step B5d: V2 Hub mindmap (v0_2)",
  "",
  "- when: " + $ts,
  "- repo: " + $root,
  "- hub: " + $hubPage,
  "",
  "## PATCH",
  "- Created/ensured: src/components/v2/Cv2MindmapHubClient.tsx",
  "- Patched: globals.css (append mindmap css)",
  "- Patched: Hub page (import + inject component)",
  "",
  "## VERIFY",
  "- OK"
) -join "`r`n"
WriteUtf8NoBom $rep $repText
Write-Host ("[REPORT] " + $rep)

Write-Host "[DONE] B5d v0_2 aplicado. Abra o Hub V2 e veja o mindmap."