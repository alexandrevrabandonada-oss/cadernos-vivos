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

# 1) /c/[slug]/page.tsx — usar redirect quando ui.default = v2 e remover Link se estiver sobrando
PatchText "src\app\c\[slug]\page.tsx" {
  param($s)

  $out = $s

  # Remove import de Link se existir (estava dando unused)
  $out = [regex]::Replace($out, '^\s*import\s+Link\s+from\s+"next/link";\s*\r?\n', '', 'Multiline')

  # Se existir const uiDefault = ... ; e ainda não tiver redirect usando uiDefault, injeta bloco
  if ($out -match "const\s+uiDefault\s*=") {
    if ($out.IndexOf('if (uiDefault === "v2")') -lt 0) {
      $out = [regex]::Replace(
        $out,
        '(const\s+uiDefault\s*=\s*[^;]+;\s*)',
        ('$1' + "`r`n" + '  if (uiDefault === "v2") {' + "`r`n" + '    redirect("/c/" + slug + "/v2");' + "`r`n" + '  }' + "`r`n"),
        1
      )
    }
  }

  return $out
}

# 2) /v2/linha/page.tsx — remover JsonValue unused (se existir)
PatchText "src\app\c\[slug]\v2\linha\page.tsx" {
  param($s)
  $out = $s
  $out = [regex]::Replace($out, '^\s*import\s+type\s*\{\s*JsonValue\s*\}\s*from\s*".*?";\s*\r?\n', '', 'Multiline')
  return $out
}

# 3) /v2/trilhas/[id]/page.tsx — remover const title unused (se existir)
PatchText "src\app\c\[slug]\v2\trilhas\[id]\page.tsx" {
  param($s)
  $out = $s
  $out = [regex]::Replace($out, '^\s*const\s+title\s*=\s*[^;]+;\s*\r?\n', '', 'Multiline')
  return $out
}

# 4) MapaV2 — remover idx unused no map callback (nodes.map((n, idx) => ...)
PatchText "src\components\v2\MapaV2.tsx" {
  param($s)
  $out = $s
  $out = [regex]::Replace($out, 'nodes\.map\(\s*\(\s*([a-zA-Z_]\w*)\s*,\s*idx\s*\)\s*=>', 'nodes.map(($1) =>')
  $out = [regex]::Replace($out, 'nodes\.map\(\s*\(\s*([a-zA-Z_]\w*)\s*,\s*index\s*\)\s*=>', 'nodes.map(($1) =>')
  return $out
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Step — Cleanup warnings + redirect default V2 (v0_76)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que entrou") | Out-Null
$rep.Add("- /c/[slug]: se uiDefault for v2, faz redirect para /c/[slug]/v2 (usa redirect e evita unused).") | Out-Null
$rep.Add("- Remove imports/vars que estavam gerando warnings (Link/JsonValue/title/idx).") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null

$rp = WriteReport "cv-step-cleanup-warnings-and-default-redirect-v0_76.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Step aplicado e verificado."