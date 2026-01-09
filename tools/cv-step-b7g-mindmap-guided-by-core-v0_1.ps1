# cv-step-b7g-mindmap-guided-by-core-v0_1
$ErrorActionPreference = "Stop"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$repoRoot = (Resolve-Path ".").Path

function EnsureDir([string]$abs) { if (-not (Test-Path -LiteralPath $abs)) { [IO.Directory]::CreateDirectory($abs) | Out-Null } }
function ReadText([string]$abs) { if (-not (Test-Path -LiteralPath $abs)) { return $null }; return [IO.File]::ReadAllText($abs) }
function WriteText([string]$abs, [string]$text) { $enc = New-Object System.Text.UTF8Encoding($false); EnsureDir (Split-Path -Parent $abs); [IO.File]::WriteAllText($abs, $text, $enc) }
function BackupFile([string]$rel) {
  $abs = Join-Path $repoRoot $rel
  if (-not (Test-Path -LiteralPath $abs)) { return }
  $bkDir = Join-Path $repoRoot "tools\_patch_backup"
  EnsureDir $bkDir
  $dst = Join-Path $bkDir ($stamp + "-" + (Split-Path -Leaf $abs))
  Copy-Item -LiteralPath $abs -Destination $dst -Force
}
function TryRun([string]$label, [scriptblock]$sb) {
  try { $out = & $sb 2>&1 | Out-String; return @("## " + $label, "", $out.TrimEnd(), "") }
  catch { return @("## " + $label, "", ("[ERR] " + $_.Exception.Message), "") }
}
function AddLines([System.Collections.Generic.List[string]]$list, [object]$block) { if ($null -eq $block) { return }; foreach ($x in @($block)) { $list.Add([string]$x) | Out-Null } }

EnsureDir (Join-Path $repoRoot "reports")
EnsureDir (Join-Path $repoRoot "tools\_patch_backup")

$rep = Join-Path $repoRoot ("reports\" + $stamp + "-cv-step-b7g-mindmap-guided-by-core.md")
$r = New-Object System.Collections.Generic.List[string]
$r.Add("# Tijolo B7G — Mindmap guiado pelo núcleo (coreNodes) — " + $stamp) | Out-Null
$r.Add("") | Out-Null
$r.Add("Repo: " + $repoRoot) | Out-Null
$r.Add("") | Out-Null
AddLines $r (TryRun "Git status (pre)" { git status })

# -------------------------
# DIAG
# -------------------------
$mmRel = "src\components\v2\Cv2MindmapHubClient.tsx"
$mmAbs = Join-Path $repoRoot $mmRel
$hubRel = "src\app\c\[slug]\v2\page.tsx"
$hubAbs = Join-Path $repoRoot $hubRel
$cssRel = "src\app\globals.css"
$cssAbs = Join-Path $repoRoot $cssRel

$r.Add("## DIAG — Mindmap file (head)") | Out-Null
$r.Add("") | Out-Null
if (Test-Path -LiteralPath $mmAbs) {
  $raw = ReadText $mmAbs
  $head = ($raw -split "`n" | Select-Object -First 60) -join "`n"
  $r.Add("```tsx") | Out-Null
  $r.Add($head.TrimEnd()) | Out-Null
  $r.Add("```") | Out-Null
} else {
  $r.Add("[ERR] missing: " + $mmRel) | Out-Null
}
$r.Add("") | Out-Null

$r.Add("## DIAG — Hub usage (Cv2MindmapHubClient)") | Out-Null
$r.Add("") | Out-Null
if (Test-Path -LiteralPath $hubAbs) {
  $rawHub = ReadText $hubAbs
  $hits = @()
  $rawHub -split "`n" | ForEach-Object {
    if ($_ -match "Cv2MindmapHubClient") { $hits += $_ }
  }
  if ($hits.Count -eq 0) { $r.Add("[WARN] nenhum uso encontrado no hub") | Out-Null }
  else {
    $r.Add("```") | Out-Null
    foreach ($h in ($hits | Select-Object -First 8)) { $r.Add($h) | Out-Null }
    $r.Add("```") | Out-Null
  }
} else {
  $r.Add("[WARN] missing: " + $hubRel) | Out-Null
}
$r.Add("") | Out-Null

# -------------------------
# PATCH A — rewrite Cv2MindmapHubClient.tsx (core-guided)
# -------------------------
if (-not (Test-Path -LiteralPath $mmAbs)) { throw ("Missing: " + $mmRel) }
BackupFile $mmRel

$ts = @(
  '"use client";',
  '',
  'import Link from "next/link";',
  'import type { CoreNodesV2 } from "@/lib/v2/types";',
  'import { coreNodesToDoorOrder, doorById } from "@/lib/v2/doors";',
  '',
  'type MetaLike = { coreNodes?: CoreNodesV2 };',
  '',
  'type Props = {',
  '  slug: string;',
  '  title?: string;',
  '  coreNodes?: CoreNodesV2;',
  '  meta?: MetaLike;',
  '};',
  '',
  'type DoorId = "mapa" | "linha" | "linha-do-tempo" | "provas" | "trilhas" | "debate";',
  'type DoorLike = {',
  '  id: DoorId;',
  '  label?: string;',
  '  title?: string;',
  '  desc?: string;',
  '  subtitle?: string;',
  '  href: (slug: string) => string;',
  '};',
  '',
  'const ALL: DoorId[] = ["mapa", "linha", "linha-do-tempo", "provas", "trilhas", "debate"];',
  '',
  'function safeLabel(d: DoorLike): string {',
  '  if (d.label) return d.label;',
  '  if (d.title) return d.title;',
  '  if (d.id === "linha-do-tempo") return "Tempo";',
  '  return d.id;',
  '}',
  '',
  'function safeDesc(d: DoorLike): string {',
  '  if (d.desc) return d.desc;',
  '  if (d.subtitle) return d.subtitle;',
  '  if (d.id === "mapa") return "Eixo central do universo: comece por aqui.";',
  '  if (d.id === "provas") return "Documentos, dados e rastros do mundo real.";',
  '  if (d.id === "trilhas") return "Caminhos guiados: aprenda e avance.";',
  '  if (d.id === "debate") return "Conversas em camadas e hipóteses.";',
  '  if (d.id === "linha") return "Resumo encadeado: o fio narrativo.";',
  '  if (d.id === "linha-do-tempo") return "Sequência histórica: datas e viradas.";',
  '  return "";',
  '}',
  '',
  'function normalizeDoorOrder(order: string[]): DoorId[] {',
  '  const out: DoorId[] = [];',
  '  for (const raw of order) {',
  '    const id = raw as DoorId;',
  '    if (ALL.includes(id) && !out.includes(id)) out.push(id);',
  '  }',
  '  // garante eixo',
  '  if (!out.includes("mapa")) out.unshift("mapa");',
  '  // completa com o resto',
  '  for (const id of ALL) {',
  '    if (!out.includes(id)) out.push(id);',
  '  }',
  '  return out;',
  '}',
  '',
  'function nextDoorAfterMap(ids: DoorId[]): DoorId {',
  '  const i = ids.indexOf("mapa");',
  '  if (i >= 0 && i + 1 < ids.length) return ids[i + 1];',
  '  return ids[0] ? ids[0] : "mapa";',
  '}',
  '',
  'export default function Cv2MindmapHubClient(props: Props) {',
  '  const cn = props.coreNodes ? props.coreNodes : (props.meta ? props.meta.coreNodes : undefined);',
  '  const orderRaw = coreNodesToDoorOrder(cn);',
  '  const ids = normalizeDoorOrder(orderRaw);',
  '  const nodes = ids.map((id) => doorById(id) as unknown as DoorLike);',
  '  const nextId = nextDoorAfterMap(ids);',
  '  const mapHref = (doorById("mapa") as unknown as DoorLike).href(props.slug);',
  '  const nextHref = (doorById(nextId) as unknown as DoorLike).href(props.slug);',
  '',
  '  return (',
  '    <section className="cv2-mindmapHub" aria-label="Mapa mental do universo">',
  '      <header className="cv2-mindmapHub__head">',
  '        <div className="cv2-mindmapHub__kicker">Núcleo</div>',
  '        <h2 className="cv2-mindmapHub__title">{props.title ? props.title : "Mapa mental"}</h2>',
  '        <p className="cv2-mindmapHub__sub">As portas seguem a ordem do núcleo (fonte única).</p>',
  '      </header>',
  '',
  '      <ol className="cv2-mindmapHub__grid">',
  '        {nodes.map((d) => (',
  '          <li key={d.id} className={"cv2-mindmapHub__node" + (d.id === "mapa" ? " is-axis" : "")}>',
  '            <Link className="cv2-mindmapHub__a" href={d.href(props.slug)}>',
  '              <span className="cv2-mindmapHub__dot" aria-hidden="true" />',
  '              <span className="cv2-mindmapHub__label">{safeLabel(d)}</span>',
  '              <span className="cv2-mindmapHub__desc">{safeDesc(d)}</span>',
  '            </Link>',
  '          </li>',
  '        ))}',
  '      </ol>',
  '',
  '      <div className="cv2-mindmapHub__cta" role="navigation" aria-label="Próximas portas">',
  '        <Link className="cv2-mindmapHub__btn is-primary" href={mapHref} title="Comece pelo mapa">',
  '          Comece pelo Mapa',
  '        </Link>',
  '        <Link className="cv2-mindmapHub__btn" href={nextHref} title="Próxima porta">',
  '          Próxima porta: {safeLabel(nodes.find((x) => x.id === nextId) ? (nodes.find((x) => x.id === nextId) as DoorLike) : nodes[0])}',
  '        </Link>',
  '      </div>',
  '    </section>',
  '  );',
  '}',
  ''
) -join "`n"

WriteText $mmAbs ($ts + "`n")
$r.Add("## Patch A") | Out-Null
$r.Add("- reescrito: " + $mmRel + " (ordem guiada por coreNodesToDoorOrder)") | Out-Null
$r.Add("") | Out-Null

# -------------------------
# PATCH B — hub: tentar passar coreNodes/meta para o mindmap (best-effort)
# -------------------------
if (Test-Path -LiteralPath $hubAbs) {
  $rawHub = ReadText $hubAbs
  if ($null -ne $rawHub -and $rawHub -match "Cv2MindmapHubClient") {
    if ($rawHub -match "Cv2MindmapHubClient[^>]*\bcoreNodes\s*=" -or $rawHub -match "Cv2MindmapHubClient[^>]*\bmeta\s*=") {
      $r.Add("## Patch B") | Out-Null
      $r.Add("- skip: hub já passa coreNodes/meta") | Out-Null
      $r.Add("") | Out-Null
    } else {
      BackupFile $hubRel
      $lines = $rawHub -split "`n"
      $idx = -1
      for ($i=0; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -match "<Cv2MindmapHubClient") { $idx = $i; break }
      }

      $exprCore = $null
      $exprMeta = $null
      if ($rawHub -match "data\.meta\.coreNodes") { $exprCore = "data.meta.coreNodes" }
      elseif ($rawHub -match "\bmeta\.coreNodes\b") { $exprCore = "meta.coreNodes" }
      elseif ($rawHub -match "data\.meta\b") { $exprMeta = "data.meta" }
      elseif ($rawHub -match "\bmeta\b") { $exprMeta = "meta" }

      if ($idx -ge 0 -and $idx -lt $lines.Length) {
        $indent = ([regex]::Match($lines[$idx], '^\s*')).Value

        if ($exprCore) {
          if ($lines[$idx] -match "/>") {
            $lines[$idx] = $lines[$idx] -replace "\s*/>", (" coreNodes={" + $exprCore + "} />")
          } else {
            # tag multiline: insere linha de prop
            $lines = $lines[0..$idx] + @($indent + "  coreNodes={" + $exprCore + "}") + $lines[($idx+1)..($lines.Length-1)]
          }
          $r.Add("## Patch B") | Out-Null
          $r.Add("- hub: passou coreNodes={" + $exprCore + "} para Cv2MindmapHubClient") | Out-Null
          $r.Add("") | Out-Null
        } elseif ($exprMeta) {
          if ($lines[$idx] -match "/>") {
            $lines[$idx] = $lines[$idx] -replace "\s*/>", (" meta={" + $exprMeta + "} />")
          } else {
            $lines = $lines[0..$idx] + @($indent + "  meta={" + $exprMeta + "}") + $lines[($idx+1)..($lines.Length-1)]
          }
          $r.Add("## Patch B") | Out-Null
          $r.Add("- hub: passou meta={" + $exprMeta + "} para Cv2MindmapHubClient") | Out-Null
          $r.Add("") | Out-Null
        } else {
          $r.Add("## Patch B") | Out-Null
          $r.Add("- skip: não encontrei data.meta/meta no hub (mindmap vai usar fallback)") | Out-Null
          $r.Add("") | Out-Null
        }

        WriteText $hubAbs (($lines -join "`n") + "`n")
      }
    }
  }
}

# -------------------------
# PATCH C — CSS minimal (se não existir)
# -------------------------
if (Test-Path -LiteralPath $cssAbs) {
  $rawCss = ReadText $cssAbs
  if ($null -ne $rawCss -and $rawCss -notmatch "cv2-mindmapHub") {
    BackupFile $cssRel
    $cssBlock = @(
      '',
      '/* =============================== */',
      '/* CV2 — Mindmap Hub (core-guided) */',
      '/* =============================== */',
      '.cv2-mindmapHub{border:1px solid rgba(255,255,255,.10);border-radius:18px;padding:16px;background:rgba(0,0,0,.25);backdrop-filter:saturate(120%) blur(10px);}',
      '.cv2-mindmapHub__head{display:flex;flex-direction:column;gap:4px;margin-bottom:12px;}',
      '.cv2-mindmapHub__kicker{font-size:12px;letter-spacing:.08em;text-transform:uppercase;opacity:.7;}',
      '.cv2-mindmapHub__title{font-size:18px;margin:0;line-height:1.2;}',
      '.cv2-mindmapHub__sub{margin:0;font-size:13px;opacity:.75;}',
      '.cv2-mindmapHub__grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px;list-style:none;padding:0;margin:0;}',
      '@media (min-width: 860px){.cv2-mindmapHub__grid{grid-template-columns:repeat(3,minmax(0,1fr));}}',
      '.cv2-mindmapHub__node{position:relative;}',
      '.cv2-mindmapHub__a{display:flex;flex-direction:column;gap:6px;text-decoration:none;border:1px solid rgba(255,255,255,.12);border-radius:16px;padding:12px;transition:transform .12s ease, border-color .12s ease, background .12s ease;background:rgba(255,255,255,.02);}',
      '.cv2-mindmapHub__a:hover{transform:translateY(-1px);border-color:rgba(255,255,255,.22);background:rgba(255,255,255,.04);}',
      '.cv2-mindmapHub__dot{width:10px;height:10px;border-radius:99px;background:rgba(255,255,255,.55);}',
      '.cv2-mindmapHub__node.is-axis .cv2-mindmapHub__dot{background:rgba(255,220,120,.85);}',
      '.cv2-mindmapHub__label{font-weight:700;letter-spacing:.01em;}',
      '.cv2-mindmapHub__desc{font-size:12px;opacity:.78;line-height:1.25;}',
      '.cv2-mindmapHub__cta{display:flex;gap:10px;flex-wrap:wrap;margin-top:12px;}',
      '.cv2-mindmapHub__btn{display:inline-flex;align-items:center;gap:8px;padding:10px 12px;border-radius:999px;border:1px solid rgba(255,255,255,.14);text-decoration:none;background:rgba(255,255,255,.03);}',
      '.cv2-mindmapHub__btn:hover{border-color:rgba(255,255,255,.24);background:rgba(255,255,255,.05);}',
      '.cv2-mindmapHub__btn.is-primary{border-color:rgba(255,220,120,.35);background:rgba(255,220,120,.08);}',
      ''
    ) -join "`n"
    WriteText $cssAbs ($rawCss.TrimEnd() + $cssBlock + "`n")
    $r.Add("## Patch C") | Out-Null
    $r.Add("- globals.css: adicionado bloco cv2-mindmapHub (mínimo, sem quebrar)") | Out-Null
    $r.Add("") | Out-Null
  } else {
    $r.Add("## Patch C") | Out-Null
    $r.Add("- skip: globals.css já tem estilos cv2-mindmapHub (ou arquivo ausente)") | Out-Null
    $r.Add("") | Out-Null
  }
}

# -------------------------
# VERIFY
# -------------------------
AddLines $r (TryRun "npm run lint" {
  $npm = (Get-Command npm.cmd -ErrorAction Stop).Path
  & $npm run lint
})
AddLines $r (TryRun "npm run build" {
  $npm = (Get-Command npm.cmd -ErrorAction Stop).Path
  & $npm run build
})
AddLines $r (TryRun "Git status (post)" { git status })

WriteText $rep (($r -join "`n") + "`n")
Write-Host ("[REPORT] " + $rep)
Write-Host "[OK] B7G finalizado."