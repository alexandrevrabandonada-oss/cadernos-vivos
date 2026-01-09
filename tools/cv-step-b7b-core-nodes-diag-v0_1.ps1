# cv-step-b7b-core-nodes-diag-v0_1
$ErrorActionPreference = "Stop"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$repoRoot = (Resolve-Path ".").Path

function EnsureDir([string]$abs) {
  if (-not (Test-Path -LiteralPath $abs)) { [IO.Directory]::CreateDirectory($abs) | Out-Null }
}

function TryRun([string]$label, [scriptblock]$sb) {
  try {
    $out = & $sb 2>&1 | Out-String
    return @("## " + $label, "", $out.TrimEnd(), "")
  } catch {
    return @("## " + $label, "", ("[ERR] " + $_.Exception.Message), "")
  }
}

function AddLines([System.Collections.Generic.List[string]]$list, [object]$block) {
  if ($null -eq $block) { return }
  foreach ($x in @($block)) { $list.Add([string]$x) | Out-Null }
}

function Grep([string]$title, [string]$relRoot, [string[]]$patterns) {
  $abs = Join-Path $repoRoot $relRoot
  $out = New-Object System.Collections.Generic.List[string]
  $out.Add("## " + $title) | Out-Null
  $out.Add("") | Out-Null
  if (-not (Test-Path -LiteralPath $abs)) {
    $out.Add("[WARN] Pasta não existe: " + $relRoot) | Out-Null
    $out.Add("") | Out-Null
    return $out
  }
  foreach ($p in $patterns) {
    $out.Add("### Pattern: " + $p) | Out-Null
    $out.Add("") | Out-Null
    $hits = @()
    try {
      $hits = Select-String -LiteralPath $abs -Recurse -File -Pattern $p -ErrorAction SilentlyContinue
    } catch { $hits = @() }
    if (-not $hits -or $hits.Count -eq 0) {
      $out.Add("(sem hits)") | Out-Null
      $out.Add("") | Out-Null
      continue
    }
    foreach ($h in ($hits | Select-Object -First 120)) {
      $rel = $h.Path.Substring($repoRoot.Length).TrimStart("\")
      $out.Add(("- " + $rel + ":" + $h.LineNumber + "  " + ($h.Line.Trim()))) | Out-Null
    }
    if ($hits.Count -gt 120) { $out.Add("... (truncado)") | Out-Null }
    $out.Add("") | Out-Null
  }
  return $out
}

# report
EnsureDir (Join-Path $repoRoot "reports")
$rep = Join-Path $repoRoot ("reports\" + $stamp + "-cv-step-b7b-core-nodes-diag.md")
$enc = New-Object System.Text.UTF8Encoding($false)
$r = New-Object System.Collections.Generic.List[string]

$r.Add("# Tijolo B7B — CoreNodes DIAG (fonte única) — " + $stamp) | Out-Null
$r.Add("") | Out-Null
$r.Add("Repo: " + $repoRoot) | Out-Null
$r.Add("") | Out-Null

AddLines $r (TryRun "Git status" { git status })
AddLines $r (TryRun "Git diff --stat" { git diff --stat })

$r.Add("## Inventário rápido — V2 pages") | Out-Null
$r.Add("") | Out-Null
$v2dir = Join-Path $repoRoot "src\app\c\[slug]\v2"
if (Test-Path -LiteralPath $v2dir) {
  Get-ChildItem -LiteralPath $v2dir -Recurse -File -Filter "page.tsx" |
    ForEach-Object { $r.Add("- " + $_.FullName.Substring($repoRoot.Length).TrimStart("\")) | Out-Null }
} else {
  $r.Add("[WARN] sem src/app/c/[slug]/v2") | Out-Null
}
$r.Add("") | Out-Null

$r.Add("## Inventário rápido — components/v2") | Out-Null
$r.Add("") | Out-Null
$cmpdir = Join-Path $repoRoot "src\components\v2"
if (Test-Path -LiteralPath $cmpdir) {
  Get-ChildItem -LiteralPath $cmpdir -File -Filter "*.tsx" |
    Sort-Object Name |
    ForEach-Object { $r.Add("- " + $_.Name) | Out-Null }
} else {
  $r.Add("[WARN] sem src/components/v2") | Out-Null
}
$r.Add("") | Out-Null

AddLines $r (Grep "Onde coreNodes aparece (src)" "src" @("coreNodes", "Cv2CoreNodes", "V2CoreNodes"))
AddLines $r (Grep "Quem consome (Portals/Rails/Mindmap)" "src" @("V2Portals", "Cv2MapRail", "Cv2UniverseRail", "Cv2MindmapHubClient", "V2QuickNav", "MapFirstCta"))
AddLines $r (Grep "Meta/normalize candidates" "src" @("meta.ui.default", "uiDefault", "normalize", "caderno", "frontmatter"))

[IO.File]::WriteAllText($rep, ($r -join "`n") + "`n", $enc)
Write-Host ("[REPORT] " + $rep)
Write-Host "[OK] B7B DIAG gerado."