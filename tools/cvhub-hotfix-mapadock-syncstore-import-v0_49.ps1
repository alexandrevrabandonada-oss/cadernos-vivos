$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Write-Host ("[DIAG] Repo: " + $repo)

. (Join-Path $PSScriptRoot "_bootstrap.ps1")

$file = Join-Path $repo "src\components\v2\MapaDockV2.tsx"
if (-not (Test-Path -LiteralPath $file)) { throw ("[STOP] nao achei: " + $file) }
Write-Host ("[DIAG] File: " + $file)

$raw = Get-Content -LiteralPath $file -Raw
$lines = $raw -split "`r?`n"

# encontra imports de react
$reactImportIdx = @()
for ($i=0; $i -lt $lines.Length; $i++) {
  if ($lines[$i] -match '^\s*import\s+.*from\s+["'']react["'']\s*;?\s*$') {
    $reactImportIdx += $i
  }
}

if ($reactImportIdx.Count -eq 0) {
  Write-Host "[DIAG] nao achei nenhum import de react; vou inserir um import nomeado."
  $insertAt = 0
  for ($j=0; $j -lt $lines.Length; $j++) {
    if ($lines[$j] -match '^\s*["'']use client["'']\s*;?\s*$') { $insertAt = $j + 1; break }
  }
  $ins = 'import { useSyncExternalStore } from "react";'
  $before = @()
  if ($insertAt -gt 0) { $before = $lines[0..($insertAt-1)] }
  $after = $lines[$insertAt..($lines.Length-1)]
  $lines = @($before + @($ins) + $after)
}
else {
  $patched = $false

  # 1) tenta patchar um import com braces (import { ... } from react) ou (import React, { ... } from react)
  foreach ($idx in $reactImportIdx) {
    $ln = $lines[$idx]

    # ignora import type (nao serve pra hook)
    if ($ln -match '^\s*import\s+type\s+') { continue }

    $hasBraces = ($ln -match '\{') -and ($ln -match '\}')
    if ($hasBraces) {
      if ($ln -match '\buseSyncExternalStore\b') {
        Write-Host "[OK] import de react ja contem useSyncExternalStore."
        $patched = $true
        break
      }

      # injeta logo apos "{"
      $lines[$idx] = [regex]::Replace($ln, '\{\s*', '{ useSyncExternalStore, ', 1)
      Write-Host ("[OK] patch: adicionou useSyncExternalStore no import react (linha " + ($idx+1) + ").")
      $patched = $true
      break
    }
  }

  # 2) se nao achou braces, cria import separado abaixo do ultimo import de react (nao-type)
  if (-not $patched) {
    # se ja existe import separado (nao-type) para useSyncExternalStore, ok
    $already = $false
    foreach ($idx in $reactImportIdx) {
      $ln = $lines[$idx]
      if (($ln -notmatch '^\s*import\s+type\s+') -and ($ln -match '\buseSyncExternalStore\b')) { $already = $true; break }
    }

    if ($already) {
      Write-Host "[OK] ja existe import nao-type contendo useSyncExternalStore."
    } else {
      $lastReact = $reactImportIdx[$reactImportIdx.Count - 1]
      $ins = 'import { useSyncExternalStore } from "react";'
      $before = $lines[0..$lastReact]
      $after = @()
      if ($lastReact -lt ($lines.Length - 1)) { $after = $lines[($lastReact+1)..($lines.Length-1)] }
      $lines = @($before + @($ins) + $after)
      Write-Host "[OK] patch: criou import separado de useSyncExternalStore abaixo do ultimo import react."
    }
  }
}

# grava se mudou
$newRaw = ($lines -join "`n")
if ($newRaw -ne $raw) {
  $bk = BackupFile $file
  WriteUtf8NoBom $file $newRaw
  Write-Host ("[OK] patched: " + $file)
  if ($bk) { Write-Host ("[BK] " + $bk) }
} else {
  Write-Host "[OK] nada pra mudar (arquivo ja estava no estado esperado)."
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT (sem backticks pra nao quebrar PowerShell)
$rep = @()
$rep += "# CV — Hotfix v0_49 — MapaDockV2 import useSyncExternalStore"
$rep += ""
$rep += "## Causa"
$rep += "- useSyncExternalStore era usado no MapaDockV2.tsx sem estar disponivel como value (import ausente/nao-type)."
$rep += ""
$rep += "## Fix"
$rep += "- Garante import nao-type de useSyncExternalStore a partir de react."
$rep += ""
$rep += "## Arquivo"
$rep += "- src/components/v2/MapaDockV2.tsx"
$rep += ""
$rep += "## Verify"
$rep += "- tools/cv-verify.ps1 (guard + lint + build)"
$rep += ""

$rp = WriteReport "cv-hotfix-mapadock-syncstore-import-v0_49.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Hotfix v0_49 aplicado e verificado."