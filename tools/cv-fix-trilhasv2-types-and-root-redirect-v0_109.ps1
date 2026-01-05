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

# ---------------------------
# 1) Exportar types Trail / TrailStep em src/components/v2/TrilhasV2.tsx
# ---------------------------
PatchText "src\components\v2\TrilhasV2.tsx" {
  param($s)
  $out = $s

  if ($out.IndexOf("export type Trail") -ge 0 -and $out.IndexOf("export type TrailStep") -ge 0) {
    return $out
  }

  $anchor = "type AnyObj = Record<string, unknown>;"
  $pos = $out.IndexOf($anchor)
  if ($pos -lt 0) {
    # fallback: coloca no topo após os imports
    $pos2 = $out.IndexOf("type ")
    if ($pos2 -lt 0) { return $out }
    $insertAt = $pos2
  } else {
    $insertAt = $pos + $anchor.Length
  }

  $types = @(
    ""
    "export type TrailStep = string | Record<string, unknown>;"
    "export type Trail = {"
    "  id?: string;"
    "  title?: string;"
    "  desc?: string;"
    "  steps?: TrailStep[];"
    "  tags?: string[];"
    "  kind?: string;"
    "};"
    ""
  ) -join "`r`n"

  return ($out.Substring(0, $insertAt) + "`r`n" + $types + $out.Substring($insertAt))
}

# ---------------------------
# 2) Zerar warnings do /c/[slug]/page.tsx:
# usar uiDefault e redirect de verdade (redirect para /v2 quando meta.ui.default === 'v2')
# (regex robusto pra const uiDefault em múltiplas linhas)
# ---------------------------
PatchText "src\app\c\[slug]\page.tsx" {
  param($s)
  $out = $s

  # se já tem o bloco, ok
  if ($out.IndexOf('if (uiDefault === "v2")') -ge 0 -and $out.IndexOf('redirect("/c/" + slug + "/v2")') -ge 0) {
    return $out
  }

  # garantir import redirect
  if ($out -match 'from\s+["'']next/navigation["'']') {
    if ($out -notmatch '\bredirect\b') {
      $out = [regex]::Replace(
        $out,
        'import\s*\{\s*([^}]*)\}\s*from\s*["'']next/navigation["''];',
        {
          param($m)
          $inner = $m.Groups[1].Value
          if ($inner -match '\bredirect\b') { return $m.Value }
          $inner2 = $inner.Trim()
          if ($inner2.Length -gt 0) { return ('import { ' + $inner2 + ', redirect } from "next/navigation";') }
          return 'import { redirect } from "next/navigation";'
        },
        1
      )
    }
  } else {
    $out = 'import { redirect } from "next/navigation";' + "`r`n" + $out
  }

  $m = [regex]::Match($out, '(?s)const\s+uiDefault\b[\s\S]*?;')
  if (-not $m.Success) {
    Write-Host "[WARN] nao encontrei const uiDefault; deixando como estava."
    return $out
  }

  $insertPos = $m.Index + $m.Length
  $ins = @(
    ""
    "  if (uiDefault === ""v2"") {"
    "    redirect(""/c/"" + slug + ""/v2"");"
    "  }"
    ""
  ) -join "`r`n"

  return ($out.Substring(0, $insertPos) + $ins + $out.Substring($insertPos))
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Fix — TrilhasV2 types + root redirect (v0_109)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que foi corrigido") | Out-Null
$rep.Add("- TrilhasV2 agora exporta types Trail e TrailStep (corrige build de /v2/trilhas/[id]).") | Out-Null
$rep.Add("- /c/[slug]/page.tsx agora usa uiDefault + redirect (zera warnings do lint).") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null
$rp = WriteReport "cv-fix-trilhasv2-types-and-root-redirect-v0_109.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Fix aplicado e verificado."