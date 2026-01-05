$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Write-Host ("[DIAG] Repo: " + $repo)

. (Join-Path $PSScriptRoot "_bootstrap.ps1")

$changed = New-Object System.Collections.Generic.List[string]

function PatchText([string]$rel, [scriptblock]$mutate) {
  $full = Join-Path $repo $rel
  if (!(Test-Path -LiteralPath $full)) { throw ("[STOP] nao achei: " + $full) }
  $raw = Get-Content -LiteralPath $full -Raw
  if ($null -eq $raw) { throw ("[STOP] leitura nula: " + $full) }

  $next = & $mutate $raw
  if ($null -eq $next) { throw "[STOP] mutate retornou null" }

  if ($next -ne $raw) {
    $bk = BackupFile $full
    WriteUtf8NoBom $full $next
    Write-Host ("[OK] patched: " + $full)
    Write-Host ("[BK] " + $bk)
    $script:changed.Add($full) | Out-Null
  } else {
    Write-Host ("[OK] sem mudanca: " + $full)
  }
}

# Fix principal: replace(/^\\/+/, "")  -> replace(/^\/+/, "")
PatchText "src\components\v2\HomeV2Hub.tsx" {
  param($s)
  $out = $s

  # corrige todos os casos
  $out = $out.Replace('replace(/^\\/+/, "")', 'replace(/^\/+/, "")')
  $out = $out.Replace("replace(/^\\/+/, '')", "replace(/^\/+/, '')")

  # fallback: se tiver variação de espaço
  $out = [regex]::Replace($out, 'replace\(\s*/\^\\\\/\+\s*/\s*,', 'replace(/^\/+/,', "IgnoreCase")

  return $out
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Fix — HomeV2Hub regex (v0_82)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que foi corrigido") | Out-Null
$rep.Add("- Corrigiu regex literal em HomeV2Hub (replace /^\/+/) para parar o erro 'Unterminated regular expression literal'.") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null

$rp = WriteReport "cv-fix-homev2hub-regex-v0_82.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Fix aplicado e verificado."