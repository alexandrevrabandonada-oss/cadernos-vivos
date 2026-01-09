# cv-step-b7g-mindmap-guided-by-core-v0_2
$ErrorActionPreference = "Stop"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$repoRoot = (Resolve-Path ".").Path
$nl = [Environment]::NewLine

function EnsureDir([string]$abs) { if (-not (Test-Path -LiteralPath $abs)) { [IO.Directory]::CreateDirectory($abs) | Out-Null } }
function ReadText([string]$abs) { if (-not (Test-Path -LiteralPath $abs)) { return $null }; return [IO.File]::ReadAllText($abs) }
function WriteText([string]$abs, [string]$text) { $enc = New-Object System.Text.UTF8Encoding($false); EnsureDir (Split-Path -Parent $abs); [IO.File]::WriteAllText($abs, $text, $enc) }
function BackupFile([string]$rel) {
  $abs = Join-Path $repoRoot $rel
  if (-not (Test-Path -LiteralPath $abs)) { return }
  $bkDir = Join-Path $repoRoot "tools\_patch_backup"
  EnsureDir $bkDir
  $dst = Join-Path $bkDir ($stamp + "-" + (Split-Path -Leaf $abs) + ".bak")
  Copy-Item -LiteralPath $abs -Destination $dst -Force
}
function TryRun([string]$label, [scriptblock]$sb) {
  try {
    $out = & $sb 2>&1 | Out-String
    return @("## " + $label, "", $out.TrimEnd(), "")
  } catch {
    return @("## " + $label, "", ("ERR: " + $_.Exception.Message), "")
  }
}
function AddLines([System.Collections.Generic.List[string]]$list, [object]$block) {
  if ($null -eq $block) { return }
  foreach ($x in @($block)) { $list.Add([string]$x) | Out-Null }
}

EnsureDir (Join-Path $repoRoot "reports")
EnsureDir (Join-Path $repoRoot "tools\_patch_backup")

$rep = Join-Path $repoRoot ("reports\" + $stamp + "-cv-step-b7g-mindmap-guided-by-core.md")
$r = New-Object System.Collections.Generic.List[string]
$r.Add("# Tijolo B7G v0_2 — Mindmap guiado pelo núcleo (coreNodes) — " + $stamp) | Out-Null
$r.Add("") | Out-Null
$r.Add("Repo: " + $repoRoot) | Out-Null
$r.Add("") | Out-Null

AddLines $r (TryRun "Git status (pre)" { git status })

# Paths
$mmRel  = "src\components\v2\Cv2MindmapHubClient.tsx"
$hubRel = "src\app\c\[slug]\v2\page.tsx"
$mmAbs  = Join-Path $repoRoot $mmRel
$hubAbs = Join-Path $repoRoot $hubRel

# DIAG quick
$r.Add("## DIAG") | Out-Null
$r.Add("") | Out-Null
$r.Add("- mindmap: " + (Test-Path -LiteralPath $mmAbs)) | Out-Null
$r.Add("- hub: " + (Test-Path -LiteralPath $hubAbs)) | Out-Null
$r.Add("") | Out-Null

if (-not (Test-Path -LiteralPath $mmAbs)) { throw ("Missing: " + $mmRel) }
BackupFile $mmRel

# PATCH A — rewrite mindmap component (preserva classes principais do layout)
$tsLines = @(
  '"use client";',
  '',
  'import Link from "next/link";',
  'import { useEffect, useMemo, useRef, useState } from "react";',
  'import type { CoreNodesV2 } from "@/lib/v2/types";',
  'import { coreNodesToDoorOrder, doorById } from "@/lib/v2/doors";',
  '',
  'type MetaLike = { coreNodes?: CoreNodesV2 };',
  'type DoorId = "mapa" | "linha" | "linha-do-tempo" | "provas" | "trilhas" | "debate";',
  '',
  'type Props = {',
  '  slug: string;',
  '  title?: string;',
  '  coreNodes?: CoreNodesV2;',
  '  meta?: MetaLike;',
  '};',
  '',
  'type Node = {',
  '  id: DoorId;',
  '  x: number;',
  '  y: number;',
  '  label: string;',
  '  desc: string;',
  '  href: string;',
  '};',
  '',
  'const ALL: DoorId[] = ["mapa", "linha", "linha-do-tempo", "provas", "trilhas", "debate"];',
  '',
  'const POS: Record<DoorId, { x: number; y: number }> = {',
  '  "mapa": { x: 50, y: 18 },',
  '  "linha": { x: 22, y: 34 },',
  '  "linha-do-tempo": { x: 18, y: 62 },',
  '  "provas": { x: 78, y: 34 },',
  '  "trilhas": { x: 82, y: 62 },',
  '  "debate": { x: 50, y: 82 }',
  '};',
  '',
  'const LABEL: Record<DoorId, string> = {',
  '  "mapa": "Mapa",',
  '  "linha": "Linha",',
  '  "linha-do-tempo": "Tempo",',
  '  "provas": "Provas",',
  '  "trilhas": "Trilhas",',
  '  "debate": "Debate"',
  '};',
  '',
  'const DESC: Record<DoorId, string> = {',
  '  "mapa": "Eixo central do universo. Comece por aqui.",',
  '  "linha": "O fio narrativo: resumo encadeado.",',
  '  "linha-do-tempo": "Datas, viradas e contexto histórico.",',
  '  "provas": "Documentos, dados e rastros do mundo real.",',
  '  "trilhas": "Caminhos guiados para avançar.",',
  '  "debate": "Perguntas, hipóteses e conversas em camadas."',
  '};',
  '',
  'function normalizeDoorOrder(order: string[]): DoorId[] {',
  '  const out: DoorId[] = [];',
  '  for (const raw of order) {',
  '    const id = raw as DoorId;',
  '    if (ALL.includes(id) && !out.includes(id)) out.push(id);',
  '  }',
  '  if (!out.includes("mapa")) out.unshift("mapa");',
  '  for (const id of ALL) {',
  '    if (!out.includes(id)) out.push(id);',
  '  }',
  '  return out;',
  '}',
  '',
  'function nextAfterMap(ids: DoorId[]): DoorId {',
  '  const i = ids.indexOf("mapa");',
  '  if (i >= 0 && i + 1 < ids.length) return ids[i + 1];',
  '  return ids[0] ? ids[0] : "mapa";',
  '}',
  '',
  'export default function Cv2MindmapHubClient(props: Props) {',
  '  const cn = props.coreNodes ?? props.meta?.coreNodes;',
  '  const ids = useMemo(() => normalizeDoorOrder(coreNodesToDoorOrder(cn)), [cn]);',
  '',
  '  const nodes = useMemo(() => {',
  '    return ids.map((id) => {',
  '      const def = doorById(id);',
  '      const p = POS[id];',
  '      return {',
  '        id,',
  '        x: p.x,',
  '        y: p.y,',
  '        label: LABEL[id],',
  '        desc: DESC[id],',
  '        href: def.href(props.slug)',
  '      } as Node;',
  '    });',
  '  }, [ids, props.slug]);',
  '',
  '  const [activeIdx, setActiveIdx] = useState<number>(0);',
  '  const nodesRef = useRef<Node[]>([]);',
  '  const idxRef = useRef<number>(0);',
  '',
  '  useEffect(() => { nodesRef.current = nodes; }, [nodes]);',
  '  useEffect(() => { idxRef.current = activeIdx; }, [activeIdx]);',
  '',
  '  useEffect(() => {',
  '    const i = ids.indexOf("mapa");',
  '    if (i >= 0) setActiveIdx(i);',
  '  }, [ids]);',
  '',
  '  useEffect(() => {',
  '    const onKeyDown = (e: KeyboardEvent) => {',
  '      const list = nodesRef.current;',
  '      if (!list || list.length === 0) return;',
  '      const key = e.key;',
  '      if (key === "ArrowRight" || key === "ArrowDown") {',
  '        e.preventDefault();',
  '        setActiveIdx((prev) => (prev + 1) % list.length);',
  '        return;',
  '      }',
  '      if (key === "ArrowLeft" || key === "ArrowUp") {',
  '        e.preventDefault();',
  '        setActiveIdx((prev) => (prev - 1 + list.length) % list.length);',
  '        return;',
  '      }',
  '      if (key === "Enter") {',
  '        e.preventDefault();',
  '        const i = idxRef.current;',
  '        const href = list[i] ? list[i].href : "";',
  '        if (href) window.location.href = href;',
  '      }',
  '    };',
  '    window.addEventListener("keydown", onKeyDown);',
  '    return () => window.removeEventListener("keydown", onKeyDown);',
  '  }, []);',
  '',
  '  const cx0 = 50;',
  '  const cy0 = 50;',
  '  const nextId = nextAfterMap(ids);',
  '  const mapHref = doorById("mapa").href(props.slug);',
  '  const nextHref = doorById(nextId).href(props.slug);',
  '',
  '  return (',
  '    <section className="cv2-mindmap" aria-label="Mapa mental do caderno">',
  '      <svg className="cv2-mindmapLines" viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true">',
  '        {nodes.map((n) => (',
  '          <g key={n.id}>',
  '            <line x1={cx0} y1={cy0} x2={n.x} y2={n.y} className="cv2-mindmapLine" />',
  '            <circle cx={n.x} cy={n.y} r="1.6" className="cv2-mindmapDot" />',
  '          </g>',
  '        ))}',
  '        <circle cx={cx0} cy={cy0} r="2.2" className="cv2-mindmapDot" />',
  '      </svg>',
  '',
  '      <div className="cv2-mindmapCenter">',
  '        <div className="cv2-card cv2-mindmapCenterCard">',
  '          <div className="cv2-mindmapKicker">Núcleo</div>',
  '          <div className="cv2-mindmapTitle">{props.title ?? "Mapa mental"}</div>',
  '          <div className="cv2-mindmapHint">Dica: setas navegam • Enter abre</div>',
  '          <div className="cv2-mindmapCtas">',
  '            <Link className="cv2-btn cv2-btnPrimary" href={mapHref} title="Comece pelo mapa">Comece pelo Mapa</Link>',
  '            <Link className="cv2-btn" href={nextHref} title="Próxima porta">Próxima porta</Link>',
  '          </div>',
  '        </div>',
  '      </div>',
  '',
  '      {nodes.map((n, idx) => (',
  '        <div',
  '          key={n.id}',
  '          className={"cv2-mindmapNode" + (idx === activeIdx ? " is-active" : "")}',
  '          style={{ left: n.x + "%", top: n.y + "%" }}',
  '        >',
  '          <Link className="cv2-mindmapNodeA" href={n.href} onMouseEnter={() => setActiveIdx(idx)}>',
  '            <div className="cv2-mindmapNodeLabel">{n.label}</div>',
  '            <div className="cv2-mindmapNodeDesc">{n.desc}</div>',
  '          </Link>',
  '        </div>',
  '      ))}',
  '    </section>',
  '  );',
  '}',
  ''
)

WriteText $mmAbs ([string]::Join($nl, $tsLines))
$r.Add("## Patch A") | Out-Null
$r.Add("- rewrote: " + $mmRel + " (ordem guiada por coreNodesToDoorOrder)") | Out-Null
$r.Add("") | Out-Null

# PATCH B — hub: tentar passar meta para o mindmap (best-effort)
if (Test-Path -LiteralPath $hubAbs) {
  $rawHub = ReadText $hubAbs
  if ($null -ne $rawHub -and $rawHub -match "Cv2MindmapHubClient") {
    if ($rawHub -match "Cv2MindmapHubClient[^>]*\bmeta\s*=" -or $rawHub -match "Cv2MindmapHubClient[^>]*\bcoreNodes\s*=") {
      $r.Add("## Patch B") | Out-Null
      $r.Add("- skip: hub já passa meta/coreNodes") | Out-Null
      $r.Add("") | Out-Null
    } else {
      $expr = $null
      if ($rawHub -match "data\.meta") { $expr = "data.meta" }
      elseif ($rawHub -match "caderno\.meta") { $expr = "caderno.meta" }
      elseif ($rawHub -match "\bmeta\b") { $expr = "meta" }

      if ($expr) {
        BackupFile $hubRel
        $patched = $rawHub

        $patched = $patched.Replace("<Cv2MindmapHubClient slug={slug} />", "<Cv2MindmapHubClient slug={slug} meta={" + $expr + "} />")
        $patched = $patched.Replace("<Cv2MindmapHubClient slug={slug}/>", "<Cv2MindmapHubClient slug={slug} meta={" + $expr + "} />")

        if ($patched -eq $rawHub) {
          # tentativa 2: injeta logo após slug={slug}
          $patched = [regex]::Replace($rawHub, "<Cv2MindmapHubClient([^>]*slug=\{slug\})([^>]*)\/>", "<Cv2MindmapHubClient`$1 meta={" + $expr + "}`$2 />")
        }

        WriteText $hubAbs $patched
        $r.Add("## Patch B") | Out-Null
        $r.Add("- hub: tentou passar meta={" + $expr + "} para Cv2MindmapHubClient") | Out-Null
        $r.Add("") | Out-Null
      } else {
        $r.Add("## Patch B") | Out-Null
        $r.Add("- skip: não encontrei expr de meta (data.meta/caderno.meta/meta). Mindmap fica com fallback.") | Out-Null
        $r.Add("") | Out-Null
      }
    }
  }
}

# VERIFY
AddLines $r (TryRun "npm run lint" {
  $npm = (Get-Command npm.cmd -ErrorAction Stop).Path
  & $npm run lint
})
AddLines $r (TryRun "npm run build" {
  $npm = (Get-Command npm.cmd -ErrorAction Stop).Path
  & $npm run build
})
AddLines $r (TryRun "Git status (post)" { git status })

WriteText $rep ([string]::Join($nl, $r.ToArray()) + $nl)
Write-Host ("[REPORT] " + $rep)
Write-Host "[OK] B7G v0_2 finalizado."