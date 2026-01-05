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

# -----------------------------------------
# 1) src/components/v2/TrilhasV2.tsx — adicionar summary?: string ao type Trail
# -----------------------------------------
PatchText "src\components\v2\TrilhasV2.tsx" {
  param($s)
  $out = $s

  if ($out -match 'export\s+type\s+Trail\b' -and $out -match 'summary\?\s*:') { return $out }

  $m = [regex]::Match($out, 'export\s+type\s+Trail\s*=\s*\{', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if (-not $m.Success) { return $out }

  # inserir logo após desc?: string; se existir, senão após title?: string;, senão no começo do bloco
  $blockStart = $m.Index + $m.Length
  $posDesc = $out.IndexOf("desc?: string;", $blockStart)
  if ($posDesc -ge 0) {
    $insertAt = $posDesc + "desc?: string;".Length
  } else {
    $posTitle = $out.IndexOf("title?: string;", $blockStart)
    if ($posTitle -ge 0) { $insertAt = $posTitle + "title?: string;".Length } else { $insertAt = $blockStart }
  }

  $ins = "`r`n  summary?: string;"
  return ($out.Substring(0, $insertAt) + $ins + $out.Substring($insertAt))
}

# -----------------------------------------
# 2) src/app/c/[slug]/page.tsx — usar uiDefault+redirect (inserir antes do return do export default)
# -----------------------------------------
PatchText "src\app\c\[slug]\page.tsx" {
  param($s)
  $out = $s

  if ($out.IndexOf('redirect("/c/" + slug + "/v2")') -ge 0) { return $out }
  if ($out -notmatch '\buiDefault\b') { return $out } # se não existir, não mexe

  $start = $out.IndexOf("export default")
  if ($start -lt 0) { $start = 0 }

  $sub = $out.Substring($start)
  $m = [regex]::Match($sub, '(?m)^\s*return\s*\(')
  if (-not $m.Success) { return $out }

  $insertPos = $start + $m.Index

  # indent do "return"
  $ls = $out.LastIndexOf("`n", $insertPos)
  if ($ls -lt 0) { $ls = 0 } else { $ls = $ls + 1 }
  $le = $out.IndexOf("`n", $ls)
  if ($le -lt 0) { $le = $out.Length }
  $line = $out.Substring($ls, $le - $ls)
  $indent = ([regex]::Match($line, '^\s*')).Value

  $block = @(
    $indent + 'if (uiDefault === "v2") {'
    $indent + '  redirect("/c/" + slug + "/v2");'
    $indent + '}'
    ''
  ) -join "`r`n"

  return ($out.Substring(0, $insertPos) + $block + $out.Substring($insertPos))
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Fix — Trail.summary + root redirect (v0_110)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que foi corrigido") | Out-Null
$rep.Add("- Type Trail agora aceita summary?: string (corrige build de /v2/trilhas/[id]).") | Out-Null
$rep.Add("- /c/[slug]/page.tsx agora usa uiDefault+redirect (zera warnings do lint).") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null
$rp = WriteReport "cv-fix-trail-summary-and-root-redirect-v0_110.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Fix aplicado e verificado."