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

# 1) Corrigir import na Home V2 page (default export)
PatchText "src\app\c\[slug]\v2\page.tsx" {
  param($s)
  $out = $s

  # substitui qualquer import nomeado do HomeV2Hub por default import
  $out2 = [regex]::Replace(
    $out,
    'import\s*\{\s*HomeV2Hub\s*(?:,\s*type\s*HubStats\s*)?\}\s*from\s*"@/components/v2/HomeV2Hub";',
    'import HomeV2Hub from "@/components/v2/HomeV2Hub";'
  )
  $out = $out2

  # se ainda houver referência a HubStats, cria um type local best-effort
  if ($out.IndexOf("HubStats") -ge 0 -and $out.IndexOf("type HubStats") -lt 0) {
    $marker = "type AccentStyle"
    $idx = $out.IndexOf($marker)
    if ($idx -gt 0) {
      $insLines = @(
        'type HubStats = Record<string, unknown>;',
        ''
      )
      $ins = ($insLines -join "`r`n")
      $out = $out.Substring(0, $idx) + $ins + $out.Substring($idx)
    }
  }

  return $out
}

# 2) /c/[slug]/page.tsx: usar uiDefault e redirect (remove warnings)
PatchText "src\app\c\[slug]\page.tsx" {
  param($s)
  $out = $s

  # já tem o bloco? não mexe
  if ($out.IndexOf('uiDefault === "v2"') -ge 0 -and $out.IndexOf("redirect(") -ge 0) {
    return $out
  }

  $idx = $out.IndexOf("const uiDefault")
  if ($idx -lt 0) { return $out }

  # acha fim da linha (primeiro ';' depois do const uiDefault)
  $semi = $out.IndexOf(";", $idx)
  if ($semi -lt 0) { return $out }

  # insere logo após a quebra de linha seguinte ao ';'
  $nl = $out.IndexOf("`n", $semi)
  if ($nl -lt 0) { $nl = $semi }

  $insLines = @(
    '',
    '  if (uiDefault === "v2") {',
    '    redirect("/c/" + slug + "/v2");',
    '  }',
    ''
  )
  $ins = ($insLines -join "`r`n")

  return ($out.Substring(0, $nl + 1) + $ins + $out.Substring($nl + 1))
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Fix — HomeV2Hub import + /c/[slug] redirect (v0_94)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que foi corrigido") | Out-Null
$rep.Add("- src/app/c/[slug]/v2/page.tsx: import do HomeV2Hub agora é default (compat com componente atual).") | Out-Null
$rep.Add("- src/app/c/[slug]/page.tsx: uiDefault + redirect usados quando default=v2 (remove warnings).") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null

$rp = WriteReport "cv-fix-homev2hub-import-and-slug-redirect-v0_94.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Fix aplicado e verificado."