$ErrorActionPreference = "Stop"

function _NowTag { Get-Date -Format "yyyyMMdd-HHmmss" }

# --- Bootstrap (preferencial) ---
$boot = Join-Path $PSScriptRoot "_bootstrap.ps1"
if (Test-Path $boot) { . $boot }

# --- Fallbacks se bootstrap nao existir ---
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
function _Run([string[]]$cmd, [string]$cwd) {
  Write-Host ("[RUN] " + ($cmd -join " "))
  $p = Start-Process -FilePath $cmd[0] -ArgumentList ($cmd | Select-Object -Skip 1) -WorkingDirectory $cwd -Wait -PassThru -NoNewWindow
  if ($p.ExitCode -ne 0) { throw ("[STOP] falhou (exit " + $p.ExitCode + "): " + ($cmd -join " ")) }
}

function _FirstGlobalsCss([string]$root) {
  $p1 = Join-Path $root "src\app\globals.css"
  if (Test-Path $p1) { return $p1 }
  $hits = Get-ChildItem -Path (Join-Path $root "src") -Recurse -File -Filter "globals.css" -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($hits) { return $hits.FullName }
  return $null
}

function _RegexInsertAfterFirst([string]$text, [string]$pattern, [string]$insert) {
  $rx = [regex]::new($pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
  $m = $rx.Match($text)
  if (-not $m.Success) { return $null }
  $i = $m.Index + $m.Length
  return $text.Substring(0, $i) + $insert + $text.Substring($i)
}

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ts = _NowTag
Write-Host ("== CV — Step B5d: V2 Hub mindmap (v0_1) == " + $ts)
Write-Host ("[DIAG] Root: " + $root)

$hubPage = Join-Path $root "src\app\c\[slug]\v2\page.tsx"
$compOut = Join-Path $root "src\components\v2\Cv2MindmapHubClient.tsx"
$globals = _FirstGlobalsCss $root

Write-Host "[DIAG] Targets:"
Write-Host (" - hub page: " + $hubPage + " (" + (Test-Path $hubPage) + ")")
Write-Host (" - component: " + $compOut)
Write-Host (" - globals.css: " + ($globals ?? "<NOT FOUND>"))

if (-not (Test-Path $hubPage)) { throw "[STOP] Nao achei src\app\c\[slug]\v2\page.tsx" }
if (-not $globals) { throw "[STOP] Nao achei globals.css em src/" }

# -------------------------
# PATCH 1: Create component
# -------------------------
if (-not (Test-Path $compOut)) {
  $lines = @(
    '"use client";',
    '',
    'import * as React from "react";',
    '',
    'type NodeDef = {',
    '  id: "mapa" | "linha" | "provas" | "trilhas" | "debate";',
    '  label: string;',
    '  desc: string;',
    '  href: string;',
    '  x: number; // 0..100',
    '  y: number; // 0..100',
    '};',
    '',
    'export default function Cv2MindmapHubClient(props: { slug: string; title: string }) {',
    '  const { slug, title } = props;',
    '  const nodes: NodeDef[] = React.useMemo(() => ([',
    '    { id: "mapa",   label: "Mapa",   desc: "Explorar por lugares e conexões", href: "/c/" + slug + "/v2/mapa",          x: 50, y: 44 },',
    '    { id: "linha",  label: "Linha",  desc: "Narrativa em fluxo (o que levou ao quê)", href: "/c/" + slug + "/v2/linha",  x: 22, y: 52 },',
    '    { id: "provas", label: "Provas", desc: "Fontes, documentos e checagens", href: "/c/" + slug + "/v2/provas",         x: 78, y: 52 },',
    '    { id: "trilhas",label: "Trilhas",desc: "Caminhos de leitura (do básico ao avançado)", href: "/c/" + slug + "/v2/trilhas", x: 30, y: 74 },',
    '    { id: "debate", label: "Debate", desc: "Perguntas, hipóteses e conversa em camadas", href: "/c/" + slug + "/v2/debate", x: 70, y: 74 }',
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
    '  const cx = (a: string, b?: boolean) => (b ? (a + " cv2-card--active") : a);',
    '',
    '  const cx0 = 50; // center anchor',
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
  $text = ($lines -join "`r`n") + "`r`n"
  WriteUtf8NoBom $compOut $text
  Write-Host ("[PATCH] wrote -> " + $compOut)
} else {
  Write-Host ("[SKIP] component exists -> " + $compOut)
}

# -------------------------
# PATCH 2: Append CSS
# -------------------------
$cssMarker = "/* CV2 mindmap hub v0_1 */"
$cssRaw = Get-Content -Raw $globals
if ($cssRaw -notlike "*$cssMarker*") {
  $bk = BackupFile $globals
  if ($bk) { Write-Host ("[BK] " + $bk) }
  $css = @(
    '',
    $cssMarker,
    '.cv2-mindmap{ margin-top:12px; }',
    '.cv2-mindmapFrame{ position:relative; min-height:420px; border:1px solid rgba(255,255,255,.10); border-radius:14px; background:rgba(0,0,0,.22); overflow:hidden; outline:none; }',
    '.cv2-mindmapFrame:focus{ box-shadow:0 0 0 2px var(--accent); }',
    '.cv2-mindmapSvg{ position:absolute; inset:0; width:100%; height:100%; pointer-events:none; }',
    '.cv2-mindmapLine{ stroke: rgba(247,198,0,.38); stroke-width:0.5; }',
    '.cv2-mindmapDot{ fill: var(--accent); opacity:.9; }',
    '.cv2-mindmapCenter{ position:absolute; left:50%; top:22%; transform:translate(-50%,-50%); width:min(520px, 92%); }',
    '.cv2-mindmapCenterCard{ text-align:center; }',
    '.cv2-mindmapHint{ margin-top:10px; font-size:12px; opacity:.85; }',
    '.cv2-mindmapNode{ position:absolute; transform:translate(-50%,-50%); width:min(340px, 46vw); }',
    '.cv2-card--active{ box-shadow:0 0 0 2px var(--accent); }',
    ''
  ) -join "`r`n"
  WriteUtf8NoBom $globals ($cssRaw + $css)
  Write-Host ("[PATCH] globals.css appended -> " + $globals)
} else {
  Write-Host ("[SKIP] globals.css already has mindmap block.")
}

# -------------------------
# PATCH 3: Inject into Hub page
# -------------------------
$raw = Get-Content -Raw $hubPage
$changed = $false

if ($raw -notmatch "Cv2MindmapHubClient") {
  $bk2 = BackupFile $hubPage
  if ($bk2) { Write-Host ("[BK] " + $bk2) }

  # 3a) add import
  if ($raw -notmatch "from\s+`"@/components/v2/Cv2MindmapHubClient`"") {
    $insertImp = 'import Cv2MindmapHubClient from "@/components/v2/Cv2MindmapHubClient";' + "`r`n"
    $tmp = _RegexInsertAfterFirst $raw '^(import\s+.*?;\s*\r?\n)+' $insertImp
    if (-not $tmp) {
      # fallback: insert after first import line
      $tmp = _RegexInsertAfterFirst $raw '^import\s+.*?;\s*\r?\n' $insertImp
    }
    if ($tmp) { $raw = $tmp; $changed = $true; Write-Host "[PATCH] added import Cv2MindmapHubClient" }
    else { throw "[STOP] Nao consegui injetar import no hub page.tsx (formato inesperado)." }
  }

  # 3b) add JSX after V2Nav
  if ($raw -notmatch "CV2_MINDMAP_HUB") {
    $inject = "`r`n      {/* CV2_MINDMAP_HUB */}`r`n      <Cv2MindmapHubClient slug={slug} title={title} />"
    $rxSelf = [regex]::new('<V2Nav[^>]*\/>', [System.Text.RegularExpressions.RegexOptions]::Multiline)
    $mSelf = $rxSelf.Match($raw)
    if ($mSelf.Success) {
      $raw = $raw.Substring(0, $mSelf.Index + $mSelf.Length) + $inject + $raw.Substring($mSelf.Index + $mSelf.Length)
      $changed = $true
      Write-Host "[PATCH] injected mindmap after <V2Nav ... />"
    } else {
      # fallback: after line containing <V2Nav
      $idx = $raw.IndexOf("<V2Nav")
      if ($idx -ge 0) {
        $eol = $raw.IndexOf("`n", $idx)
        if ($eol -gt 0) {
          $raw = $raw.Substring(0, $eol+1) + "      {/* CV2_MINDMAP_HUB */}`r`n      <Cv2MindmapHubClient slug={slug} title={title} />`r`n" + $raw.Substring($eol+1)
          $changed = $true
          Write-Host "[PATCH] injected mindmap after V2Nav line (fallback)"
        }
      }
    }
  }
}

if ($changed) {
  WriteUtf8NoBom $hubPage $raw
  Write-Host ("[OK] patched: " + $hubPage)
} else {
  Write-Host "[SKIP] Hub page already patched."
}

# -------------------------
# VERIFY
# -------------------------
$verify = Join-Path $root "tools\cv-verify.ps1"
if (Test-Path $verify) {
  _Run @("pwsh","-NoProfile","-ExecutionPolicy","Bypass","-File",$verify) $root
} else {
  Write-Host "[WARN] tools\cv-verify.ps1 nao encontrado; rodando npm run lint/build"
  _Run @("npm","run","lint") $root
  _Run @("npm","run","build") $root
}

# -------------------------
# REPORT
# -------------------------
$repDir = Join-Path $root "reports"
EnsureDir $repDir
$rep = Join-Path $repDir ("cv-step-b5d-v2-hub-mindmap-" + $ts + ".md")
$repText = @(
  "# CV — Step B5d: V2 Hub mindmap (v0_1)",
  "",
  "- when: " + $ts,
  "- repo: " + $root,
  "",
  "## ACTIONS",
  "- Created: src/components/v2/Cv2MindmapHubClient.tsx",
  "- Patched: src/app/c/[slug]/v2/page.tsx (inject mindmap below V2Nav)",
  "- Patched: " + (Split-Path -Leaf $globals) + " (append mindmap CSS block)",
  "",
  "## NOTES",
  "- Hub V2 ganha um 'mapa mental' com 5 portas (Mapa/Linha/Provas/Trilhas/Debate).",
  "- Navegacao: setas + Enter (roving focus).",
  "",
  "## VERIFY",
  "- OK"
) -join "`r`n"
WriteUtf8NoBom $rep $repText
Write-Host ("[ রিপোর্ট ] " + $rep)

Write-Host ""
Write-Host "[DONE] B5d aplicado. Abra /c/SEU-SLUG/v2 e veja o mindmap."