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

# 1) MapaV2 — garantir que o map que usa idx tenha (n, idx) (e remover index do 2o map se estiver sobrando)
PatchText "src\components\v2\MapaV2.tsx" {
  param($s)
  $out = $s

  $needle = '.map((n, _idx) =>'
  $count = 0
  $scan = 0
  while ($true) {
    $p = $out.IndexOf($needle, $scan, [System.StringComparison]::Ordinal)
    if ($p -lt 0) { break }
    $count++
    $scan = $p + $needle.Length
  }

  if ($count -ge 1) {
    # 1a ocorrencia: vira idx (pra casar com o codigo que usa idx)
    $out = ReplaceNth $out $needle '.map((n, idx) =>' 1
  }
  if ($count -ge 2) {
    # 2a ocorrencia: se nao usa index, remove (evita warning)
    $out = ReplaceNth $out $needle '.map((n) =>' 2
  }

  return $out
}

# 2) HomeV2Hub — remover useState/useEffect (setState em effect) e usar useSyncExternalStore
PatchText "src\components\v2\HomeV2Hub.tsx" {
  param($s)
  $out = $s

  # 2.1) garantir import do useSyncExternalStore e remover useEffect se não usar
  $hasUseSyncCall = ($out.IndexOf("useSyncExternalStore(", [System.StringComparison]::Ordinal) -ge 0) -or ($out.IndexOf("React.useSyncExternalStore(", [System.StringComparison]::Ordinal) -ge 0)

  if (-not $hasUseSyncCall) {
    $m = [regex]::Match($out, 'import\s+React\s*,\s*\{([^}]*)\}\s+from\s+"react";')
    if ($m.Success) {
      $inner = $m.Groups[1].Value
      if ($inner -notmatch '\buseSyncExternalStore\b') {
        $newInner = $inner.Trim()
        if ($newInner.Length -gt 0) { $newInner = $newInner.Trim().TrimEnd(",") }
        if ($newInner.Length -gt 0) { $newInner = $newInner + ", " }
        $newInner = $newInner + "useSyncExternalStore"
        $newImport = 'import React, {' + $newInner + '} from "react";'
        $out = $out.Substring(0, $m.Index) + $newImport + $out.Substring($m.Index + $m.Length)
      }
    } else {
      $m2 = [regex]::Match($out, 'import\s*\{([^}]*)\}\s+from\s+"react";')
      if ($m2.Success) {
        $inner2 = $m2.Groups[1].Value
        if ($inner2 -notmatch '\buseSyncExternalStore\b') {
          $newInner2 = $inner2.Trim()
          if ($newInner2.Length -gt 0) { $newInner2 = $newInner2.Trim().TrimEnd(",") }
          if ($newInner2.Length -gt 0) { $newInner2 = $newInner2 + ", " }
          $newInner2 = $newInner2 + "useSyncExternalStore"
          $newImport2 = 'import {' + $newInner2 + '} from "react";'
          $out = $out.Substring(0, $m2.Index) + $newImport2 + $out.Substring($m2.Index + $m2.Length)
        }
      }
    }
  }

  # 2.2) substituir o bloco const [last,setLast] + useEffect(...) por useSyncExternalStore(...)
  $replacementLines = @(
    '  const last = useSyncExternalStore(',
    '    (cb) => {',
    '      if (typeof window === "undefined") return () => {};',
    '      const handler = () => cb();',
    '      window.addEventListener("storage", handler);',
    '      window.addEventListener("cv:last", handler as unknown as EventListener);',
    '      return () => {',
    '        window.removeEventListener("storage", handler);',
    '        window.removeEventListener("cv:last", handler as unknown as EventListener);',
    '      };',
    '    },',
    '    () => {',
    '      try {',
    '        return localStorage.getItem(key) || "";',
    '      } catch {',
    '        return "";',
    '      }',
    '    },',
    '    () => ""',
    '  );',
    ''
  )
  $replacement = ($replacementLines -join "`r`n")

  $pattern = 'const\s*\[\s*last\s*,\s*setLast\s*\]\s*=\s*(?:React\.)?useState\([^;]*\);\s*(?:\r?\n)+\s*(?:React\.)?useEffect\(\s*\(\s*\)\s*=>\s*\{[\s\S]*?\}\s*,\s*\[\s*key\s*\]\s*\)\s*;\s*'
  $re = New-Object System.Text.RegularExpressions.Regex($pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
  $out2 = $re.Replace($out, $replacement, 1)

  # se não casou (código diferente), pelo menos remove setLast do destructuring se não houver setLast(
  if ($out2 -eq $out) {
    if ($out2 -match 'const\s*\[\s*last\s*,\s*setLast\s*\]\s*=') {
      if ($out2.IndexOf('setLast(', [System.StringComparison]::Ordinal) -lt 0) {
        $out2 = [regex]::Replace($out2, 'const\s*\[\s*last\s*,\s*setLast\s*\]\s*=\s*', 'const [last] = ', 1)
      }
    }
  }

  return $out2
}

# 3) /c/[slug]/page.tsx — usar uiDefault e redirect (tira warnings e ativa default)
PatchText "src\app\c\[slug]\page.tsx" {
  param($s)
  $out = $s

  if ($out.IndexOf('uiDefault === "v2"', [System.StringComparison]::Ordinal) -ge 0 -and $out.IndexOf('redirect("/c/" + slug + "/v2")', [System.StringComparison]::Ordinal) -ge 0) {
    return $out
  }

  $m = [regex]::Match($out, '(?s)(const\s+uiDefault\s*=\s*[^;]+;\s*)')
  if (!$m.Success) {
    return $out
  }

  $ins = @(
    'if (uiDefault === "v2") {',
    '  redirect("/c/" + slug + "/v2");',
    '}',
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
$rep.Add("# CV — Fix — MapaV2 + HomeV2Hub + uiDefault redirect (v0_87)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que foi corrigido") | Out-Null
$rep.Add("- MapaV2: garante map com (n, idx) quando usa idx e remove index do segundo map quando sobra.") | Out-Null
$rep.Add("- HomeV2Hub: remove setState em effect e usa useSyncExternalStore para ler last do localStorage.") | Out-Null
$rep.Add('- /c/[slug]: aplica redirect quando uiDefault === "v2" (usa redirect/uiDefault e remove warnings).') | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null

$rp = WriteReport "cv-fix-mapv2-homev2hub-uidefault-v0_87.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Fix aplicado e verificado."