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

function EnsureRedirectImport([string]$s) {
  $out = $s

  # já tem redirect importado
  if ($out -match 'redirect' -and $out -match 'from\s+["'']next/navigation["'']') { return $out }

  # tenta expandir import { ... } from "next/navigation"
  $m = [regex]::Match($out, 'import\s+\{\s*([^\}]+)\}\s+from\s+["'']next/navigation["''];')
  if ($m.Success) {
    $inside = $m.Groups[1].Value
    if ($inside -notmatch '\bredirect\b') {
      $newInside = $inside.Trim()
      if ($newInside.Length -gt 0 -and $newInside.Trim().EndsWith(",")) {
        $newInside = $newInside.Trim()
      }
      if ($newInside.Length -gt 0) { $newInside = $newInside + ", redirect" } else { $newInside = "redirect" }
      $out2 = $out.Substring(0, $m.Index) + ('import { ' + $newInside + ' } from "next/navigation";') + $out.Substring($m.Index + $m.Length)
      return $out2
    }
    return $out
  }

  # não achou import do next/navigation: injeta após o primeiro import
  $firstImport = [regex]::Match($out, '^\s*import\s+.+?;\s*$', [System.Text.RegularExpressions.RegexOptions]::Multiline)
  if ($firstImport.Success) {
    $pos = $firstImport.Index + $firstImport.Length
    $ins = "`r`n" + 'import { redirect } from "next/navigation";' + "`r`n"
    return ($out.Substring(0, $pos) + $ins + $out.Substring($pos))
  }

  # fallback: coloca no topo
  return ('import { redirect } from "next/navigation";' + "`r`n" + $out)
}

# 1) /c/[slug]/page.tsx — usar uiDefault e redirect (remove warnings de redirect/uiDefault e ativa default=v2)
PatchText "src\app\c\[slug]\page.tsx" {
  param($s)
  $out = $s

  if ($out.IndexOf('if (uiDefault === "v2")') -ge 0) { return $out }

  $idx = $out.IndexOf("const uiDefault")
  if ($idx -lt 0) { return $out }

  $semi = $out.IndexOf(";", $idx)
  if ($semi -lt 0) { return $out }

  $out = EnsureRedirectImport $out

  $blockLines = @(
    '',
    '  if (uiDefault === "v2") {',
    '    redirect("/c/" + slug + "/v2");',
    '  }',
    ''
  )
  $block = ($blockLines -join "`r`n")

  $pos = $semi + 1
  return ($out.Substring(0, $pos) + $block + $out.Substring($pos))
}

# 1b) /c/[slug]/page.tsx — remover import de Link se não houver <Link ...>
PatchText "src\app\c\[slug]\page.tsx" {
  param($s)
  $out = $s
  if ($out.IndexOf("<Link") -ge 0) { return $out }

  $out2 = [regex]::Replace($out, '^\s*import\s+Link\s+from\s+["'']next/link["''];\s*[\r\n]+', '', [System.Text.RegularExpressions.RegexOptions]::Multiline)
  return $out2
}

# 2) /v2/linha/page.tsx — remover JsonValue import se só aparece no import (warning)
PatchText "src\app\c\[slug]\v2\linha\page.tsx" {
  param($s)
  $out = $s
  if ($out.IndexOf("JsonValue") -lt 0) { return $out }

  $count = ([regex]::Matches($out, '\bJsonValue\b')).Count
  if ($count -le 1) {
    $out2 = [regex]::Replace($out, '^\s*import\s+type\s+\{\s*JsonValue\s*\}\s+from\s+["'']@/lib/v2["''];\s*[\r\n]+', '', [System.Text.RegularExpressions.RegexOptions]::Multiline)
    return $out2
  }
  return $out
}

# 3) /v2/trilhas/[id]/page.tsx — se existir const title = ... e title só aparece 1 vez, renomeia p/ _title (ignora warning)
PatchText "src\app\c\[slug]\v2\trilhas\[id]\page.tsx" {
  param($s)
  $out = $s
  if ($out.IndexOf("const title") -lt 0) { return $out }

  $count = ([regex]::Matches($out, '\btitle\b')).Count
  if ($count -le 1) {
    return $out.Replace("const title", "const _title")
  }
  return $out
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Polish — clean warnings + redirect uiDefault v2 (v0_80)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que foi ajustado") | Out-Null
$rep.Add("- /c/[slug]: se uiDefault === ""v2"", redireciona para /c/<slug>/v2 (usa redirect e uiDefault, limpando warnings).") | Out-Null
$rep.Add("- /c/[slug]: remove import Link se não houver <Link>.") | Out-Null
$rep.Add("- /v2/linha: remove import JsonValue quando estiver sobrando.") | Out-Null
$rep.Add("- /v2/trilhas/[id]: renomeia title para _title se estiver sobrando (best-effort).") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null

$rp = WriteReport "cv-polish-clean-warnings-and-redirect-v0_80.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Polish aplicado e verificado."