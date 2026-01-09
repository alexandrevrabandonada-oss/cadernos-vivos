# cv-hotfix-b7f3-maprail-meta-compat-v0_1
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

$rep = Join-Path $repoRoot ("reports\" + $stamp + "-cv-hotfix-b7f3-maprail-meta-compat.md")
$r = New-Object System.Collections.Generic.List[string]
$r.Add("# Hotfix B7F3 — MapRail meta compat — " + $stamp) | Out-Null
$r.Add("") | Out-Null
$r.Add("Repo: " + $repoRoot) | Out-Null
$r.Add("") | Out-Null
AddLines $r (TryRun "Git status (pre)" { git status })

# -------------------------
# DIAG: onde existe meta= no Cv2MapRail
# -------------------------
$r.Add("## DIAG — usos de Cv2MapRail com meta=") | Out-Null
$r.Add("") | Out-Null
$scanRoot = Join-Path $repoRoot "src\app\c\[slug]\v2"
if (Test-Path -LiteralPath $scanRoot) {
  $hits = @()
  Get-ChildItem -LiteralPath $scanRoot -Recurse -File -Filter "*.tsx" | ForEach-Object {
    $rel = $_.FullName.Substring($repoRoot.Length).TrimStart("\")
    $raw = ReadText $_.FullName
    if ($null -ne $raw -and $raw -match 'Cv2MapRail' -and $raw -match 'meta\s*=') { $hits += $rel }
  }
  if ($hits.Count -eq 0) { $r.Add("[OK] nenhum uso com meta= encontrado") | Out-Null }
  else { foreach ($h in $hits) { $r.Add("- " + $h) | Out-Null } }
} else {
  $r.Add("[WARN] pasta nao encontrada: src/app/c/[slug]/v2") | Out-Null
}
$r.Add("") | Out-Null

# -------------------------
# PATCH: tornar Cv2MapRail compat com meta
# -------------------------
$rel = "src\components\v2\Cv2MapRail.tsx"
$abs = Join-Path $repoRoot $rel
if (-not (Test-Path -LiteralPath $abs)) { throw ("Missing file: " + $rel) }
BackupFile $rel

$ts = @(
  'import Link from "next/link";',
  'import type { CoreNodesV2 } from "@/lib/v2/types";',
  'import { coreNodesToDoorOrder } from "@/lib/v2/doors";',
  '',
  'type MetaLike = { coreNodes?: CoreNodesV2 };',
  '',
  'type RailProps = {',
  '  slug: string;',
  '  title?: string;',
  '  coreNodes?: CoreNodesV2;',
  '  meta?: MetaLike;',
  '};',
  '',
  'type RailDoorId = "mapa" | "linha" | "linha-do-tempo" | "provas" | "trilhas" | "debate";',
  'type RailPage = { id: RailDoorId; label: string; href: (slug: string) => string };',
  '',
  'const PAGES: RailPage[] = [',
  '  { id: "mapa", label: "Mapa", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/mapa" },',
  '  { id: "linha", label: "Linha", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/linha" },',
  '  { id: "linha-do-tempo", label: "Tempo", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/linha-do-tempo" },',
  '  { id: "provas", label: "Provas", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/provas" },',
  '  { id: "trilhas", label: "Trilhas", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/trilhas" },',
  '  { id: "debate", label: "Debate", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/debate" },',
  '];',
  '',
  'function orderPages(coreNodes?: CoreNodesV2): RailPage[] {',
  '  const order = coreNodesToDoorOrder(coreNodes);',
  '  const out: RailPage[] = [];',
  '  for (const id of order) {',
  '    const p = PAGES.find((x) => x.id === id);',
  '    if (p) out.push(p);',
  '  }',
  '  // garante o eixo (mapa) sempre presente',
  '  if (!out.some((p) => p.id === "mapa")) out.unshift(PAGES[0]);',
  '  // adiciona portas restantes (ex.: linha-do-tempo) mantendo ordem local',
  '  for (const p of PAGES) {',
  '    if (!out.some((x) => x.id === p.id)) out.push(p);',
  '  }',
  '  return out;',
  '}',
  '',
  'export function Cv2MapRail(props: RailProps) {',
  '  const slug = props.slug;',
  '  const title = props.title ? props.title : "Mapa";',
  '  const cn = props.coreNodes ? props.coreNodes : (props.meta ? props.meta.coreNodes : undefined);',
  '  const pages = orderPages(cn);',
  '',
  '  return (',
  '    <aside className="cv2-mapRail" aria-label="Corredor de portas">',
  '      <div className="cv2-mapRail__inner">',
  '        <div className="cv2-mapRail__title">',
  '          <div className="cv2-mapRail__kicker">Eixo</div>',
  '          <div className="cv2-mapRail__name">{title}</div>',
  '        </div>',
  '',
  '        <nav className="cv2-mapRail__nav" aria-label="Portas do universo">',
  '          {pages.map((p) => (',
  '            <Link key={p.id} className={"cv2-mapRail__a" + (p.id === "mapa" ? " is-axis" : "")} href={p.href(slug)}>',
  '              <span className="cv2-mapRail__dot" aria-hidden="true" />',
  '              <span className="cv2-mapRail__txt">{p.label}</span>',
  '            </Link>',
  '          ))}',
  '        </nav>',
  '',
  '        <div className="cv2-mapRail__hint">Mapa é o eixo. O resto são portas.</div>',
  '      </div>',
  '    </aside>',
  '  );',
  '}',
  '',
  'export default Cv2MapRail;',
  ''
) -join "`n"

WriteText $abs ($ts + "`n")
$r.Add("## Patch") | Out-Null
$r.Add("- compat meta?: MetaLike em " + $rel) | Out-Null
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
Write-Host "[OK] Hotfix B7F3 finalizado."