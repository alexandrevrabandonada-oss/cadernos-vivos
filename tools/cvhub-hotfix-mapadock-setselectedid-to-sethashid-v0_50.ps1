$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Write-Host ("[DIAG] Repo: " + $repo)

. (Join-Path $PSScriptRoot "_bootstrap.ps1")

$file = Join-Path $repo "src\components\v2\MapaDockV2.tsx"
if (-not (Test-Path -LiteralPath $file)) { throw ("[STOP] nao achei: " + $file) }
Write-Host ("[DIAG] File: " + $file)

$raw = Get-Content -LiteralPath $file -Raw

$cnt = ([regex]::Matches($raw, '\bsetSelectedId\b')).Count
Write-Host ("[DIAG] setSelectedId refs: " + $cnt)

if ($cnt -eq 0) {
  Write-Host "[OK] nada pra mudar (nao existe setSelectedId)."
} else {
  $bk = BackupFile $file

  # troca somente o identificador (evita mexer em outras strings)
  $newRaw = [regex]::Replace($raw, '\bsetSelectedId\b', 'setHashId')

  WriteUtf8NoBom $file $newRaw
  Write-Host ("[OK] patched: " + $file)
  if ($bk) { Write-Host ("[BK] " + $bk) }
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = @()
$rep += "# CV — Hotfix v0_50 — MapaDockV2 setSelectedId para setHashId"
$rep += ""
$rep += "## Causa"
$rep += "- MapaDockV2 chamava setSelectedId, mas o state setter nao existe mais (migrou para hash store)."
$rep += ""
$rep += "## Fix"
$rep += "- Substitui setSelectedId por setHashId (padrao hash focus)."
$rep += ""
$rep += "## Arquivo"
$rep += "- src/components/v2/MapaDockV2.tsx"
$rep += ""
$rep += "## Verify"
$rep += "- tools/cv-verify.ps1 (guard + lint + build)"
$rep += ""

$rp = WriteReport "cv-hotfix-mapadock-setselectedid-to-sethashid-v0_50.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Hotfix v0_50 aplicado e verificado."