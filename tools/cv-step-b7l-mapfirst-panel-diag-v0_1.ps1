# cv-step-b7l-mapfirst-panel-diag-v0_1
$ErrorActionPreference = "Stop"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$repoRoot = (Resolve-Path ".").Path
$nl = [Environment]::NewLine

function EnsureDir([string]$abs) { if (-not (Test-Path -LiteralPath $abs)) { [IO.Directory]::CreateDirectory($abs) | Out-Null } }
function ReadText([string]$abs) { if (-not (Test-Path -LiteralPath $abs)) { return $null }; return [IO.File]::ReadAllText($abs) }
function WriteText([string]$abs, [string]$text) {
  $enc = New-Object System.Text.UTF8Encoding($false)
  EnsureDir (Split-Path -Parent $abs)
  [IO.File]::WriteAllText($abs, $text, $enc)
}

EnsureDir (Join-Path $repoRoot "reports")
$rep = Join-Path $repoRoot ("reports\" + $stamp + "-cv-step-b7l-mapfirst-panel-diag.md")
$r = New-Object System.Collections.Generic.List[string]
$r.Add("# DIAG B7L — Map-first panel gaps — " + $stamp) | Out-Null
$r.Add("") | Out-Null
$r.Add("Repo: " + $repoRoot) | Out-Null
$r.Add("") | Out-Null

$r.Add("## Git status") | Out-Null
$r.Add("") | Out-Null
try { $r.Add((git status | Out-String).TrimEnd()) | Out-Null } catch { $r.Add("ERR: git status") | Out-Null }
$r.Add("") | Out-Null

$comps = @(
  "src\components\v2\Cv2DoorGuide.tsx",
  "src\components\v2\Cv2PortalsCurated.tsx",
  "src\components\v2\Cv2UniverseRail.tsx",
  "src\components\v2\Cv2MapRail.tsx",
  "src\components\v2\Cv2CoreNodes.tsx",
  "src\components\v2\Cv2MindmapHubClient.tsx"
)

$r.Add("## Componentes-chave (presenca)") | Out-Null
$r.Add("") | Out-Null
foreach ($c in $comps) {
  $abs = Join-Path $repoRoot $c
  $r.Add("- " + $c + " : " + ($(if(Test-Path -LiteralPath $abs){"OK"}else{"MISSING"}))) | Out-Null
}
$r.Add("") | Out-Null

$v2Dir = Join-Path $repoRoot "src\app\c\[slug]\v2"
$r.Add("## Pages V2 (features por pagina)") | Out-Null
$r.Add("") | Out-Null
if (-not (Test-Path -LiteralPath $v2Dir)) {
  $r.Add("[ERR] missing: src/app/c/[slug]/v2") | Out-Null
} else {
  $pages = Get-ChildItem -LiteralPath $v2Dir -Recurse -File -Filter "page.tsx"
  foreach ($p in $pages) {
    $raw = ReadText $p.FullName
    if ($null -eq $raw) { continue }
    $rel = $p.FullName.Substring($repoRoot.Length).TrimStart("\")
    $hasDoor = ($raw.IndexOf("Cv2DoorGuide", [StringComparison]::OrdinalIgnoreCase) -ge 0)
    $hasPort = ($raw.IndexOf("Cv2PortalsCurated", [StringComparison]::OrdinalIgnoreCase) -ge 0)
    $hasUR = ($raw.IndexOf("Cv2UniverseRail", [StringComparison]::OrdinalIgnoreCase) -ge 0)
    $hasMR = ($raw.IndexOf("Cv2MapRail", [StringComparison]::OrdinalIgnoreCase) -ge 0)
    $hasCore = ($raw.IndexOf("Cv2CoreNodes", [StringComparison]::OrdinalIgnoreCase) -ge 0) -or ($raw.IndexOf("V2CoreNodes", [StringComparison]::OrdinalIgnoreCase) -ge 0)
    $flags = @()
    if ($hasDoor) { $flags += "DoorGuide" }
    if ($hasPort) { $flags += "PortalsCurated" }
    if ($hasUR) { $flags += "UniverseRail" }
    if ($hasMR) { $flags += "MapRail" }
    if ($hasCore) { $flags += "CoreNodes" }
    if ($flags.Count -eq 0) { $flags = @("NONE") }
    $r.Add("- " + $rel) | Out-Null
    $r.Add("  - " + ($flags -join ", ")) | Out-Null
  }
}
$r.Add("") | Out-Null

# foco: mapa
$mapRel = "src\app\c\[slug]\v2\mapa\page.tsx"
$mapAbs = Join-Path $repoRoot $mapRel
$r.Add("## Foco Mapa (dashboard)") | Out-Null
$r.Add("") | Out-Null
if (-not (Test-Path -LiteralPath $mapAbs)) {
  $r.Add("[ERR] missing: " + $mapRel) | Out-Null
} else {
  $m = ReadText $mapAbs
  $checks = @(
    @{k="Cv2MapRail"; ok=($m.IndexOf("Cv2MapRail",[StringComparison]::OrdinalIgnoreCase)-ge 0)},
    @{k="Cv2DoorGuide"; ok=($m.IndexOf("Cv2DoorGuide",[StringComparison]::OrdinalIgnoreCase)-ge 0)},
    @{k="Cv2PortalsCurated"; ok=($m.IndexOf("Cv2PortalsCurated",[StringComparison]::OrdinalIgnoreCase)-ge 0)},
    @{k="CoreNodes"; ok=(($m.IndexOf("Cv2CoreNodes",[StringComparison]::OrdinalIgnoreCase)-ge 0) -or ($m.IndexOf("V2CoreNodes",[StringComparison]::OrdinalIgnoreCase)-ge 0))}
  )
  foreach ($c in $checks) { $r.Add("- " + $c.k + " : " + ($(if($c.ok){"YES"}else{"NO"}))) | Out-Null }
  $r.Add("") | Out-Null
  $r.Add("Sugestao: para Mapa virar painel central, ideal ter CoreNodes no topo + destaques + CTA 'proxima porta'.") | Out-Null
}
$r.Add("") | Out-Null

WriteText $rep ([string]::Join($nl, $r.ToArray()) + $nl)
Write-Host ("[REPORT] " + $rep)
Write-Host "[OK] B7L DIAG finalizado."