# cv-hotfix-b6w2-fix-rail-eslint-and-runnpm-v0_1
$ErrorActionPreference = "Stop"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Write-Host ("== cv-hotfix-b6w2-fix-rail-eslint-and-runnpm-v0_1 == " + $stamp)

$repoRoot = (Resolve-Path ".").Path

# bootstrap
$boot = Join-Path $repoRoot "tools\_bootstrap.ps1"
if (Test-Path -LiteralPath $boot) {
  . $boot
} else {
  function EnsureDir([string]$p){ [IO.Directory]::CreateDirectory($p) | Out-Null }
  function WriteUtf8NoBom([string]$p,[string]$c){ $enc=New-Object System.Text.UTF8Encoding($false); [IO.File]::WriteAllText($p,$c,$enc) }
  function BackupFile([string]$p){
    $bkDir = Join-Path $repoRoot "tools\_patch_backup"
    EnsureDir $bkDir
    $leaf = Split-Path -Leaf $p
    $dest = Join-Path $bkDir ($stamp + "-" + $leaf + ".bak")
    Copy-Item -LiteralPath $p -Destination $dest -Force
    return $dest
  }
}

function RunNpm([string[]]$npmArgs) {
  $npm = (Get-Command npm.cmd -ErrorAction Stop).Path
  $out = (& $npm @npmArgs 2>&1 | Out-String)
  return @{ out=$out; code=$LASTEXITCODE }
}

Write-Host ("[DIAG] Repo: " + $repoRoot)

# ------------------------------------------------------------
# PATCH 1: remove eslint-disable unused in Cv2MapRail.tsx
# ------------------------------------------------------------
$rail = Join-Path $repoRoot "src\components\v2\Cv2MapRail.tsx"
if (Test-Path -LiteralPath $rail) {
  $raw = Get-Content -LiteralPath $rail -Raw
  if (-not $raw) { throw "[STOP] Cv2MapRail.tsx vazio" }

  # remove linhas com eslint-disable de no-unused-vars (as que geram warning de "Unused eslint-disable directive")
  $lines = $raw -split "`r?`n"
  $new = New-Object System.Collections.Generic.List[string]
  $removed = 0
  foreach ($ln in $lines) {
    $isDisable = ($ln -match "eslint-disable") -and ($ln -match "no-unused-vars")
    if ($isDisable) { $removed++; continue }
    $new.Add($ln) | Out-Null
  }

  if ($removed -gt 0) {
    $bk = BackupFile $rail
    Write-Host ("[BK]    tools/_patch_backup/" + (Split-Path -Leaf $bk))
    WriteUtf8NoBom $rail (($new -join "`n").TrimEnd() + "`n")
    Write-Host "[PATCH] src/components/v2/Cv2MapRail.tsx (removed unused eslint-disable)"
  } else {
    Write-Host "[SKIP] Cv2MapRail.tsx não tinha eslint-disable no-unused-vars"
  }
} else {
  Write-Host "[SKIP] não achei Cv2MapRail.tsx"
}

# ------------------------------------------------------------
# PATCH 2: fix RunNpm in the B6W script (avoid 'npm help' issue)
# ------------------------------------------------------------
$b6w = Join-Path $repoRoot "tools\cv-step-b6w-v2-portals-everywhere-v0_2.ps1"
if (Test-Path -LiteralPath $b6w) {
  $raw = Get-Content -LiteralPath $b6w -Raw
  if (-not $raw) { throw "[STOP] b6w v0_2 vazio" }

  $raw2 = $raw

  # rename param + splat variable
  $raw2 = $raw2 -replace "function\s+RunNpm\(\[string\[\]\]\`$args\)", "function RunNpm([string[]]`$npmArgs)"
  $raw2 = $raw2 -replace "\&\s*\`$npm\s+\@args", "& `$npm @npmArgs"

  # also fix any calls that used RunNpm @("run","lint") etc — this is fine, but keep as-is.
  if ($raw2 -ne $raw) {
    $bk = BackupFile $b6w
    Write-Host ("[BK]    tools/_patch_backup/" + (Split-Path -Leaf $bk))
    WriteUtf8NoBom $b6w ($raw2.TrimEnd() + "`n")
    Write-Host "[PATCH] tools/cv-step-b6w-v2-portals-everywhere-v0_2.ps1 (RunNpm fix)"
  } else {
    Write-Host "[SKIP] b6w v0_2 já parecia ok (nenhuma troca aplicada)"
  }
} else {
  Write-Host "[SKIP] não achei tools/cv-step-b6w-v2-portals-everywhere-v0_2.ps1"
}

# ------------------------------------------------------------
# VERIFY
# ------------------------------------------------------------
$verify = Join-Path $repoRoot "tools\cv-verify.ps1"
if (Test-Path -LiteralPath $verify) {
  Write-Host ("[RUN] " + $verify)
  & $verify
  if ($LASTEXITCODE -ne 0) { throw ("[STOP] cv-verify falhou (exit=" + $LASTEXITCODE + ")") }
}

Write-Host "[RUN] npm run lint"
$r1 = RunNpm @("run","lint")
Write-Host $r1.out
if ($r1.code -ne 0) { throw ("[STOP] lint falhou (exit=" + $r1.code + ")") }

Write-Host "[RUN] npm run build"
$r2 = RunNpm @("run","build")
Write-Host $r2.out
if ($r2.code -ne 0) { throw ("[STOP] build falhou (exit=" + $r2.code + ")") }

# ------------------------------------------------------------
# REPORT
# ------------------------------------------------------------
$repDir = Join-Path $repoRoot "reports"
EnsureDir $repDir
$rep = Join-Path $repDir ($stamp + "-cv-hotfix-b6w2-fix-rail-eslint-and-runnpm.md")

$body = @(
("# CV HOTFIX B6W2 — fix rail eslint-disable + RunNpm — " + $stamp),
"",
("Repo: " + $repoRoot),
"",
"## PATCH",
"- Cv2MapRail.tsx: remove eslint-disable no-unused-vars (era warning virando exit 1)",
"- b6w v0_2: RunNpm param/splat corrigido (evita npm help)",
"",
"## VERIFY",
("- lint: " + $r1.code),
("- build: " + $r2.code)
) -join "`n"

WriteUtf8NoBom $rep $body
Write-Host ("[REPORT] reports/" + (Split-Path -Leaf $rep))
Write-Host "[OK] HOTFIX B6W2 concluído (lint/build ok)."