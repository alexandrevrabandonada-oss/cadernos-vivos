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

# -----------------------------------------
# Fix: trocar "if (uiDefault === 'v2')" por cálculo seguro do valor (uiDefault pode ser função)
# -----------------------------------------
PatchText "src\app\c\[slug]\page.tsx" {
  param($s)
  $out = $s

  if ($out.IndexOf('const ui = (typeof uiDefault === "function")') -ge 0) { return $out }

  $idx = $out.IndexOf('if (uiDefault === "v2")')
  if ($idx -lt 0) { return $out }

  # do 'if' até o próximo '}' (suficiente para esse if simples)
  $end = $out.IndexOf("}", $idx)
  if ($end -lt 0) { return $out }
  $end = $end + 1

  # indent do if
  $ls = $out.LastIndexOf("`n", $idx)
  if ($ls -lt 0) { $ls = 0 } else { $ls = $ls + 1 }
  $le = $out.IndexOf("`n", $ls)
  if ($le -lt 0) { $le = $out.Length }
  $line = $out.Substring($ls, $le - $ls)
  $indent = ([regex]::Match($line, '^\s*')).Value

  $replacement = @(
    $indent + 'const ui = (typeof uiDefault === "function")'
    $indent + '  ? (uiDefault as unknown as (m: unknown) => string)(data.meta)'
    $indent + '  : (uiDefault as unknown as string);'
    ''
    $indent + 'if (ui === "v2") {'
    $indent + '  redirect("/c/" + slug + "/v2");'
    $indent + '}'
  ) -join "`r`n"

  return ($out.Substring(0, $idx) + $replacement + $out.Substring($end))
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Fix — root redirect uiDefault function-safe (v0_112)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que foi corrigido") | Out-Null
$rep.Add("- /c/[slug]/page.tsx: uiDefault pode ser funcao; calculamos ui e comparamos com ""v2"" (corrige TypeScript).") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null
$rp = WriteReport "cv-fix-root-redirect-uidefault-fn-v0_112.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Fix aplicado e verificado."