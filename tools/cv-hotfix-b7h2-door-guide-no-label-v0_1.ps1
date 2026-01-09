# cv-hotfix-b7h2-door-guide-no-label-v0_1
$ErrorActionPreference = "Stop"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$repoRoot = (Resolve-Path ".").Path
$nl = [Environment]::NewLine

function EnsureDir([string]$abs) { if (-not (Test-Path -LiteralPath $abs)) { [IO.Directory]::CreateDirectory($abs) | Out-Null } }
function ReadText([string]$abs) { if (-not (Test-Path -LiteralPath $abs)) { return $null }; return [IO.File]::ReadAllText($abs) }
function WriteText([string]$abs, [string]$text) { $enc = New-Object System.Text.UTF8Encoding($false); EnsureDir (Split-Path -Parent $abs); [IO.File]::WriteAllText($abs, $text, $enc) }
function BackupFile([string]$rel) {
  $abs = Join-Path $repoRoot $rel
  if (-not (Test-Path -LiteralPath $abs)) { return }
  $bkDir = Join-Path $repoRoot "tools\_patch_backup"
  EnsureDir $bkDir
  $dst = Join-Path $bkDir ($stamp + "-" + (Split-Path -Leaf $abs) + ".bak")
  Copy-Item -LiteralPath $abs -Destination $dst -Force
}
function TryRun([string]$label, [scriptblock]$sb) {
  try { $out = & $sb 2>&1 | Out-String; return @("## " + $label, "", $out.TrimEnd(), "") }
  catch { return @("## " + $label, "", ("ERR: " + $_.Exception.Message), "") }
}
function AddLines([System.Collections.Generic.List[string]]$list, [object]$block) {
  if ($null -eq $block) { return }
  foreach ($x in @($block)) { $list.Add([string]$x) | Out-Null }
}

EnsureDir (Join-Path $repoRoot "reports")
EnsureDir (Join-Path $repoRoot "tools\_patch_backup")

$rep = Join-Path $repoRoot ("reports\" + $stamp + "-cv-hotfix-b7h2-door-guide-no-label.md")
$r = New-Object System.Collections.Generic.List[string]
$r.Add("# Hotfix B7H2 — Cv2DoorGuide sem d.label — " + $stamp) | Out-Null
$r.Add("") | Out-Null
$r.Add("Repo: " + $repoRoot) | Out-Null
$r.Add("") | Out-Null

AddLines $r (TryRun "Git status (pre)" { git status })

$rel = "src\components\v2\Cv2DoorGuide.tsx"
$abs = Join-Path $repoRoot $rel
if (-not (Test-Path -LiteralPath $abs)) { throw ("Missing: " + $rel) }

$raw = ReadText $abs
if ($null -eq $raw) { throw ("Empty: " + $rel) }

$r.Add("## DIAG") | Out-Null
$r.Add("") | Out-Null
$r.Add("- has_d_label: " + ($raw.Contains("d.label"))) | Out-Null
$r.Add("") | Out-Null

BackupFile $rel

$patched = $raw

# troca direta do return problemático (mais comum)
$patched = $patched.Replace('return (d.label ? d.label : (d.title ? d.title : id));', 'return (d.title ? d.title : id);')

# fallback: remove qualquer "d.label ? d.label : " que tenha sobrado
if ($patched.Contains("d.label")) {
  $patched = $patched.Replace('return (d.label ? d.label : (d.title ? d.title : id));', 'return (d.title ? d.title : id);')
  $patched = $patched.Replace('(d.label ? d.label : (d.title ? d.title : id))', '(d.title ? d.title : id)')
}

if ($patched -eq $raw) {
  $r.Add("## Patch") | Out-Null
  $r.Add("- WARN: nenhum replace aplicado (formato diferente do esperado).") | Out-Null
  $r.Add("") | Out-Null
} else {
  WriteText $abs ($patched.TrimEnd() + $nl)
  $r.Add("## Patch") | Out-Null
  $r.Add("- updated: " + $rel + " (labelOf usa só title)") | Out-Null
  $r.Add("") | Out-Null
}

AddLines $r (TryRun "npm run lint" {
  $npm = (Get-Command npm.cmd -ErrorAction Stop).Path
  & $npm run lint
})
AddLines $r (TryRun "npm run build" {
  $npm = (Get-Command npm.cmd -ErrorAction Stop).Path
  & $npm run build
})
AddLines $r (TryRun "Git status (post)" { git status })

WriteText $rep ([string]::Join($nl, $r.ToArray()) + $nl)
Write-Host ("[REPORT] " + $rep)
Write-Host "[OK] Hotfix B7H2 finalizado."