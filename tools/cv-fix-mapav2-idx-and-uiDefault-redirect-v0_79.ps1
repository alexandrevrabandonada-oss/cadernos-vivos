$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Write-Host ("[DIAG] Repo: " + $repo)

. (Join-Path $PSScriptRoot "_bootstrap.ps1")

$changed = New-Object System.Collections.Generic.List[string]

function PatchText([string]$rel, [scriptblock]$mutate) {
  $full = Join-Path $repo $rel
  if (!(Test-Path -LiteralPath $full)) {
    Write-Host ("[SKIP] nao achei: " + $full)
    return
  }
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

# 1) MapaV2: nodes.map((n) => { ... idx ... }) -> nodes.map((n, idx) => { ... })
PatchText "src\components\v2\MapaV2.tsx" {
  param($s)
  $out = $s

  if ($out.IndexOf("nodes.map((n, idx) => {") -ge 0) { return $out }
  if ($out.IndexOf("nodes.map((n,idx) => {") -ge 0) { return $out }

  # troca só a primeira ocorrência do padrão comum
  $out2 = [regex]::Replace(
    $out,
    'nodes\.map\(\(\s*n\s*\)\s*=>\s*\{',
    'nodes.map((n, idx) => {',
    1
  )

  return $out2
}

# 2) /c/[slug]/page.tsx: usar uiDefault e redirect quando uiDefault === "v2" (se achar uiDefault)
PatchText "src\app\c\[slug]\page.tsx" {
  param($s)
  $out = $s

  if ($out.IndexOf('if (uiDefault === "v2")') -ge 0 -and $out.IndexOf("redirect(") -ge 0) {
    return $out
  }

  # tenta achar a linha do uiDefault
  $m = [regex]::Match($out, 'const\s+uiDefault\s*=\s*[^;]+;\s*')
  if (!$m.Success) { return $out }

  $insLines = @(
    '  if (uiDefault === "v2") {',
    '    redirect("/c/" + slug + "/v2");',
    '  }',
    ''
  )
  $ins = ($insLines -join "`r`n")
  $pos = $m.Index + $m.Length

  return ($out.Substring(0, $pos) + "`r`n" + $ins + $out.Substring($pos))
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Fix — MapaV2 idx + uiDefault redirect (v0_79)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que foi corrigido") | Out-Null
$rep.Add("- MapaV2: nodes.map agora recebe (n, idx) para compat com layout deterministico.") | Out-Null
$rep.Add("- /c/[slug]: se encontrar uiDefault, faz redirect para /v2 quando uiDefault === ""v2"".") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null

$rp = WriteReport "cv-fix-mapav2-idx-and-uiDefault-redirect-v0_79.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Fix aplicado e verificado."