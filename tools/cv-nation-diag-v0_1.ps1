# cv-nation-diag-v0_1
$ErrorActionPreference = "Stop"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$repoRoot = (Resolve-Path ".").Path

function TryRun([string]$label, [scriptblock]$sb) {
  try {
    $out = & $sb 2>&1 | Out-String
    return @("## " + $label, "", $out.TrimEnd(), "")
  } catch {
    return @("## " + $label, "", ("[ERR] " + $_.Exception.Message), "")
  }
}

function HasFile([string]$rel) {
  return (Test-Path -LiteralPath (Join-Path $repoRoot $rel))
}

function ListFiles([string]$relDir, [string]$filter) {
  $abs = Join-Path $repoRoot $relDir
  if (-not (Test-Path -LiteralPath $abs)) { return @() }
  return (Get-ChildItem -LiteralPath $abs -Recurse -File -Filter $filter | ForEach-Object {
    $_.FullName.Substring($repoRoot.Length).TrimStart("\")
  })
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# Estado Geral da Nação — Cadernos Vivos — " + $stamp) | Out-Null
$lines.Add("") | Out-Null
$lines.Add("Repo: " + $repoRoot) | Out-Null
$lines.Add("") | Out-Null

# A) snapshot
$lines.AddRange((TryRun "Git status" { git status })) | Out-Null
$lines.AddRange((TryRun "Git branch" { git branch --show-current })) | Out-Null
$lines.AddRange((TryRun "Git log (10)" { git log -10 --oneline })) | Out-Null
$lines.AddRange((TryRun "Node/NPM versions" { node -v; npm -v })) | Out-Null

# B) V2 structure
$lines.Add("## V2 — Portas encontradas (src/app/c/[slug]/v2/**)") | Out-Null
$lines.Add("") | Out-Null
$v2Pages = ListFiles "src\app\c\[slug]\v2" "page.tsx"
if (-not $v2Pages -or $v2Pages.Count -eq 0) {
  $lines.Add("[WARN] Nenhuma page.tsx em src/app/c/[slug]/v2") | Out-Null
} else {
  foreach ($p in $v2Pages) { $lines.Add("- " + $p) | Out-Null }
}
$lines.Add("") | Out-Null

$lines.Add("## Componentes V2 — presença") | Out-Null
$lines.Add("") | Out-Null
$comps = @(
  "src\components\v2\V2Nav.tsx",
  "src\components\v2\V2QuickNav.tsx",
  "src\components\v2\V2Portals.tsx",
  "src\components\v2\Cv2DomFilterClient.tsx",
  "src\components\v2\Cv2MapRail.tsx",
  "src\components\v2\Cv2UniverseRail.tsx",
  "src\components\v2\Cv2MindmapHubClient.tsx"
)
foreach ($c in $comps) {
  $ok = HasFile $c
  $lines.Add(("- " + $c + " : " + ($(if($ok){"OK"}else{"MISSING"})))) | Out-Null
}
$lines.Add("") | Out-Null

# C) reports + backups
$lines.Add("## Reports recentes (top 12)") | Out-Null
$lines.Add("") | Out-Null
$repDir = Join-Path $repoRoot "reports"
if (Test-Path -LiteralPath $repDir) {
  Get-ChildItem -LiteralPath $repDir -File |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 12 |
    ForEach-Object { $lines.Add("- " + $_.Name) | Out-Null }
} else {
  $lines.Add("[WARN] sem reports/") | Out-Null
}
$lines.Add("") | Out-Null

$bkDir = Join-Path $repoRoot "tools\_patch_backup"
$lines.Add("## Backups recentes (tools/_patch_backup top 12)") | Out-Null
$lines.Add("") | Out-Null
if (Test-Path -LiteralPath $bkDir) {
  Get-ChildItem -LiteralPath $bkDir -File |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 12 |
    ForEach-Object { $lines.Add("- " + $_.Name) | Out-Null }
} else {
  $lines.Add("[WARN] sem tools/_patch_backup/") | Out-Null
}
$lines.Add("") | Out-Null

# D) verify (sem quebrar tudo se falhar)
$lines.AddRange((TryRun "cv-verify.ps1 (se existir)" {
  $v = Join-Path $repoRoot "tools\cv-verify.ps1"
  if (Test-Path -LiteralPath $v) { pwsh -NoProfile -ExecutionPolicy Bypass -File $v } else { "sem tools/cv-verify.ps1" }
})) | Out-Null

$lines.AddRange((TryRun "npm run lint" {
  $npm = (Get-Command npm.cmd -ErrorAction Stop).Path
  & $npm run lint
})) | Out-Null

$lines.AddRange((TryRun "npm run build" {
  $npm = (Get-Command npm.cmd -ErrorAction Stop).Path
  & $npm run build
})) | Out-Null

# write report
if (-not (Test-Path -LiteralPath $repDir)) { [IO.Directory]::CreateDirectory($repDir) | Out-Null }
$rep = Join-Path $repDir ($stamp + "-cv-nation-diag.md")
$enc = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($rep, ($lines -join "`n") + "`n", $enc)
Write-Host ("[REPORT] " + $rep)
Write-Host "[OK] Nação verificada."