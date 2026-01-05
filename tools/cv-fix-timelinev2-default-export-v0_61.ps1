$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Write-Host ("[DIAG] Repo: " + $repo)

. (Join-Path $PSScriptRoot "_bootstrap.ps1")

$changed = New-Object System.Collections.Generic.List[string]

function PatchAppend([string]$rel, [string]$appendIfMissing, [string]$mustContain) {
  $full = Join-Path $repo $rel
  if (!(Test-Path -LiteralPath $full)) { throw ("[STOP] nao achei: " + $full) }
  $raw = Get-Content -LiteralPath $full -Raw
  if ($null -eq $raw) { throw ("[STOP] leitura nula: " + $full) }

  if ($raw.Contains($mustContain)) {
    Write-Host ("[OK] ja contem: " + $mustContain)
    return
  }

  $bk = BackupFile $full
  $raw2 = $raw.TrimEnd() + "`r`n`r`n" + $appendIfMissing + "`r`n"
  WriteUtf8NoBom $full $raw2
  Write-Host ("[OK] patched: " + $full)
  Write-Host ("[BK] " + $bk)
  $script:changed.Add($full) | Out-Null
}

# 1) Patch TimelineV2 default export
PatchAppend "src\components\v2\TimelineV2.tsx" "export default TimelineV2;" "export default TimelineV2"

# 2) VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# 3) REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Fix — TimelineV2 default export (v0_61)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que foi corrigido") | Out-Null
$rep.Add("- Adicionado export default TimelineV2 para compatibilidade com imports default existentes (ex.: /v2/linha).") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null

$rp = WriteReport "cv-fix-timelinev2-default-export-v0_61.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Fix aplicado e verificado."