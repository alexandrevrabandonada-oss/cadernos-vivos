# cv-hotfix-b7f2-core-order-lint-warnings-v0_1
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

$rep = Join-Path $repoRoot ("reports\" + $stamp + "-cv-hotfix-b7f2-core-order-lint-warnings.md")
$r = New-Object System.Collections.Generic.List[string]
$r.Add("# Hotfix B7F2 — Core order lint warnings — " + $stamp) | Out-Null
$r.Add("") | Out-Null
$r.Add("Repo: " + $repoRoot) | Out-Null
$r.Add("") | Out-Null
AddLines $r (TryRun "Git status (pre)" { git status })

# -------------------------
# DIAG: ocorrências do símbolo
# -------------------------
$r.Add("## DIAG — coreNodesToDoorOrder occurrences") | Out-Null
$r.Add("") | Out-Null

$targets = @(
  "src\components\v2\Cv2MapRail.tsx",
  "src\components\v2\Cv2MindmapHubClient.tsx"
)

foreach ($rel in $targets) {
  $abs = Join-Path $repoRoot $rel
  if (-not (Test-Path -LiteralPath $abs)) { $r.Add("[MISS] " + $rel) | Out-Null; continue }
  $raw = ReadText $abs
  $count = 0
  if ($null -ne $raw) { $count = ([regex]::Matches($raw, "coreNodesToDoorOrder")).Count }
  $r.Add(("[INFO] " + $rel + " -> count=" + $count)) | Out-Null
}
$r.Add("") | Out-Null

# -------------------------
# PATCH A: reescrever Cv2MapRail.tsx para usar coreNodesToDoorOrder
# -------------------------
$mapRel = "src\components\v2\Cv2MapRail.tsx"
$mapAbs = Join-Path $repoRoot $mapRel
if (-not (Test-Path -LiteralPath $mapAbs)) { throw ("Missing file: " + $mapRel) }
BackupFile $mapRel

$mapTs = @(
  'import Link from "next/link";',
  'import type { CoreNodesV2 } from "@/lib/v2/types";',
  'import { coreNodesToDoorOrder } from "@/lib/v2/doors";',
  '',
  'type RailProps = {',
  '  slug: string;',
  '  title?: string;',
  '  coreNodes?: CoreNodesV2;',
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
  '  const pages = orderPages(props.coreNodes);',
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

WriteText $mapAbs ($mapTs + "`n")
$r.Add("## Patch A") | Out-Null
$r.Add("- reescrito: " + $mapRel + " (agora usa coreNodesToDoorOrder)") | Out-Null
$r.Add("") | Out-Null

# -------------------------
# PATCH B: remover import morto em Cv2MindmapHubClient.tsx (se não usado)
# -------------------------
$mmRel = "src\components\v2\Cv2MindmapHubClient.tsx"
$mmAbs = Join-Path $repoRoot $mmRel
if (Test-Path -LiteralPath $mmAbs) {
  $raw = ReadText $mmAbs
  if ($null -ne $raw) {
    $count = ([regex]::Matches($raw, "coreNodesToDoorOrder")).Count
    if ($count -le 1 -and $raw -match 'import\s+\{\s*coreNodesToDoorOrder\s*\}\s+from\s+"@/lib/v2/doors";') {
      BackupFile $mmRel
      $raw2 = [regex]::Replace($raw, '(?m)^\s*import\s+\{\s*coreNodesToDoorOrder\s*\}\s+from\s+"@/lib/v2/doors";\s*\r?\n', "")
      WriteText $mmAbs ($raw2 + "`n")
      $r.Add("## Patch B") | Out-Null
      $r.Add("- removido import morto: " + $mmRel) | Out-Null
      $r.Add("") | Out-Null
    } else {
      $r.Add("## Patch B") | Out-Null
      $r.Add("- skip (coreNodesToDoorOrder já é usado ou padrão não encontrado): " + $mmRel) | Out-Null
      $r.Add("") | Out-Null
    }
  }
} else {
  $r.Add("## Patch B") | Out-Null
  $r.Add("- skip (missing): " + $mmRel) | Out-Null
  $r.Add("") | Out-Null
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
Write-Host "[OK] Hotfix B7F2 finalizado."