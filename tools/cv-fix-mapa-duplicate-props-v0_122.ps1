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

function PrintContext([string]$fp, [int]$centerLine, [int]$radius) {
  if (!(Test-Path -LiteralPath $fp)) { return }
  $lines = Get-Content -LiteralPath $fp
  $start = [Math]::Max(1, $centerLine - $radius)
  $end = [Math]::Min($lines.Length, $centerLine + $radius)
  Write-Host ""
  Write-Host ("[DIAG] Contexto " + (Split-Path -Leaf $fp) + " linhas " + $start + "-" + $end + " (centro=" + $centerLine + ")")
  for ($i = $start; $i -le $end; $i++) {
    $prefix = $i.ToString().PadLeft(4,' ')
    Write-Host ($prefix + ": " + $lines[$i-1])
  }
  Write-Host ""
}

function RemoveDupDoubleBraceProp([string]$text, [string]$prop) {
  $out = $text
  # Ex.: style={{...}} style={{...}}
  $rx = '(?s)(\s' + $prop + '=\{\{.*?\}\})\s+' + $prop + '=\{\{.*?\}\}'
  while ([regex]::IsMatch($out, $rx)) {
    $out = [regex]::Replace($out, $rx, '$1')
  }
  return $out
}

function RemoveDupBraceProp([string]$text, [string]$prop) {
  $out = $text
  # Ex.: mapa={...} mapa={...} (limita pra não atravessar >)
  $rx = '(?s)(\s' + $prop + '=\{[^>]*?\})\s+' + $prop + '=\{[^>]*?\}'
  while ([regex]::IsMatch($out, $rx)) {
    $out = [regex]::Replace($out, $rx, '$1')
  }
  return $out
}

function RemoveDupQuotedProp([string]$text, [string]$prop) {
  $out = $text
  # Ex.: className="..." className="..."
  $rx = '(\s' + $prop + '="[^"]*")\s+' + $prop + '="[^"]*"'
  while ([regex]::IsMatch($out, $rx)) {
    $out = [regex]::Replace($out, $rx, '$1')
  }
  return $out
}

$rel = 'src\components\v2\MapaV2Interactive.tsx'
$fp0 = Join-Path $repo $rel
PrintContext $fp0 37 6

PatchText $rel {
  param($s)
  $out = $s

  # 1) style={{...}} duplicado é o campeão desse erro
  $out = RemoveDupDoubleBraceProp $out 'style'

  # 2) outros props comuns (inclui style de novo em modo {..} por segurança)
  foreach ($p in @('mapa','slug','title','style')) {
    $out = RemoveDupBraceProp $out $p
  }

  # 3) quoted props
  foreach ($p in @('className','id','href')) {
    $out = RemoveDupQuotedProp $out $p
  }

  return $out
}

PrintContext $fp0 37 6

# VERIFY
$verify = Join-Path $repo 'tools\cv-verify.ps1'
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add('# CV — FIX — MapaV2Interactive sem props duplicadas (v0_122)') | Out-Null
$rep.Add('') | Out-Null
$rep.Add('## O que foi corrigido') | Out-Null
$rep.Add('- Remove props duplicadas em JSX (especialmente style={{...}}), para passar react/jsx-no-duplicate-props.') | Out-Null
$rep.Add('') | Out-Null
$rep.Add('## Arquivos alterados') | Out-Null
foreach ($f in $changed) { $rep.Add('- ' + $f) | Out-Null }
$rep.Add('') | Out-Null
$rep.Add('## Verify') | Out-Null
$rep.Add('- tools/cv-verify.ps1 (guard + lint + build)') | Out-Null
$rp = WriteReport 'cv-fix-mapa-duplicate-props-v0_122.md' ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host '[OK] FIX aplicado e verificado.'