$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Write-Host ("[DIAG] Repo: " + $repo)

. (Join-Path $PSScriptRoot "_bootstrap.ps1")

$file = Join-Path $repo "src\components\v2\MapaDockV2.tsx"
if (-not (Test-Path -LiteralPath $file)) { throw ("[STOP] nao achei: " + $file) }
Write-Host ("[DIAG] File: " + $file)

$raw = Get-Content -LiteralPath $file -Raw
if ($raw -notmatch "\buseSyncExternalStore\b") {
  throw "[STOP] useSyncExternalStore nao aparece no arquivo (talvez mudou o alvo?)."
}

# já tem import?
if ($raw -match "(?s)from\s+[`"']react[`"']\s*;.*\buseSyncExternalStore\b") {
  Write-Host "[OK] ja parece importar useSyncExternalStore."
} else {
  $lines = $raw -split "`r?`n"
  $changed = $false
  $foundReactImport = $false

  for ($i=0; $i -lt $lines.Length; $i++) {
    $ln = $lines[$i]

    if ($ln -match 'from\s+["'']react["'']\s*;?\s*$') {
      $foundReactImport = $true
      if ($ln -notmatch '\buseSyncExternalStore\b') {
        if ($ln -match '\{') {
          # injeta logo após "{"
          $lines[$i] = [regex]::Replace($ln, '\{\s*', '{ useSyncExternalStore, ', 1)
          $changed = $true
          Write-Host "[OK] patch: adicionou useSyncExternalStore no import de react (linha unica)."
        } else {
          # não tem braces -> adiciona nova linha de import logo abaixo
          $before = $lines[0..$i]
          $after = @()
          if ($i -lt ($lines.Length - 1)) { $after = $lines[($i+1)..($lines.Length-1)] }

          $ins = 'import { useSyncExternalStore } from "react";'
          $lines = @($before + @($ins) + $after)
          $changed = $true
          Write-Host "[OK] patch: adicionou import separado de useSyncExternalStore."
        }
      } else {
        Write-Host "[OK] react import ja contem useSyncExternalStore."
      }
      break
    }
  }

  if (-not $foundReactImport) {
    # fallback: coloca import depois do "use client" se existir, senão no topo
    $insertAt = 0
    for ($j=0; $j -lt $lines.Length; $j++) {
      if ($lines[$j] -match '^\s*["'']use client["'']\s*;?\s*$') { $insertAt = $j + 1; break }
    }

    $ins = 'import { useSyncExternalStore } from "react";'
    $before = @()
    if ($insertAt -gt 0) { $before = $lines[0..($insertAt-1)] }
    $after = $lines[$insertAt..($lines.Length-1)]
    $lines = @($before + @($ins) + $after)
    $changed = $true
    Write-Host "[OK] patch: fallback import inserido (nao achei import react)."
  }

  if ($changed) {
    $bk = BackupFile $file
    WriteUtf8NoBom $file ($lines -join "`n")
    Write-Host ("[OK] patched: " + $file)
    if ($bk) { Write-Host ("[BK] " + $bk) }
  } else {
    Write-Host "[OK] Nada pra mudar."
  }
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = @()
$rep += "# CV — Hotfix v0_48 — Import useSyncExternalStore no MapaDockV2"
$rep += ""
$rep += "## Causa"
$rep += "- useSyncExternalStore estava sendo usado no MapaDockV2.tsx sem import do react."
$rep += ""
$rep += "## Fix"
$rep += "- Injeta useSyncExternalStore no import de react (ou cria import separado)."
$rep += ""
$rep += "## Arquivo"
$rep += "- src/components/v2/MapaDockV2.tsx"
$rep += ""
$rep += "## Verify"
$rep += "- tools/cv-verify.ps1 (guard + lint + build)"
$rep += ""

$rp = WriteReport "cv-hotfix-mapadock-import-syncstore-v0_48.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Hotfix v0_48 aplicado e verificado."