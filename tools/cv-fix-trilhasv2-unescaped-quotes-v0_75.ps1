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

$rel = "src\components\v2\TrilhasV2.tsx"

PatchText $rel {
  param($raw)
  $s = $raw

  # Corrige o texto: type: "trail" -> type: &quot;trail&quot;
  $s = $s.Replace('type: "trail"', 'type: &quot;trail&quot;')

  return $s
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Fix — TrilhasV2 escapar aspas (v0_75)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que foi corrigido") | Out-Null
$rep.Add("- TrilhasV2: texto JSX agora usa &quot;trail&quot; para evitar react/no-unescaped-entities.") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null

$rp = WriteReport "cv-fix-trilhasv2-unescaped-quotes-v0_75.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Fix aplicado e verificado."