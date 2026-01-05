$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Write-Host ("[DIAG] Repo: " + $repo)

. (Join-Path $PSScriptRoot "_bootstrap.ps1")

$changed = New-Object System.Collections.Generic.List[string]

function PatchText([string]$rel, [scriptblock]$mutate) {
  $fp = Join-Path $repo $rel
  if (!(Test-Path -LiteralPath $fp)) {
    Write-Host ("[SKIP] nao achei: " + $fp)
    return
  }
  $raw = Get-Content -LiteralPath $fp -Raw
  if ($null -eq $raw) { throw ("[STOP] leitura nula: " + $fp) }

  $next = & $mutate $raw
  if ($null -eq $next) { throw "[STOP] mutate retornou null" }

  if ($next -ne $raw) {
    $bk = BackupFile $fp
    WriteUtf8NoBom $fp $next
    Write-Host ("[OK] patched: " + $fp)
    Write-Host ("[BK] " + $bk)
    $script:changed.Add($fp) | Out-Null
  } else {
    Write-Host ("[OK] sem mudanca: " + $fp)
  }
}

# Remove duplicatas do tipo: prop={...} prop={...} e prop="..." prop="..."
function RemoveDupProp([string]$text, [string]$prop) {
  $out = $text

  # prop={...} prop={...}
  $rx1 = '(\s' + $prop + '=\{[^}]*\})\s+' + $prop + '=\{[^}]*\}'
  do {
    $prev = $out
    $out = [regex]::Replace($out, $rx1, '$1')
  } while ($out -ne $prev)

  # prop="..." prop="..."
  $rx2 = '(\s' + $prop + '="[^"]*")\s+' + $prop + '="[^"]*"'
  do {
    $prev = $out
    $out = [regex]::Replace($out, $rx2, '$1')
  } while ($out -ne $prev)

  return $out
}

PatchText 'src\components\v2\MapaV2Interactive.tsx' {
  param($s)
  $out = $s

  foreach ($p in @('mapa','slug','title')) {
    $out = RemoveDupProp $out $p
  }

  return $out
}

# VERIFY
$verify = Join-Path $repo 'tools\cv-verify.ps1'
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add('# CV — FIX — MapaV2Interactive sem props duplicadas (v0_121)') | Out-Null
$rep.Add('') | Out-Null
$rep.Add('## O que foi corrigido') | Out-Null
$rep.Add('- Remove props duplicadas em JSX (mapa/slug/title) no MapaV2Interactive.tsx para passar eslint react/jsx-no-duplicate-props.') | Out-Null
$rep.Add('') | Out-Null
$rep.Add('## Arquivos alterados') | Out-Null
foreach ($f in $changed) { $rep.Add('- ' + $f) | Out-Null }
$rep.Add('') | Out-Null
$rep.Add('## Verify') | Out-Null
$rep.Add('- tools/cv-verify.ps1 (guard + lint + build)') | Out-Null
$rp = WriteReport 'cv-fix-mapa-duplicate-props-v0_121.md' ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host '[OK] FIX aplicado e verificado.'