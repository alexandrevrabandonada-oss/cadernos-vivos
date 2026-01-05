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

# 1) V2Nav — badge "V2 beta" + link V1
PatchText "src\components\v2\V2Nav.tsx" {
  param($s)
  $out = $s

  if ($out.IndexOf("V2 beta", [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { return $out }

  # garante import de Link
  if ($out -notmatch 'from\s+"next/link"') {
    $mImp = [regex]::Match($out, '(?m)^import\s+.*?;\s*$')
    if ($mImp.Success) {
      $pos = $mImp.Index + $mImp.Length
      $out = $out.Substring(0, $pos) + "`r`n" + 'import Link from "next/link";' + $out.Substring($pos)
    } else {
      $out = 'import Link from "next/link";' + "`r`n" + $out
    }
  }

  $needle = "</nav>"
  $idx = $out.IndexOf($needle, [System.StringComparison]::Ordinal)
  if ($idx -lt 0) { return $out }

  $ins = @(
    '',
    '      <div className="flex items-center gap-2">',
    '        <Link href={"/c/" + slug} className="text-xs underline opacity-80 hover:opacity-100">V1</Link>',
    '        <span className="text-[10px] uppercase tracking-wider px-2 py-1 rounded-full border border-current/30 opacity-80">V2 beta</span>',
    '      </div>',
    ''
  ) -join "`r`n"

  return ($out.Substring(0, $idx) + $ins + $out.Substring($idx))
}

# 2) /c/[slug]/page.tsx — usar uiDefault e chamar redirect quando default=v2
PatchText "src\app\c\[slug]\page.tsx" {
  param($s)
  $out = $s

  if ($out.IndexOf('uiDefault === "v2"', [System.StringComparison]::Ordinal) -ge 0) { return $out }
  if ($out.IndexOf('redirect("/c/" + slug + "/v2")', [System.StringComparison]::Ordinal) -ge 0) { return $out }

  # acha statement do uiDefault
  $m = [regex]::Match($out, '(?s)(const|let)\s+uiDefault\s*=\s*.*?;\s*')
  if (!$m.Success) { return $out }

  $block = @(
    'if (uiDefault === "v2") {',
    '  redirect("/c/" + slug + "/v2");',
    '}',
    ''
  ) -join "`r`n"

  $pos = $m.Index + $m.Length
  return ($out.Substring(0, $pos) + "`r`n" + $block + $out.Substring($pos))
}

# 3) HomeV2Hub — se importou useSyncExternalStore mas não usa, remove do import
PatchText "src\components\v2\HomeV2Hub.tsx" {
  param($s)
  $out = $s

  $uses = ($out.IndexOf("useSyncExternalStore(", [System.StringComparison]::Ordinal) -ge 0)
  if ($uses) { return $out }

  # remove do import { ... }
  $out2 = [regex]::Replace(
    $out,
    '(?m)^import\s*\{\s*([^}]*)\s*\}\s*from\s*"react";\s*$',
    {
      param($m0)
      $inner = $m0.Groups[1].Value
      if ($inner -notmatch '\buseSyncExternalStore\b') { return $m0.Value }
      $parts = @()
      foreach ($p in ($inner -split ',')) {
        $t = $p.Trim()
        if ($t.Length -eq 0) { continue }
        if ($t -eq 'useSyncExternalStore') { continue }
        $parts += $t
      }
      return ('import { ' + ($parts -join ', ') + ' } from "react";')
    }
  )

  # remove do import React, { ... } from "react";
  $out2 = [regex]::Replace(
    $out2,
    '(?m)^import\s+React\s*,\s*\{\s*([^}]*)\s*\}\s*from\s*"react";\s*$',
    {
      param($m0)
      $inner = $m0.Groups[1].Value
      if ($inner -notmatch '\buseSyncExternalStore\b') { return $m0.Value }
      $parts = @()
      foreach ($p in ($inner -split ',')) {
        $t = $p.Trim()
        if ($t.Length -eq 0) { continue }
        if ($t -eq 'useSyncExternalStore') { continue }
        $parts += $t
      }
      return ('import React, { ' + ($parts -join ', ') + ' } from "react";')
    }
  )

  return $out2
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Step — UI Switch V1↔V2 + uiDefault redirect (v0_89)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que foi feito") | Out-Null
$rep.Add('- V2Nav: adiciona "V2 beta" + link para V1.') | Out-Null
$rep.Add('- /c/[slug]: aplica redirect quando meta.ui.default = "v2" (usa uiDefault + redirect).') | Out-Null
$rep.Add("- HomeV2Hub: remove import useSyncExternalStore se estiver sobrando.") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null

$rp = WriteReport "cv-step-ui-switch-v1-v2-and-uidefault-v0_89.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Step aplicado e verificado."