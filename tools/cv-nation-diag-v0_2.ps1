# cv-nation-diag-v0_2
$ErrorActionPreference = "Stop"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$repoRoot = (Resolve-Path ".").Path

$lines = New-Object System.Collections.Generic.List[string]

function AddLine([string]$s) { [void]$lines.Add($s) }
function AddLines($items) {
  foreach ($it in @($items)) { [void]$lines.Add([string]$it) }
}

function TryRun([string]$label, [scriptblock]$sb) {
  try {
    $out = (& $sb 2>&1 | Out-String)
    return @(
      "## " + $label,
      "",
      $out.TrimEnd(),
      ""
    )
  } catch {
    return @(
      "## " + $label,
      "",
      ("[ERR] " + $_.Exception.Message),
      ""
    )
  }
}

function HasFile([string]$rel) {
  return (Test-Path -LiteralPath (Join-Path $repoRoot $rel))
}

function ListFiles([string]$relDir, [string]$filter) {
  $abs = Join-Path $repoRoot $relDir
  if (-not (Test-Path -LiteralPath $abs)) { return @() }
  return @(
    Get-ChildItem -LiteralPath $abs -Recurse -File -Filter $filter |
      ForEach-Object { $_.FullName.Substring($repoRoot.Length).TrimStart("\") }
  )
}

AddLine ("# Estado Geral da Nação — Cadernos Vivos — " + $stamp)
AddLine ""
AddLine ("Repo: " + $repoRoot)
AddLine ""

# A) snapshot
AddLines (TryRun "Git status (porcelain + branch)" { git status --porcelain=v1 -b })
AddLines (TryRun "Git status (completo)" { git status })
AddLines (TryRun "Git branch" { git branch --show-current })
AddLines (TryRun "Git log (10)" { git log -10 --oneline })
AddLines (TryRun "Node/NPM versions" { node -v; npm -v })

# B) V2 structure
AddLine "## V2 — Portas encontradas (src/app/c/[slug]/v2/**)"
AddLine ""
$v2Pages = @(ListFiles "src\app\c\[slug]\v2" "page.tsx")
if (-not $v2Pages -or $v2Pages.Count -eq 0) {
  AddLine "[WARN] Nenhuma page.tsx em src/app/c/[slug]/v2"
} else {
  foreach ($p in $v2Pages) { AddLine ("- " + $p) }
}
AddLine ""

AddLine "## Componentes V2 — presença"
AddLine ""
$comps = @(
  "src\components\v2\V2Nav.tsx",
  "src\components\v2\V2QuickNav.tsx",
  "src\components\v2\V2Portals.tsx",
  "src\components\v2\Cv2DomFilterClient.tsx",
  "src\components\v2\Cv2MapRail.tsx",
  "src\components\v2\Cv2UniverseRail.tsx",
  "src\components\v2\Cv2MindmapHubClient.tsx",
  "src\components\v2\Cv2CoreNodes.tsx",
  "src\components\v2\Cv2MapFirstCta.tsx",
  "src\components\v2\ShellV2.tsx"
)
foreach ($c in $comps) {
  $ok = HasFile $c
  AddLine ("- " + $c + " : " + ($(if($ok){"OK"}else{"MISSING"})))
}
AddLine ""

# C) reports + backups
AddLine "## Reports recentes (top 15)"
AddLine ""
$repDir = Join-Path $repoRoot "reports"
if (Test-Path -LiteralPath $repDir) {
  Get-ChildItem -LiteralPath $repDir -File |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 15 |
    ForEach-Object { AddLine ("- " + $_.Name) }
} else {
  AddLine "[WARN] sem reports/"
}
AddLine ""

$bkDir = Join-Path $repoRoot "tools\_patch_backup"
AddLine "## Backups recentes (tools/_patch_backup top 15)"
AddLine ""
if (Test-Path -LiteralPath $bkDir) {
  Get-ChildItem -LiteralPath $bkDir -File |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 15 |
    ForEach-Object { AddLine ("- " + $_.Name) }
} else {
  AddLine "[WARN] sem tools/_patch_backup/"
}
AddLine ""

# D) verify
AddLines (TryRun "cv-verify.ps1 (se existir)" {
  $v = Join-Path $repoRoot "tools\cv-verify.ps1"
  if (Test-Path -LiteralPath $v) {
    pwsh -NoProfile -ExecutionPolicy Bypass -File $v
  } else {
    "sem tools/cv-verify.ps1"
  }
})

AddLines (TryRun "npm run lint" {
  $npm = (Get-Command npm.cmd -ErrorAction Stop).Path
  & $npm run lint
})

AddLines (TryRun "npm run build" {
  $npm = (Get-Command npm.cmd -ErrorAction Stop).Path
  & $npm run build
})

# write report
if (-not (Test-Path -LiteralPath $repDir)) { [IO.Directory]::CreateDirectory($repDir) | Out-Null }
$rep = Join-Path $repDir ($stamp + "-cv-nation-diag.md")
$enc = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($rep, ($lines -join "`n") + "`n", $enc)

Write-Host ("[REPORT] " + $rep)
Write-Host "[OK] Nação verificada (v0_2)."