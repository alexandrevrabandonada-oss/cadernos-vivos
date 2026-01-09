# cv-hotfix-b7e2-portals-curated-no-any-v0_1
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

$rep = Join-Path $repoRoot ("reports\" + $stamp + "-cv-hotfix-b7e2-portals-curated-no-any.md")
$r = New-Object System.Collections.Generic.List[string]
$r.Add("# Hotfix B7E2 — Cv2PortalsCurated sem any — " + $stamp) | Out-Null
$r.Add("") | Out-Null
$r.Add("Repo: " + $repoRoot) | Out-Null
$r.Add("") | Out-Null
AddLines $r (TryRun "Git status (pre)" { git status })

# -------------------------
# PATCH: reescrever Cv2PortalsCurated.tsx sem any
# -------------------------
$rel = "src\components\v2\Cv2PortalsCurated.tsx"
$abs = Join-Path $repoRoot $rel
if (-not (Test-Path -LiteralPath $abs)) { throw ("Missing file: " + $rel) }
BackupFile $rel

$ts = @(
  'import Link from "next/link";',
  'import type { CoreNodesV2 } from "@/lib/v2/types";',
  '',
  'type DoorId = "hub" | "mapa" | "linha" | "linha-do-tempo" | "provas" | "trilhas" | "debate";',
  'type DoorDef = { id: DoorId; title: string; desc: string; href: (slug: string) => string };',
  '',
  'type Props = { slug: string; active?: string; current?: string; coreNodes?: CoreNodesV2 };',
  '',
  'const DOORS: DoorDef[] = [',
  '  { id: "hub", title: "Hub", desc: "Visão geral do universo.", href: (s) => "/c/" + encodeURIComponent(s) + "/v2" },',
  '  { id: "mapa", title: "Mapa", desc: "A porta central (comece por aqui).", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/mapa" },',
  '  { id: "linha", title: "Linha", desc: "Fatos em ordem e fio narrativo.", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/linha" },',
  '  { id: "linha-do-tempo", title: "Linha do tempo", desc: "Marcos e sequência histórica.", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/linha-do-tempo" },',
  '  { id: "provas", title: "Provas", desc: "Fontes, docs e evidências.", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/provas" },',
  '  { id: "trilhas", title: "Trilhas", desc: "Caminhos guiados e prática.", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/trilhas" },',
  '  { id: "debate", title: "Debate", desc: "Camadas de conversa e disputa.", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/debate" },',
  '];',
  '',
  'const DOOR_SET = new Set<string>(DOORS.map((d) => d.id));',
  '',
  'function isRecord(v: unknown): v is Record<string, unknown> {',
  '  return !!v && typeof v === "object";',
  '}',
  '',
  'function doorById(id: DoorId): DoorDef {',
  '  const d = DOORS.find((x) => x.id === id);',
  '  return d ? d : DOORS[1];',
  '}',
  '',
  'function coreToDoorOrder(coreNodes?: CoreNodesV2): DoorId[] {',
  '  const base: DoorId[] = ["mapa","linha","provas","trilhas","debate"];',
  '  if (!coreNodes || !coreNodes.length) return base;',
  '',
  '  const out: DoorId[] = [];',
  '  for (const v of coreNodes) {',
  '    if (typeof v === "string") {',
  '      const k = v.trim();',
  '      if (DOOR_SET.has(k)) out.push(k as DoorId);',
  '      continue;',
  '    }',
  '    if (isRecord(v)) {',
  '      const idVal = v["id"];',
  '      if (typeof idVal === "string") {',
  '        const k = idVal.trim();',
  '        if (DOOR_SET.has(k)) out.push(k as DoorId);',
  '      }',
  '    }',
  '  }',
  '',
  '  const seen = new Set<DoorId>();',
  '  const dedup: DoorId[] = [];',
  '  for (const d of out) {',
  '    if (seen.has(d)) continue;',
  '    seen.add(d);',
  '    dedup.push(d);',
  '  }',
  '  return dedup.length ? dedup : base;',
  '}',
  '',
  'function pickActive(p: Props): DoorId {',
  '  const raw = (p.active ? p.active : (p.current ? p.current : "")).toString();',
  '  return DOOR_SET.has(raw) ? (raw as DoorId) : "mapa";',
  '}',
  '',
  'function pickNext(order: DoorId[], active: DoorId): DoorId {',
  '  if (!order.length) return "mapa";',
  '  const i = order.indexOf(active);',
  '  if (i < 0) return order[0];',
  '  const j = (i + 1) % order.length;',
  '  const n = order[j];',
  '  return n === active ? "mapa" : n;',
  '}',
  '',
  'function pickRelated(order: DoorId[], active: DoorId, next: DoorId): DoorId[] {',
  '  const out: DoorId[] = [];',
  '  for (const d of order) {',
  '    if (d === active) continue;',
  '    if (d === next) continue;',
  '    out.push(d);',
  '  }',
  '  for (const d of ["hub","mapa","linha","linha-do-tempo","provas","trilhas","debate"] as DoorId[]) {',
  '    if (d === active || d === next) continue;',
  '    if (out.includes(d)) continue;',
  '    out.push(d);',
  '  }',
  '  return out.slice(0, 5);',
  '}',
  '',
  'export default function Cv2PortalsCurated(props: Props) {',
  '  const active = pickActive(props);',
  '  const order = coreToDoorOrder(props.coreNodes);',
  '  const next = pickNext(order, active);',
  '  const rel = pickRelated(order, active, next);',
  '  const nextDoor = doorById(next);',
  '',
  '  return (',
  '    <section className="cv2-portals-curated" aria-label="Portais do universo">',
  '      <div className="cv2-portals-curated__head">',
  '        <div className="cv2-portals-curated__kicker">Portais</div>',
  '        <div className="cv2-portals-curated__title">Próxima porta</div>',
  '        <div className="cv2-portals-curated__sub">Siga o fio: atravessar é aprender.</div>',
  '      </div>',
  '',
  '      <div className="cv2-portals-curated__next">',
  '        <Link className="cv2-portal-card cv2-portal-card--next" href={nextDoor.href(props.slug)}>',
  '          <div className="cv2-portal-card__title">{nextDoor.title}</div>',
  '          <div className="cv2-portal-card__desc">{nextDoor.desc}</div>',
  '        </Link>',
  '',
  '        {active !== "mapa" ? (',
  '          <Link className="cv2-portal-pill" href={doorById("mapa").href(props.slug)} title="Comece pelo mapa">',
  '            Comece pelo Mapa',
  '          </Link>',
  '        ) : null}',
  '      </div>',
  '',
  '      <div className="cv2-portals-curated__relHead">Relacionados</div>',
  '      <div className="cv2-portals-curated__grid">',
  '        {rel.map((id) => {',
  '          const d = doorById(id);',
  '          return (',
  '            <Link key={d.id} className="cv2-portal-card" href={d.href(props.slug)}>',
  '              <div className="cv2-portal-card__title">{d.title}</div>',
  '              <div className="cv2-portal-card__desc">{d.desc}</div>',
  '            </Link>',
  '          );',
  '        })}',
  '      </div>',
  '    </section>',
  '  );',
  '}',
  ''
) -join "`n"

WriteText $abs ($ts + "`n")
$r.Add("## Patch") | Out-Null
$r.Add("- reescrito sem any: " + $rel) | Out-Null
$r.Add("") | Out-Null

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
Write-Host "[OK] Hotfix B7E2 finalizado."