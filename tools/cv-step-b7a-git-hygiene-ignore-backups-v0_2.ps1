# cv-step-b7a-git-hygiene-ignore-backups-v0_2
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
  foreach ($x in @($block)) {
    $list.Add([string]$x) | Out-Null
  }
}

# Ensure dirs
$reportsDir = Join-Path $repoRoot "reports"
EnsureDir $reportsDir
EnsureDir (Join-Path $repoRoot "tools\_patch_backup")

# PATCH: .gitignore ignore tools/_patch_backup
$gi = Join-Path $repoRoot ".gitignore"
$enc = New-Object System.Text.UTF8Encoding($false)

if (Test-Path -LiteralPath $gi) {
  $bk = Join-Path $repoRoot ("tools\_patch_backup\" + $stamp + "-.gitignore.bak")
  Copy-Item -LiteralPath $gi -Destination $bk -Force
}

$lines = @()
if (Test-Path -LiteralPath $gi) { $lines = Get-Content -LiteralPath $gi }

$marker = "# Cadernos Vivos — local patch backups"
$hasMarker = $false
foreach ($l in $lines) { if ($l -eq $marker) { $hasMarker = $true } }

if (-not $hasMarker) {
  $lines = @($lines + @(
    "",
    $marker,
    "tools/_patch_backup/",
    ""
  ))
  [IO.File]::WriteAllText($gi, ($lines -join "`n") + "`n", $enc)
}

# REPORT
$rep = Join-Path $repoRoot ("reports\" + $stamp + "-cv-step-b7a-git-hygiene.md")
$r = New-Object System.Collections.Generic.List[string]
$r.Add("# Tijolo B7A — Git hygiene + ignore backups — " + $stamp) | Out-Null
$r.Add("") | Out-Null
$r.Add("Repo: " + $repoRoot) | Out-Null
$r.Add("") | Out-Null

AddLines $r (TryRun "Git status" { git status })
AddLines $r (TryRun "Git diff --stat" { git diff --stat })

$r.Add("## Patch aplicado") | Out-Null
$r.Add("") | Out-Null
$r.Add("- .gitignore: garantido ignore de tools/_patch_backup/") | Out-Null
$r.Add("") | Out-Null

AddLines $r (TryRun "cv-verify.ps1 (se existir)" {
  $v = Join-Path $repoRoot "tools\cv-verify.ps1"
  if (Test-Path -LiteralPath $v) { pwsh -NoProfile -ExecutionPolicy Bypass -File $v } else { "sem tools/cv-verify.ps1" }
})

AddLines $r (TryRun "npm run lint" {
  $npm = (Get-Command npm.cmd -ErrorAction Stop).Path
  & $npm run lint
})

AddLines $r (TryRun "npm run build" {
  $npm = (Get-Command npm.cmd -ErrorAction Stop).Path
  & $npm run build
})

$r.Add("## Próximo passo (manual)") | Out-Null
$r.Add("") | Out-Null
$r.Add("Sugestão de staging (sem backups):") | Out-Null
$r.Add("  git add -A src tools reports .gitignore") | Out-Null
$r.Add("") | Out-Null
$r.Add("Sugestão de commit:") | Out-Null
$r.Add('  git commit -m "chore(cv): V2 Concreto Zen (map-first + portais + rails + core nodes)"') | Out-Null
$r.Add("") | Out-Null

[IO.File]::WriteAllText($rep, ($r -join "`n") + "`n", $enc)
Write-Host ("[REPORT] " + $rep)
Write-Host "[OK] Tijolo B7A v0_2 finalizado."