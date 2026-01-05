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

function InsertAfterSemicolon([string]$text, [int]$fromIndex, [string]$insert) {
  $semi = $text.IndexOf(";", $fromIndex, [System.StringComparison]::Ordinal)
  if ($semi -lt 0) { return $text }
  $pos = $semi + 1
  return ($text.Substring(0, $pos) + "`r`n" + $insert + $text.Substring($pos))
}

# 1) MapaV2 — trocar _idx -> idx (por palavra) e garantir map principal com (n, idx)
PatchText "src\components\v2\MapaV2.tsx" {
  param($s)
  $out = $s

  # garante assinatura do map principal (se ainda estiver com _idx)
  if ($out.IndexOf("nodes.map((n, _idx) =>", [System.StringComparison]::Ordinal) -ge 0) {
    $out = $out.Replace("nodes.map((n, _idx) =>", "nodes.map((n, idx) =>")
  }

  # troca _idx por idx quando for identificador inteiro
  $out = [regex]::Replace($out, '\b_idx\b', 'idx')

  return $out
}

# 2) HomeV2Hub — se estiver usando React.useSyncExternalStore, trocar para useSyncExternalStore (usa o import)
PatchText "src\components\v2\HomeV2Hub.tsx" {
  param($s)
  $out = $s

  if ($out.IndexOf("React.useSyncExternalStore", [System.StringComparison]::Ordinal) -ge 0) {
    $out = $out.Replace("React.useSyncExternalStore", "useSyncExternalStore")
  }

  return $out
}

# 3) /c/[slug] — usar uiDefault + redirect (mata warnings e aplica default=v2)
PatchText "src\app\c\[slug]\page.tsx" {
  param($s)
  $out = $s

  if ($out.IndexOf('uiDefault === "v2"', [System.StringComparison]::Ordinal) -ge 0) {
    return $out
  }

  $idx = $out.IndexOf("const uiDefault", [System.StringComparison]::Ordinal)
  if ($idx -lt 0) { $idx = $out.IndexOf("let uiDefault", [System.StringComparison]::Ordinal) }

  if ($idx -lt 0) {
    # se não achou uiDefault, não arrisca
    return $out
  }

  $block = @(
    'if (uiDefault === "v2") {',
    '  redirect("/c/" + slug + "/v2");',
    '}',
    ''
  ) -join "`r`n"

  return (InsertAfterSemicolon $out $idx $block)
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Fix — idx/_idx + HomeV2Hub useSyncExternalStore + uiDefault redirect (v0_88)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que foi corrigido") | Out-Null
$rep.Add("- MapaV2: removeu _idx remanescente (agora usa idx corretamente).") | Out-Null
$rep.Add("- HomeV2Hub: se existia React.useSyncExternalStore, troca para useSyncExternalStore (usa o import).") | Out-Null
$rep.Add('- /c/[slug]: usa uiDefault e redireciona quando uiDefault === "v2".') | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null

$rp = WriteReport "cv-fix-mapv2-idx-homev2hub-uidefault-v0_88.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Fix aplicado e verificado."