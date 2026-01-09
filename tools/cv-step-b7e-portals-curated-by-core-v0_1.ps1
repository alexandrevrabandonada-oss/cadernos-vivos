# cv-step-b7e-portals-curated-by-core-v0_1
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

$rep = Join-Path $repoRoot ("reports\" + $stamp + "-cv-step-b7e-portals-curated-by-core.md")
$r = New-Object System.Collections.Generic.List[string]
$r.Add("# Tijolo B7E — Portais curados pelo núcleo (coreNodes) — " + $stamp) | Out-Null
$r.Add("") | Out-Null
$r.Add("Repo: " + $repoRoot) | Out-Null
$r.Add("") | Out-Null
AddLines $r (TryRun "Git status (pre)" { git status })

# -------------------------
# PATCH A) novo componente: Cv2PortalsCurated.tsx
# -------------------------
$compRel = "src\components\v2\Cv2PortalsCurated.tsx"
$compAbs = Join-Path $repoRoot $compRel
if (Test-Path -LiteralPath $compAbs) { BackupFile $compRel }

$comp = @(
  'import Link from "next/link";',
  'import type { CoreNodesV2 } from "@/lib/v2/types";',
  '',
  'type DoorId = "mapa" | "linha" | "linha-do-tempo" | "provas" | "trilhas" | "debate" | "hub";',
  'type DoorDef = { id: DoorId; title: string; desc: string; href: (slug: string) => string };',
  '',
  'type Props = { slug: string; active?: string; current?: string; coreNodes?: CoreNodesV2 };',
  '',
  'const DOORS: DoorDef[] = [',
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
  'function doorById(id: DoorId): DoorDef {',
  '  const d = DOORS.find((x) => x.id === id);',
  '  return d ? d : DOORS[0];',
  '}',
  '',
  'function coreToDoorOrder(coreNodes?: CoreNodesV2): DoorId[] {',
  '  const base: DoorId[] = ["mapa","linha","provas","trilhas","debate"];',
  '  if (!coreNodes || !coreNodes.length) return base;',
  '  const out: DoorId[] = [];',
  '  for (const v of coreNodes) {',
  '    const id = typeof v === "string" ? v : (v && typeof v === "object" && "id" in v ? (v as any).id : undefined);',
  '    if (typeof id !== "string") continue;',
  '    const k = id.trim();',
  '    if (!k) continue;',
  '    if (DOOR_SET.has(k)) out.push(k as DoorId);',
  '  }',
  '  // dedupe + fallback se ficar vazio',
  '  const seen = new Set<DoorId>();',
  '  const dedup: DoorId[] = [];',
  '  for (const d of out) { if (seen.has(d)) continue; seen.add(d); dedup.push(d); }',
  '  return dedup.length ? dedup : base;',
  '}',
  '',
  'function pickActive(p: Props): DoorId {',
  '  const raw = (p.active ? p.active : (p.current ? p.current : "")).toString();',
  '  return (DOOR_SET.has(raw) ? (raw as DoorId) : "mapa");',
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
  '  // completa com portas faltantes (para sempre existir navegação)',
  '  for (const d of ["mapa","linha","linha-do-tempo","provas","trilhas","debate"] as DoorId[]) {',
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

WriteText $compAbs $comp
$r.Add("## Patch A") | Out-Null
$r.Add("- criado/atualizado: " + $compRel) | Out-Null
$r.Add("") | Out-Null

# -------------------------
# PATCH B) CSS (globals.css)
# -------------------------
$cssRel = "src\app\globals.css"
$cssAbs = Join-Path $repoRoot $cssRel
$cssRaw = ReadText $cssAbs
if ($null -eq $cssRaw) { throw ("Missing file: " + $cssRel) }
BackupFile $cssRel

if ($cssRaw -notmatch '\.cv2-portals-curated\s*{') {
  $cssAdd = @(
    "",
    "/* CV2: portals curated (coreNodes) */",
    ".cv2-portals-curated {",
    "  margin-top: 12px;",
    "  padding: 12px;",
    "  border: 1px solid rgba(255,255,255,0.10);",
    "  border-radius: 14px;",
    "  background: rgba(255,255,255,0.06);",
    "  backdrop-filter: blur(10px);",
    "}",
    ".cv2-portals-curated__head {",
    "  display: flex;",
    "  flex-direction: column;",
    "  gap: 4px;",
    "  margin-bottom: 10px;",
    "}",
    ".cv2-portals-curated__kicker {",
    "  font-size: 11px;",
    "  letter-spacing: 0.18em;",
    "  text-transform: uppercase;",
    "  opacity: 0.75;",
    "}",
    ".cv2-portals-curated__title {",
    "  font-size: 14px;",
    "  font-weight: 900;",
    "}",
    ".cv2-portals-curated__sub {",
    "  font-size: 12px;",
    "  opacity: 0.75;",
    "}",
    ".cv2-portals-curated__next {",
    "  display: flex;",
    "  flex-direction: column;",
    "  gap: 10px;",
    "  margin-bottom: 10px;",
    "}",
    ".cv2-portal-pill {",
    "  display: inline-flex;",
    "  align-items: center;",
    "  gap: 8px;",
    "  width: fit-content;",
    "  padding: 8px 10px;",
    "  border-radius: 999px;",
    "  border: 1px solid rgba(255,255,255,0.12);",
    "  background: rgba(0,0,0,0.18);",
    "  text-decoration: none;",
    "  font-size: 12px;",
    "  font-weight: 800;",
    "}",
    ".cv2-portals-curated__relHead {",
    "  font-size: 12px;",
    "  font-weight: 900;",
    "  opacity: 0.85;",
    "  margin: 6px 0 8px;",
    "}",
    ".cv2-portals-curated__grid {",
    "  display: grid;",
    "  grid-template-columns: 1fr;",
    "  gap: 10px;",
    "}",
    "@media (min-width: 720px) {",
    "  .cv2-portals-curated__grid {",
    "    grid-template-columns: 1fr 1fr;",
    "  }",
    "}",
    ".cv2-portal-card {",
    "  display: block;",
    "  padding: 12px;",
    "  border-radius: 14px;",
    "  border: 1px solid rgba(255,255,255,0.12);",
    "  background: rgba(0,0,0,0.18);",
    "  text-decoration: none;",
    "}",
    ".cv2-portal-card--next {",
    "  border-color: rgba(255,255,255,0.22);",
    "  background: rgba(255,255,255,0.08);",
    "}",
    ".cv2-portal-card__title {",
    "  font-size: 13px;",
    "  font-weight: 900;",
    "  margin-bottom: 4px;",
    "}",
    ".cv2-portal-card__desc {",
    "  font-size: 12px;",
    "  opacity: 0.8;",
    "}",
    ".cv2-portal-card:hover {",
    "  transform: translateY(-1px);",
    "}",
    ""
  ) -join "`n"
  $cssRaw = $cssRaw + $cssAdd
  WriteText $cssAbs $cssRaw
}

$r.Add("## Patch B") | Out-Null
$r.Add("- globals.css: estilos cv2-portals-curated") | Out-Null
$r.Add("") | Out-Null

# -------------------------
# PATCH C) Trocar V2Portals por Cv2PortalsCurated nas portas V2
# -------------------------
function PickExpr([string]$raw) {
  $hasCaderno = ($raw -match '(?m)\b(const|let|var)\s+caderno\b')
  $hasData    = ($raw -match '(?m)\b(const|let|var)\s+data\b')
  if ($hasCaderno) { return "caderno.meta.coreNodes" }
  if ($hasData)    { return "data.meta.coreNodes" }
  $m = [Regex]::Match($raw, '(?m)\b(const|let|var)\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*await\s+loadCadernoV2\s*\(')
  if ($m.Success) { return ($m.Groups[2].Value + ".meta.coreNodes") }
  return "undefined"
}

function PatchPage([string]$rel) {
  $abs = Join-Path $repoRoot $rel
  $raw = ReadText $abs
  if ($null -eq $raw) { return }

  if ($raw -notmatch '<V2Portals\b') { return }

  BackupFile $rel

  # remove import antigo
  $raw = [Regex]::Replace($raw, '(?m)^\s*import\s+V2Portals\s+from\s+"@\/components\/v2\/V2Portals";\s*\r?\n', '')

  # garante import novo (insere no bloco de imports)
  if ($raw -notmatch 'import Cv2PortalsCurated from "@/components/v2/Cv2PortalsCurated";') {
    $lines = $raw -split "`r?`n"
    $start = 0
    if ($lines.Length -gt 0 -and ($lines[0] -match '^(?:"use client"|"use server"|''use client''|''use server'');\s*$')) { $start = 1 }
    $lastImport = -1
    for ($i = $start; $i -lt $lines.Length; $i++) {
      $t = $lines[$i].Trim()
      if ($t -match '^import\s') { $lastImport = $i; continue }
      if ($lastImport -ge 0 -and $t -ne '') { break }
      if ($lastImport -lt 0 -and $t -ne '') { break }
    }
    $out = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $lines.Length; $i++) {
      $out.Add($lines[$i]) | Out-Null
      if ($lastImport -ge 0 -and $i -eq $lastImport) {
        $out.Add('import Cv2PortalsCurated from "@/components/v2/Cv2PortalsCurated";') | Out-Null
      }
    }
    if ($lastImport -lt 0) {
      $out = New-Object System.Collections.Generic.List[string]
      if ($start -eq 1) {
        $out.Add($lines[0]) | Out-Null
        $out.Add('import Cv2PortalsCurated from "@/components/v2/Cv2PortalsCurated";') | Out-Null
        for ($k=1; $k -lt $lines.Length; $k++) { $out.Add($lines[$k]) | Out-Null }
      } else {
        $out.Add('import Cv2PortalsCurated from "@/components/v2/Cv2PortalsCurated";') | Out-Null
        foreach ($ln in $lines) { $out.Add($ln) | Out-Null }
      }
    }
    $raw = ($out -join "`n")
  }

  # troca o componente no JSX
  $raw = $raw.Replace("<V2Portals", "<Cv2PortalsCurated")
  $raw = $raw.Replace("</V2Portals>", "</Cv2PortalsCurated>")

  # injeta coreNodes prop se não tiver
  if ($raw -match '<Cv2PortalsCurated\b' -and $raw -notmatch 'coreNodes=\{') {
    $expr = PickExpr $raw
    $raw = [Regex]::Replace($raw, '(<Cv2PortalsCurated\b[^>]*)(\s*\/?>)', ('$1' + ' coreNodes={' + $expr + '}$2'), 1)
  }

  WriteText $abs ($raw + "`n")
}

$pages = @(
  "src\app\c\[slug]\v2\page.tsx",
  "src\app\c\[slug]\v2\debate\page.tsx",
  "src\app\c\[slug]\v2\linha\page.tsx",
  "src\app\c\[slug]\v2\linha-do-tempo\page.tsx",
  "src\app\c\[slug]\v2\mapa\page.tsx",
  "src\app\c\[slug]\v2\provas\page.tsx",
  "src\app\c\[slug]\v2\trilhas\page.tsx",
  "src\app\c\[slug]\v2\trilhas\[id]\page.tsx"
)
foreach ($p in $pages) { PatchPage $p }

$r.Add("## Patch C") | Out-Null
$r.Add("- portas V2: trocar V2Portals -> Cv2PortalsCurated (+ coreNodes)") | Out-Null
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
Write-Host "[OK] B7E finalizado."