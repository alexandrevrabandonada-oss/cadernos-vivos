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

# 1) /v2/trilhas/[id] — title shorthand inexistente -> title: id
PatchText "src\app\c\[slug]\v2\trilhas\[id]\page.tsx" {
  param($s)
  $out = $s

  $out2 = [regex]::Replace(
    $out,
    "return\s*\{\s*id\s*,\s*title\s*,\s*summary\s*:",
    "return { id, title: id, summary:",
    1
  )

  if ($out2 -eq $out) {
    $out2 = [regex]::Replace(
      $out,
      "(\breturn\s*\{\s*)(id\s*,\s*)title(\s*,)",
      '$1$2title: id$3',
      1
    )
  }

  return $out2
}

# 2) /c/[slug] — usar uiDefault + redirect para default=v2 (e tirar warning de unused)
PatchText "src\app\c\[slug]\page.tsx" {
  param($s)
  $out = $s

  # já tem redirect por uiDefault?
  if ($out -match 'uiDefault\s*===\s*["'']v2["'']') { return $out }

  # garantir import redirect do next/navigation, se faltar
  $mNav = [regex]::Match($out, 'import\s*\{\s*([^}]+)\s*\}\s*from\s*["'']next/navigation["''];')
  if ($mNav.Success) {
    $inside = $mNav.Groups[1].Value
    if ($inside -notmatch '\bredirect\b') {
      $inside2 = ($inside.Trim() + ", redirect")
      $out = $out.Substring(0, $mNav.Groups[1].Index) + $inside2 + $out.Substring($mNav.Groups[1].Index + $mNav.Groups[1].Length)
    }
  } else {
    # se não tem import {..} next/navigation, não inventa — só deixa quieto
  }

  # achar uiDefault e injetar o bloco logo após
  $m = [regex]::Match($out, "const\s+uiDefault\s*=\s*[^;]+;\s*")
  if (!$m.Success) { return $out }

  $pos = $m.Index + $m.Length
  $ins = '  if (uiDefault === "v2") {' + "`r`n" +
         '    redirect("/c/" + slug + "/v2");' + "`r`n" +
         '  }' + "`r`n"

  return ($out.Substring(0, $pos) + "`r`n" + $ins + $out.Substring($pos))
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Fix — Trilhas title + slug redirect default v2 (v0_79)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que foi corrigido") | Out-Null
$rep.Add("- /v2/trilhas/[id]: title shorthand removido (agora title: id).") | Out-Null
$rep.Add("- /c/[slug]: usa uiDefault e redirect quando uiDefault === v2.") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null
$rp = WriteReport "cv-fix-trilhas-title-and-slug-redirect-v0_79.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Fix aplicado e verificado."