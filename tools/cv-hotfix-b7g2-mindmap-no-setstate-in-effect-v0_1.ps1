# cv-hotfix-b7g2-mindmap-no-setstate-in-effect-v0_1
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
  try { $out = & $sb 2>&1 | Out-String; return @("## " + $label, "", $out.TrimEnd(), "") }
  catch { return @("## " + $label, "", ("ERR: " + $_.Exception.Message), "") }
}
function AddLines([System.Collections.Generic.List[string]]$list, [object]$block) {
  if ($null -eq $block) { return }
  foreach ($x in @($block)) { $list.Add([string]$x) | Out-Null }
}

EnsureDir (Join-Path $repoRoot "reports")
EnsureDir (Join-Path $repoRoot "tools\_patch_backup")

$rep = Join-Path $repoRoot ("reports\" + $stamp + "-cv-hotfix-b7g2-mindmap-no-setstate-in-effect.md")
$r = New-Object System.Collections.Generic.List[string]
$r.Add("# Hotfix B7G2 — Mindmap sem setState em effect — " + $stamp) | Out-Null
$r.Add("") | Out-Null
$r.Add("Repo: " + $repoRoot) | Out-Null
$r.Add("") | Out-Null

AddLines $r (TryRun "Git status (pre)" { git status })

$mmRel = "src\components\v2\Cv2MindmapHubClient.tsx"
$mmAbs = Join-Path $repoRoot $mmRel
if (-not (Test-Path -LiteralPath $mmAbs)) { throw ("Missing: " + $mmRel) }

# DIAG: detectar bloco que causa lint
$r.Add("## DIAG") | Out-Null
$r.Add("") | Out-Null
$raw = ReadText $mmAbs
$hasBad = ($null -ne $raw -and $raw -match "setActiveIdx\(i\)" -and $raw -match "\[ids\]")
$r.Add("- has_setstate_in_effect_pattern: " + $hasBad) | Out-Null
$r.Add("") | Out-Null

BackupFile $mmRel

# PATCH: reescrever arquivo (mesma base do B7G v0_2, mas sem setState em effect)
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
  '  const [activeIdx, setActiveIdx] = useState<number>(() => {',
  '    const i = ids.indexOf("mapa");',
  '    return i >= 0 ? i : 0;',
  '  });',
  '',
  '  const nodesRef = useRef<Node[]>([]);',
  '  const idxRef = useRef<number>(0);',
  '',
  '  useEffect(() => { nodesRef.current = nodes; }, [nodes]);',
  '  useEffect(() => { idxRef.current = activeIdx; }, [activeIdx]);',
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

WriteText $mmAbs ([string]::Join($nl, $tsLines) + $nl)
$r.Add("## Patch") | Out-Null
$r.Add("- rewrote: " + $mmRel + " (init state no mapa; sem setState em effect)") | Out-Null
$r.Add("") | Out-Null

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
Write-Host "[OK] Hotfix B7G2 finalizado."