# cv-step-b7f-core-order-single-source-v0_1
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

function Grep([string]$rel, [string]$pattern) {
  $abs = Join-Path $repoRoot $rel
  if (-not (Test-Path -LiteralPath $abs)) { return @("[MISS] " + $rel) }
  $lines = Get-Content -LiteralPath $abs
  $hits = @()
  for ($i=0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match $pattern) { $hits += (("{0}:{1}: {2}" -f $rel, ($i+1), $lines[$i])) }
  }
  if ($hits.Count -eq 0) { return @("[NOHIT] " + $rel + " / " + $pattern) }
  return $hits
}

EnsureDir (Join-Path $repoRoot "reports")
EnsureDir (Join-Path $repoRoot "tools\_patch_backup")

$rep = Join-Path $repoRoot ("reports\" + $stamp + "-cv-step-b7f-core-order-single-source.md")
$r = New-Object System.Collections.Generic.List[string]
$r.Add("# Tijolo B7F — Core Order (single source) — " + $stamp) | Out-Null
$r.Add("") | Out-Null
$r.Add("Repo: " + $repoRoot) | Out-Null
$r.Add("") | Out-Null
AddLines $r (TryRun "Git status (pre)" { git status })

# -------------------------
# DIAG (antes): onde coreNodes / arrays de portas aparecem
# -------------------------
$r.Add("## DIAG — sinais de core order") | Out-Null
$r.Add("") | Out-Null
foreach ($x in (Grep "src\components\v2\Cv2PortalsCurated.tsx" "coreNodes|mapa|linha|provas|trilhas|debate")) { $r.Add($x) | Out-Null }
foreach ($x in (Grep "src\components\v2\Cv2MapRail.tsx" "coreNodes|mapa|linha|provas|trilhas|debate|door|rail")) { $r.Add($x) | Out-Null }
foreach ($x in (Grep "src\components\v2\Cv2MindmapHubClient.tsx" "coreNodes|mapa|linha|provas|trilhas|debate|mindmap")) { $r.Add($x) | Out-Null }
$r.Add("") | Out-Null

# -------------------------
# PATCH A) criar src/lib/v2/doors.ts
# -------------------------
$doorsRel = "src\lib\v2\doors.ts"
$doorsAbs = Join-Path $repoRoot $doorsRel
if (Test-Path -LiteralPath $doorsAbs) { BackupFile $doorsRel }

$doors = @(
  'import type { CoreNodesV2 } from "@/lib/v2/types";',
  '',
  'export type DoorId = "hub" | "mapa" | "linha" | "linha-do-tempo" | "provas" | "trilhas" | "debate";',
  'export type DoorDef = { id: DoorId; title: string; desc: string; href: (slug: string) => string };',
  '',
  'export const DOORS: DoorDef[] = [',
  '  { id: "hub", title: "Hub", desc: "Visão geral do universo.", href: (s) => "/c/" + encodeURIComponent(s) + "/v2" },',
  '  { id: "mapa", title: "Mapa", desc: "A porta central (comece por aqui).", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/mapa" },',
  '  { id: "linha", title: "Linha", desc: "Fatos em ordem e fio narrativo.", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/linha" },',
  '  { id: "linha-do-tempo", title: "Linha do tempo", desc: "Marcos e sequência histórica.", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/linha-do-tempo" },',
  '  { id: "provas", title: "Provas", desc: "Fontes, docs e evidências.", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/provas" },',
  '  { id: "trilhas", title: "Trilhas", desc: "Caminhos guiados e prática.", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/trilhas" },',
  '  { id: "debate", title: "Debate", desc: "Camadas de conversa e disputa.", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/debate" },',
  '];',
  '',
  'export const DOOR_SET = new Set<string>(DOORS.map((d) => d.id));',
  '',
  'function isRecord(v: unknown): v is Record<string, unknown> {',
  '  return !!v && typeof v === "object";',
  '}',
  '',
  'export function doorById(id: DoorId): DoorDef {',
  '  const d = DOORS.find((x) => x.id === id);',
  '  return d ? d : DOORS[1];',
  '}',
  '',
  'export function coreNodesToDoorOrder(coreNodes?: CoreNodesV2): DoorId[] {',
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
  'export function pickActiveDoor(active?: string, current?: string): DoorId {',
  '  const raw = (active ? active : (current ? current : "")).toString();',
  '  return DOOR_SET.has(raw) ? (raw as DoorId) : "mapa";',
  '}',
  '',
  'export function pickNextDoor(order: DoorId[], active: DoorId): DoorId {',
  '  if (!order.length) return "mapa";',
  '  const i = order.indexOf(active);',
  '  if (i < 0) return order[0];',
  '  const j = (i + 1) % order.length;',
  '  const n = order[j];',
  '  return n === active ? "mapa" : n;',
  '}',
  '',
  'export function pickRelatedDoors(order: DoorId[], active: DoorId, next: DoorId): DoorId[] {',
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
  ''
) -join "`n"

WriteText $doorsAbs ($doors + "`n")
$r.Add("## Patch A") | Out-Null
$r.Add("- criado/atualizado: " + $doorsRel) | Out-Null
$r.Add("") | Out-Null

# -------------------------
# PATCH B) reescrever Cv2PortalsCurated.tsx para usar doors.ts
# -------------------------
$pcRel = "src\components\v2\Cv2PortalsCurated.tsx"
$pcAbs = Join-Path $repoRoot $pcRel
if (-not (Test-Path -LiteralPath $pcAbs)) { throw ("Missing file: " + $pcRel) }
BackupFile $pcRel

$pc = @(
  'import Link from "next/link";',
  'import type { CoreNodesV2 } from "@/lib/v2/types";',
  'import { coreNodesToDoorOrder, doorById, pickActiveDoor, pickNextDoor, pickRelatedDoors } from "@/lib/v2/doors";',
  '',
  'type Props = { slug: string; active?: string; current?: string; coreNodes?: CoreNodesV2 };',
  '',
  'export default function Cv2PortalsCurated(props: Props) {',
  '  const active = pickActiveDoor(props.active, props.current);',
  '  const order = coreNodesToDoorOrder(props.coreNodes);',
  '  const next = pickNextDoor(order, active);',
  '  const rel = pickRelatedDoors(order, active, next);',
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

WriteText $pcAbs ($pc + "`n")
$r.Add("## Patch B") | Out-Null
$r.Add("- Cv2PortalsCurated agora usa src/lib/v2/doors.ts") | Out-Null
$r.Add("") | Out-Null

# -------------------------
# PATCH C) Tentativa segura: MapRail + Mindmap usam coreNodesToDoorOrder
# (só troca se achar array padrão)
# -------------------------
function PatchArrayToCoreOrder([string]$rel) {
  $abs = Join-Path $repoRoot $rel
  if (-not (Test-Path -LiteralPath $abs)) { return @("[MISS] " + $rel) }
  $raw = ReadText $abs
  if ($null -eq $raw) { return @("[MISS] " + $rel) }

  $changed = $false
  BackupFile $rel

  if ($raw -notmatch 'coreNodesToDoorOrder' ) {
    # injeta import se houver bloco de imports
    if ($raw -match '(?m)^import\s') {
      if ($raw -notmatch 'from\s+"@/lib/v2/doors"') {
        $raw = [Regex]::Replace(
          $raw,
          '(?m)^(import\s.+\r?\n)+',
          ('$0' + 'import { coreNodesToDoorOrder } from "@/lib/v2/doors";' + "`n"),
          1
        )
        $changed = $true
      }
    }
  }

  # troca arrays comuns
  $pat1 = '\[\s*"mapa"\s*,\s*"linha"\s*,\s*"provas"\s*,\s*"trilhas"\s*,\s*"debate"\s*\]'
  $pat2 = '\[\s*"mapa"\s*,\s*"linha"\s*,\s*"linha-do-tempo"\s*,\s*"provas"\s*,\s*"trilhas"\s*,\s*"debate"\s*\]'
  if ([Regex]::IsMatch($raw, $pat1)) {
    $raw = [Regex]::Replace($raw, $pat1, 'coreNodesToDoorOrder(coreNodes)', 1)
    $changed = $true
  } elseif ([Regex]::IsMatch($raw, $pat2)) {
    # mantém linha-do-tempo fora do núcleo por padrão (porta extra), então não substitui por completo
    # mas ainda deixa o núcleo guiar e depois alguém pode inserir linha-do-tempo como “extra”
    $raw = [Regex]::Replace($raw, $pat2, 'coreNodesToDoorOrder(coreNodes)', 1)
    $changed = $true
  }

  if ($changed) {
    WriteText $abs ($raw + "`n")
    return @("[OK] patched " + $rel)
  }
  return @("[WARN] no pattern matched " + $rel)
}

$r.Add("## Patch C") | Out-Null
foreach ($msg in (PatchArrayToCoreOrder "src\components\v2\Cv2MapRail.tsx")) { $r.Add($msg) | Out-Null }
foreach ($msg in (PatchArrayToCoreOrder "src\components\v2\Cv2MindmapHubClient.tsx")) { $r.Add($msg) | Out-Null }
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
Write-Host "[OK] B7F finalizado."