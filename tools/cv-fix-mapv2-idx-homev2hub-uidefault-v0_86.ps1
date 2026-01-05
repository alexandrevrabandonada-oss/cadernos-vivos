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

function ReplaceNth([string]$text, [string]$needle, [string]$replacement, [int]$n) {
  if ($n -le 0) { return $text }
  $i = 0
  $pos = -1
  $start = 0
  while ($true) {
    $pos = $text.IndexOf($needle, $start, [System.StringComparison]::Ordinal)
    if ($pos -lt 0) { return $text }
    $i++
    if ($i -eq $n) {
      return ($text.Substring(0, $pos) + $replacement + $text.Substring($pos + $needle.Length))
    }
    $start = $pos + $needle.Length
  }
}

# 1) MapaV2.tsx — corrigir usos de idx -> _idx onde o map já é (n, _idx)
PatchText "src\components\v2\MapaV2.tsx" {
  param($s)
  $out = $s

  # troca os dois pontos do erro de build (left/top) sem fazer replace global perigoso
  $out = [regex]::Replace($out, '\(\(\s*idx\s*%\s*5\s*\)\s*\*\s*240\s*\)', '((_idx % 5) * 240)')
  $out = [regex]::Replace($out, 'Math\.floor\(\s*idx\s*/\s*5\s*\)\s*\*\s*120', 'Math.floor(_idx / 5) * 120')

  # se ainda sobrou "floor(idx / 5)" com outro espaçamento
  $out = [regex]::Replace($out, 'Math\.floor\(\s*idx\s*/\s*5\s*\)', 'Math.floor(_idx / 5)')

  # 2 mapas com (n, _idx) estavam gerando warning: deixa index só no 1º, remove do 2º
  $needle = '.map((n, _idx) =>'
  $count = 0
  $scan = 0
  while ($true) {
    $p = $out.IndexOf($needle, $scan, [System.StringComparison]::Ordinal)
    if ($p -lt 0) { break }
    $count++
    $scan = $p + $needle.Length
  }
  if ($count -ge 2) {
    $out = ReplaceNth $out $needle '.map((n) =>' 2
  }

  return $out
}

# 2) HomeV2Hub.tsx — limpar warnings: remove useEffect/useSyncExternalStore se não usa + remove setLast se não usa
PatchText "src\components\v2\HomeV2Hub.tsx" {
  param($s)
  $out = $s

  $hasUseEffect = ($out.IndexOf('useEffect(', [System.StringComparison]::Ordinal) -ge 0) -or ($out.IndexOf('React.useEffect(', [System.StringComparison]::Ordinal) -ge 0)
  $hasUseSync = ($out.IndexOf('useSyncExternalStore(', [System.StringComparison]::Ordinal) -ge 0) -or ($out.IndexOf('React.useSyncExternalStore(', [System.StringComparison]::Ordinal) -ge 0)

  # a) se não usa, remove do import { ... } from "react";
  $m = [regex]::Match($out, 'import\s+React\s*,\s*\{([^}]*)\}\s+from\s+"react";')
  if ($m.Success) {
    $inner = $m.Groups[1].Value
    $parts = @()
    foreach ($p in ($inner.Split(",") | ForEach-Object { $_.Trim() })) {
      if ($p -ne "") { $parts += $p }
    }
    $keep = New-Object System.Collections.Generic.List[string]
    foreach ($p in $parts) {
      if (($p -eq "useEffect") -and (-not $hasUseEffect)) { continue }
      if (($p -eq "useSyncExternalStore") -and (-not $hasUseSync)) { continue }
      $keep.Add($p) | Out-Null
    }
    $newInner = ($keep.ToArray() -join ", ")
    $newImport = 'import React, {' + $newInner + '} from "react";'
    $out = $out.Substring(0, $m.Index) + $newImport + $out.Substring($m.Index + $m.Length)
  } else {
    $m2 = [regex]::Match($out, 'import\s*\{([^}]*)\}\s+from\s+"react";')
    if ($m2.Success) {
      $inner2 = $m2.Groups[1].Value
      $parts2 = @()
      foreach ($p in ($inner2.Split(",") | ForEach-Object { $_.Trim() })) {
        if ($p -ne "") { $parts2 += $p }
      }
      $keep2 = New-Object System.Collections.Generic.List[string]
      foreach ($p in $parts2) {
        if (($p -eq "useEffect") -and (-not $hasUseEffect)) { continue }
        if (($p -eq "useSyncExternalStore") -and (-not $hasUseSync)) { continue }
        $keep2.Add($p) | Out-Null
      }
      $newInner2 = ($keep2.ToArray() -join ", ")
      $newImport2 = 'import {' + $newInner2 + '} from "react";'
      $out = $out.Substring(0, $m2.Index) + $newImport2 + $out.Substring($m2.Index + $m2.Length)
    }
  }

  # b) se setLast existe mas não é usado, remove do destructuring
  if ($out -match 'const\s*\[\s*last\s*,\s*setLast\s*\]\s*=') {
    # só faz a troca se NÃO houver uso de setLast( ... ) em lugar nenhum
    if ($out.IndexOf('setLast(', [System.StringComparison]::Ordinal) -lt 0) {
      $out = [regex]::Replace($out, 'const\s*\[\s*last\s*,\s*setLast\s*\]\s*=\s*', 'const [last] = ', 1)
    }
  }

  return $out
}

# 3) /c/[slug]/page.tsx — usar uiDefault + redirect (tira warnings redirect/uiDefault)
PatchText "src\app\c\[slug]\page.tsx" {
  param($s)
  $out = $s

  # já tem bloco?
  if ($out.IndexOf('uiDefault === "v2"', [System.StringComparison]::Ordinal) -ge 0 -and $out.IndexOf('redirect("/c/" + slug + "/v2")', [System.StringComparison]::Ordinal) -ge 0) {
    return $out
  }

  # garantir import de redirect em next/navigation se vamos usar
  $nav = [regex]::Match($out, 'import\s*\{\s*([^}]*)\s*\}\s*from\s*"next/navigation";')
  if ($nav.Success) {
    $inner = $nav.Groups[1].Value
    if ($inner -notmatch '\bredirect\b') {
      $newInner = $inner.Trim()
      if ($newInner.Length -gt 0) { $newInner = $newInner + ", redirect" } else { $newInner = "redirect" }
      $newLine = 'import { ' + $newInner + ' } from "next/navigation";'
      $out = $out.Substring(0, $nav.Index) + $newLine + $out.Substring($nav.Index + $nav.Length)
    }
  }

  # achar const uiDefault = ...;
  $m = [regex]::Match($out, 'const\s+uiDefault\s*=\s*[^;]+;\s*')
  if (!$m.Success) {
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

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Fix — MapaV2 idx + HomeV2Hub warnings + uiDefault redirect (v0_86)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que foi corrigido") | Out-Null
$rep.Add("- MapaV2: corrigiu referencias idx -> _idx nos calculos e removeu o _idx do 2o map quando não usado.") | Out-Null
$rep.Add("- HomeV2Hub: removeu imports nao usados (useEffect/useSyncExternalStore) e removeu setLast do destructuring quando não usado.") | Out-Null
$rep.Add('- /c/[slug]: usa uiDefault === "v2" para redirect("/c/"+slug+"/v2") e garante import de redirect.') | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null

$rp = WriteReport "cv-fix-mapv2-idx-homev2hub-uidefault-v0_86.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Fix aplicado e verificado."