# cv-hotfix-b7i2-verify-npmcmd-and-portals-diag-v0_1
# DIAG: presença Cv2PortalsCurated nas pages V2
# VERIFY: npm run lint/build usando npm.cmd (não npm.ps1 cmd)
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

function FindNpmCmd() {
  # Preferir npm.cmd no Windows
  foreach ($name in @("npm.cmd","npm.exe")) {
    try {
      $p = (Get-Command $name -ErrorAction Stop).Path
      if ($p) { return $p }
    } catch {}
  }
  # fallback: npm (pode virar npm.ps1) — se for ps1, tenta achar npm.cmd na mesma pasta
  try {
    $p = (Get-Command npm -ErrorAction Stop).Path
    if ($p) {
      $lp = $p.ToLowerInvariant()
      if ($lp.EndsWith("\npm.ps1")) {
        $cand = Join-Path (Split-Path -Parent $p) "npm.cmd"
        if (Test-Path -LiteralPath $cand) { return $cand }
        $cand2 = Join-Path (Split-Path -Parent $p) "npm.exe"
        if (Test-Path -LiteralPath $cand2) { return $cand2 }
      }
      return $p
    }
  } catch {}
  return $null
}

function RunNpm([string[]]$argv) {
  $npmCmd = FindNpmCmd
  if (-not $npmCmd) { throw "npm não encontrado no PATH" }
  Write-Host ("[RUN] " + $npmCmd + " " + ($argv -join " "))
  & $npmCmd @argv
  if ($LASTEXITCODE -ne 0) { throw ("npm failed: " + ($argv -join " ")) }
}

EnsureDir (Join-Path $repoRoot "reports")
$rep = Join-Path $repoRoot ("reports\" + $stamp + "-cv-hotfix-b7i2-verify-npmcmd-and-portals-diag.md")
$r = New-Object System.Collections.Generic.List[string]
$r.Add("# Hotfix B7I2 — verify npm.cmd + diag portais — " + $stamp) | Out-Null
$r.Add("") | Out-Null
$r.Add("Repo: " + $repoRoot) | Out-Null
$r.Add("") | Out-Null

$r.Add("## DIAG — Git status") | Out-Null
$r.Add("") | Out-Null
try { $r.Add((git status | Out-String).TrimEnd()) | Out-Null } catch { $r.Add("ERR: git status") | Out-Null }
$r.Add("") | Out-Null

# DIAG Portals
$portalsRel = "src\components\v2\Cv2PortalsCurated.tsx"
$portalsAbs = Join-Path $repoRoot $portalsRel
$r.Add("## DIAG — Cv2PortalsCurated existe?") | Out-Null
$r.Add("") | Out-Null
$r.Add("- " + $portalsRel + " : " + ($(if(Test-Path -LiteralPath $portalsAbs){"OK"}else{"MISSING"}))) | Out-Null
$r.Add("") | Out-Null

$v2Dir = Join-Path $repoRoot "src\app\c\[slug]\v2"
$r.Add("## DIAG — Pages V2 e uso de portais") | Out-Null
$r.Add("") | Out-Null
if (-not (Test-Path -LiteralPath $v2Dir)) {
  $r.Add("[ERR] missing: src/app/c/[slug]/v2") | Out-Null
} else {
  $pages = Get-ChildItem -LiteralPath $v2Dir -Recurse -File -Filter "page.tsx"
  foreach ($p in $pages) {
    $raw = ReadText $p.FullName
    if ($null -eq $raw) { continue }
    $rel = $p.FullName.Substring($repoRoot.Length).TrimStart("\")
    $hasCur = ($raw.IndexOf("Cv2PortalsCurated", [StringComparison]::OrdinalIgnoreCase) -ge 0)
    $hasV2p = ($raw.IndexOf("V2Portals", [StringComparison]::OrdinalIgnoreCase) -ge 0) -or ($raw.IndexOf("PortaisV2", [StringComparison]::OrdinalIgnoreCase) -ge 0)
    $mark = $(if($hasCur){"CURATED"}elseif($hasV2p){"LEGACY"}else{"NONE"})
    $r.Add("- " + $mark + " : " + $rel) | Out-Null
  }
}
$r.Add("") | Out-Null

# VERIFY
$r.Add("## VERIFY") | Out-Null
$r.Add("") | Out-Null

$failed = $false
try { RunNpm @("run","lint"); $r.Add("- npm run lint: OK") | Out-Null } catch { $failed = $true; $r.Add("- npm run lint: FAIL") | Out-Null; $r.Add("  " + $_.Exception.Message) | Out-Null }
try { RunNpm @("run","build"); $r.Add("- npm run build: OK") | Out-Null } catch { $failed = $true; $r.Add("- npm run build: FAIL") | Out-Null; $r.Add("  " + $_.Exception.Message) | Out-Null }

$r.Add("") | Out-Null
$r.Add("## Próximo tijolo sugerido") | Out-Null
$r.Add("") | Out-Null
$r.Add("- Se houver páginas LEGACY/NONE: rodar B7I v0_2 com npm.cmd corrigido (eu te solto o tijolo que patcha tudo).") | Out-Null
$r.Add("- Se tudo CURATED: próximo é “Portais + DoorGuide” afinado por núcleo (microcopy e ordem) e depois commit limpo.") | Out-Null
$r.Add("") | Out-Null

WriteText $rep ([string]::Join($nl, $r.ToArray()) + $nl)
Write-Host ("[REPORT] " + $rep)
if ($failed) { throw "B7I2: verify failed (see report)." }
Write-Host "[OK] B7I2 finalizado."