# cv-step-b7b-core-nodes-diag-v0_2
$ErrorActionPreference = "Stop"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$repoRoot = (Resolve-Path ".").Path

function EnsureDir([string]$abs) {
  if (-not (Test-Path -LiteralPath $abs)) { [IO.Directory]::CreateDirectory($abs) | Out-Null }
}

function AddLines([System.Collections.Generic.List[string]]$list, [object]$block) {
  if ($null -eq $block) { return }
  foreach ($x in @($block)) { $list.Add([string]$x) | Out-Null }
}

function TryRun([string]$label, [scriptblock]$sb) {
  try {
    $out = & $sb 2>&1 | Out-String
    return @("## " + $label, "", $out.TrimEnd(), "")
  } catch {
    return @("## " + $label, "", ("[ERR] " + $_.Exception.Message), "")
  }
}

function GetSrcFiles([string]$relRoot) {
  $abs = Join-Path $repoRoot $relRoot
  if (-not (Test-Path -LiteralPath $abs)) { return @() }
  return Get-ChildItem -LiteralPath $abs -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object {
      $_.Extension -in @(".ts",".tsx",".js",".jsx",".md",".mdx",".json",".yml",".yaml")
    }
}

function GrepFiles([string]$title, [string]$relRoot, [string[]]$patterns) {
  $out = New-Object System.Collections.Generic.List[string]
  $out.Add("## " + $title) | Out-Null
  $out.Add("") | Out-Null

  $files = @(GetSrcFiles $relRoot)
  if (-not $files -or $files.Count -eq 0) {
    $out.Add("[WARN] Nenhum arquivo encontrado em: " + $relRoot) | Out-Null
    $out.Add("") | Out-Null
    return $out
  }

  foreach ($p in $patterns) {
    $out.Add("### Pattern: " + $p) | Out-Null
    $out.Add("") | Out-Null

    $hits = @()
    try {
      $hits = $files | Select-String -Pattern $p -ErrorAction SilentlyContinue
    } catch { $hits = @() }

    if (-not $hits -or $hits.Count -eq 0) {
      $out.Add("(sem hits)") | Out-Null
      $out.Add("") | Out-Null
      continue
    }

    $n = 0
    foreach ($h in $hits) {
      $n++
      if ($n -gt 140) { break }
      $rel = $h.Path.Substring($repoRoot.Length).TrimStart("\")
      $line = $h.Line
      if ($null -eq $line) { $line = "" }
      $out.Add(("- " + $rel + ":" + $h.LineNumber + "  " + ($line.Trim()))) | Out-Null
    }
    if ($hits.Count -gt 140) { $out.Add("... (truncado)") | Out-Null }
    $out.Add("") | Out-Null
  }

  return $out
}

EnsureDir (Join-Path $repoRoot "reports")
$rep = Join-Path $repoRoot ("reports\" + $stamp + "-cv-step-b7b-core-nodes-diag-v0_2.md")
$enc = New-Object System.Text.UTF8Encoding($false)
$r = New-Object System.Collections.Generic.List[string]

$r.Add("# Tijolo B7B — CoreNodes DIAG v0_2 (grep real) — " + $stamp) | Out-Null
$r.Add("") | Out-Null
$r.Add("Repo: " + $repoRoot) | Out-Null
$r.Add("") | Out-Null

AddLines $r (TryRun "Git status" { git status })
AddLines $r (TryRun "Git log (5)" { git log -5 --oneline })

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

AddLines $r (GrepFiles "CoreNodes: onde aparece" "src" @(
  "coreNodes",
  "CoreNodes",
  "Cv2CoreNodes",
  "V2CoreNodes"
))

AddLines $r (GrepFiles "Consumo: Portals / Rails / Mindmap" "src" @(
  "V2Portals",
  "Cv2MapRail",
  "Cv2UniverseRail",
  "Cv2MindmapHubClient",
  "V2QuickNav",
  "Cv2MapFirstCta"
))

AddLines $r (GrepFiles "Meta / data layer candidates" "src" @(
  "meta.ui.default",
  "uiDefault",
  "normalize",
  "frontmatter",
  "getCaderno",
  "loadCaderno",
  "caderno"
))

[IO.File]::WriteAllText($rep, ($r -join "`n") + "`n", $enc)
Write-Host ("[REPORT] " + $rep)
Write-Host "[OK] B7B DIAG v0_2 gerado."