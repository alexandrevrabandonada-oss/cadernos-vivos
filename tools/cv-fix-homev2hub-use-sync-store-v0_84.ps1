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

function AddNamedImport([string]$inner, [string]$name) {
  $parts = @()
  foreach ($p in ($inner -split ",")) {
    $t = ($p.Trim())
    if ($t) { $parts += $t }
  }
  if ($parts -contains $name) { return ($parts -join ", ") }
  $parts += $name
  return ($parts -join ", ")
}

PatchText "src\components\v2\HomeV2Hub.tsx" {
  param($s)
  $out = $s

  # já aplicado?
  if ($out.IndexOf("const last = useSyncExternalStore") -ge 0) { return $out }

  # 1) Garantir import de useSyncExternalStore
  $m1 = [regex]::Match($out, 'import\s+React\s*,\s*\{(?<inner>[^}]*)\}\s+from\s+"react";')
  if ($m1.Success) {
    $inner = $m1.Groups["inner"].Value
    $newInner = AddNamedImport $inner "useSyncExternalStore"
    $newLine = 'import React, {' + $newInner + '} from "react";'
    $out = $out.Substring(0, $m1.Index) + $newLine + $out.Substring($m1.Index + $m1.Length)
  } else {
    $m2 = [regex]::Match($out, 'import\s*\{(?<inner>[^}]*)\}\s+from\s+"react";')
    if ($m2.Success) {
      $inner2 = $m2.Groups["inner"].Value
      $newInner2 = AddNamedImport $inner2 "useSyncExternalStore"
      $newLine2 = 'import {' + $newInner2 + '} from "react";'
      $out = $out.Substring(0, $m2.Index) + $newLine2 + $out.Substring($m2.Index + $m2.Length)
    }
  }

  # 2) Substituir `const [last, setLast] = useState(...)` por `const last = useSyncExternalStore(...)`
  $replLines = @(
    '  const last = useSyncExternalStore(',
    '    (cb) => {',
    '      if (typeof window === "undefined") return () => {};',
    '      const handler: EventListener = () => cb();',
    '      window.addEventListener("storage", handler);',
    '      window.addEventListener("cv:last", handler);',
    '      return () => {',
    '        window.removeEventListener("storage", handler);',
    '        window.removeEventListener("cv:last", handler);',
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
  $replacement = ($replLines -join "`r`n")

  $patState = 'const\s*\[\s*last\s*,\s*setLast\s*\]\s*=\s*(?:React\.)?useState\([^;]*\);\s*'
  $out2 = [regex]::Replace($out, $patState, $replacement)

  # 3) Remover o useEffect que chama setLast(...), pra não cair na regra react-hooks/set-state-in-effect
  $patEff = 'useEffect\(\s*\(\s*\)\s*=>\s*\{[\s\S]*?setLast\s*\([\s\S]*?\)\s*;[\s\S]*?\}\s*,\s*\[\s*key\s*\]\s*\)\s*;\s*'
  $out3 = [regex]::Replace($out2, $patEff, "")

  # sanity: não pode sobrar setLast
  if ($out3 -match '\bsetLast\s*\(') {
    throw "[STOP] Ainda sobrou setLast(...) em HomeV2Hub.tsx — preciso ajustar o patch pra esse formato."
  }

  return $out3
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Fix — HomeV2Hub useSyncExternalStore (v0_84)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que foi corrigido") | Out-Null
$rep.Add("- Removeu setState dentro de useEffect em HomeV2Hub; agora last vem de localStorage via useSyncExternalStore.") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null

$rp = WriteReport "cv-fix-homev2hub-use-sync-store-v0_84.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Fix aplicado e verificado."