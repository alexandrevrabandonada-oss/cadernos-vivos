$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Write-Host ("[DIAG] Repo: " + $repo)

. (Join-Path $PSScriptRoot "_bootstrap.ps1")

$changed = New-Object System.Collections.Generic.List[string]

function PatchText([string]$rel, [scriptblock]$mutate) {
  $full = Join-Path $repo $rel
  if (!(Test-Path -LiteralPath $full)) { throw ("[STOP] nao achei: " + $full) }
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

# 1) /c/[slug] — usar uiDefault de verdade + remover Link unused
PatchText "src\app\c\[slug]\page.tsx" {
  param($raw)
  $s = $raw

  # Remove import Link (tava unused)
  $lines = $s -split "`r`n"
  $out = New-Object System.Collections.Generic.List[string]
  foreach ($ln in $lines) {
    if ($ln -match '^\s*import\s+Link\s+from\s+"next/link";\s*$') { continue }
    $out.Add($ln) | Out-Null
  }
  $s = ($out -join "`r`n")

  # Garante redirect import no next/navigation
  $m = [regex]::Match($s, 'import\s+\{\s*([^}]+)\s*\}\s+from\s+"next/navigation";')
  if ($m.Success) {
    $inside = $m.Groups[1].Value
    $parts = $inside.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    $hasRedirect = $false
    foreach ($p in $parts) { if ($p -eq "redirect") { $hasRedirect = $true } }
    if (!$hasRedirect) {
      $newInside = (($parts + @("redirect")) -join ", ")
      $newImport = 'import { ' + $newInside + ' } from "next/navigation";'
      $s = $s.Substring(0, $m.Index) + $newImport + $s.Substring($m.Index + $m.Length)
    }
  }

  # Se uiDefault existe e redirect ainda nao é usado, inserir comportamento
  if ($s -notmatch 'redirect\s*\(') {
    $lines2 = $s -split "`r`n"
    $out2 = New-Object System.Collections.Generic.List[string]
    $inserted = $false
    foreach ($ln in $lines2) {
      $out2.Add($ln) | Out-Null
      if (!$inserted -and $ln -match '^\s*const\s+uiDefault\s*=') {
        $out2.Add('') | Out-Null
        $out2.Add('  // UI default: se meta.ui.default = "v2", cai direto no V2') | Out-Null
        $out2.Add('  if (uiDefault === "v2") {') | Out-Null
        $out2.Add('    redirect("/c/" + slug + "/v2");') | Out-Null
        $out2.Add('  }') | Out-Null
        $out2.Add('') | Out-Null
        $inserted = $true
      }
    }
    $s = ($out2 -join "`r`n")
  }

  return $s
}

# 2) /c/[slug]/v2/linha — remover import type JsonValue (unused warning)
PatchText "src\app\c\[slug]\v2\linha\page.tsx" {
  param($raw)
  $s = $raw
  $lines = $s -split "`r`n"
  $out = New-Object System.Collections.Generic.List[string]
  foreach ($ln in $lines) {
    if ($ln -match '^\s*import\s+type\s+\{\s*JsonValue\s*\}\s+from\s+"@/lib/v2";\s*$') { continue }
    $out.Add($ln) | Out-Null
  }
  return ($out -join "`r`n")
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Fix — ui.default redirect + warnings (v0_69)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que foi ajustado") | Out-Null
$rep.Add('- /c/[slug]: usa uiDefault e faz redirect para /v2 quando meta.ui.default="v2".') | Out-Null
$rep.Add("- Remove import Link que estava sobrando.") | Out-Null
$rep.Add("- /v2/linha: remove import JsonValue que estava sobrando.") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null

$rp = WriteReport "cv-fix-ui-default-redirect-and-warnings-v0_69.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Fix aplicado e verificado."