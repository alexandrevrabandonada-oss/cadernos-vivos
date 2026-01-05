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

# 1) /c/[slug]/page.tsx — usar uiDefault e redirect (tira warnings redirect/uiDefault; remove Link se não usa)
PatchText "src\app\c\[slug]\page.tsx" {
  param($s)
  $out = $s

  # a) se Link importado mas não usado, remove a linha
  if ($out -match 'import\s+Link\s+from\s+"next/link";') {
    $rest = $out -replace 'import\s+Link\s+from\s+"next/link";\s*\r?\n', ""
    # se ainda sobrou "Link" no arquivo (usos reais), volta atrás
    if ($rest -match '\bLink\b') {
      $out = $out
    } else {
      $out = $rest
    }
  }

  # b) se já tem redirect condicionado pelo uiDefault, não mexe
  if ($out.IndexOf('uiDefault === "v2"') -ge 0 -and $out.IndexOf("redirect(") -ge 0) {
    return $out
  }

  # c) encontra "const uiDefault = ...;" e injeta bloco de redirect logo após
  $m = [regex]::Match($out, 'const\s+uiDefault\s*=\s*[^;]+;\s*')
  if (!$m.Success) {
    # não achou uiDefault — não arrisca
    return $out
  }

  $ins = @(
    '  if (uiDefault === "v2") {',
    '    redirect("/c/" + slug + "/v2");',
    '  }',
    ''
  ) -join "`r`n"

  $pos = $m.Index + $m.Length
  return ($out.Substring(0, $pos) + "`r`n" + $ins + $out.Substring($pos))
}

# 2) /c/[slug]/v2/linha/page.tsx — remover import JsonValue se estiver realmente inutilizado
PatchText "src\app\c\[slug]\v2\linha\page.tsx" {
  param($s)
  $out = $s
  if ($out -match 'import\s+type\s*\{\s*JsonValue\s*\}\s*from\s*"\@/lib/v2";') {
    $rest = $out -replace 'import\s+type\s*\{\s*JsonValue\s*\}\s*from\s*"\@/lib/v2";\s*\r?\n', ""
    if ($rest -match '\bJsonValue\b') { return $out }
    return $rest
  }
  return $out
}

# 3) MapaV2.tsx — idx definido mas nunca usado: renomeia para _idx (regra geralmente ignora underscore)
PatchText "src\components\v2\MapaV2.tsx" {
  param($s)
  $out = $s

  # cobre variações comuns
  $out = [regex]::Replace($out, 'nodes\.map\(\(\s*n\s*,\s*idx\s*\)\s*=>', 'nodes.map((n, _idx) =>')
  $out = [regex]::Replace($out, 'nodes\.map\(\(\s*n\s*,\s*idx\s*\)\s*=>', 'nodes.map((n, _idx) =>')

  # se tiver "map((n, idx) =>" sem "nodes.", também troca (bem comum em outros blocos)
  $out = [regex]::Replace($out, '\.map\(\(\s*n\s*,\s*idx\s*\)\s*=>', '.map((n, _idx) =>')

  return $out
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Step — Polish uiDefault + warnings (v0_85)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que foi feito") | Out-Null
$rep.Add('- /c/[slug]: se uiDefault === "v2", faz redirect("/c/"+slug+"/v2") e remove Link import se estava inútil.') | Out-Null
$rep.Add("- /v2/linha: remove import JsonValue se realmente não é usado.") | Out-Null
$rep.Add("- MapaV2: renomeia idx -> _idx pra parar warning de unused var.") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null

$rp = WriteReport "cv-step-polish-uiDefault-and-warnings-v0_85.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Polish aplicado e verificado."