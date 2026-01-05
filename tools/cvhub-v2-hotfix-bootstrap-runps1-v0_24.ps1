# CV — Hotfix Infra — Add RunPs1 helper + patch D5 verify call — v0_24
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

$repo = Get-Location
$bootPath = Join-Path $repo "tools\_bootstrap.ps1"
if (-not (Test-Path -LiteralPath $bootPath)) { throw "[STOP] tools/_bootstrap.ps1 não encontrado." }

. $bootPath
Write-Host ("[DIAG] Repo: " + $repo)
Write-Host ("[DIAG] Bootstrap: " + $bootPath)

# --- PATCH 1: tools/_bootstrap.ps1 -> adicionar RunPs1 (se não existir)
$raw = Get-Content -LiteralPath $bootPath -Raw
if ([string]::IsNullOrWhiteSpace($raw)) { throw "[STOP] bootstrap vazio/nulo." }

if ($raw -notmatch "function\s+RunPs1") {
  $insertLines = @(
    "",
    "function GetPwshExe() {",
    "  `$c = Get-Command 'pwsh.exe' -ErrorAction SilentlyContinue",
    "  if (`$c) { return `$c.Source }",
    "  `$c2 = Get-Command 'pwsh' -ErrorAction SilentlyContinue",
    "  if (`$c2) { return `$c2.Source }",
    "  return 'pwsh'",
    "}",
    "",
    "function RunPs1([string]`$scriptPath, [string[]]`$scriptArgs) {",
    "  if ([string]::IsNullOrWhiteSpace(`$scriptPath)) { throw '[STOP] RunPs1: scriptPath vazio.' }",
    "  `$pwsh = GetPwshExe",
    "  `$args = @('-NoProfile','-ExecutionPolicy','Bypass','-File',`$scriptPath)",
    "  if (`$scriptArgs -and `$scriptArgs.Count -gt 0) { `$args += `$scriptArgs }",
    "  RunCmd `$pwsh `$args",
    "}"
  )

  $needle = "function GetNpmCmd"
  $pos = $raw.IndexOf($needle, [System.StringComparison]::Ordinal)
  if ($pos -ge 0) {
    $raw2 = $raw.Insert($pos, (($insertLines -join "`n") + "`n"))
  } else {
    $raw2 = $raw + "`n" + ($insertLines -join "`n") + "`n"
  }

  $bk = BackupFile $bootPath
  WriteUtf8NoBom $bootPath $raw2
  Write-Host "[OK] patched: tools/_bootstrap.ps1 (add RunPs1)"
  if ($bk) { Write-Host ("[BK] " + $bk) }

  # recarrega bootstrap para expor RunPs1
  . $bootPath
} else {
  Write-Host "[OK] bootstrap já tem RunPs1."
}

# --- PATCH 2: patchar o D5 (se existir) para não usar RunCmd com args vazio
$d5 = Join-Path $repo "tools\cvhub-v2-tijolo-d5-linha-v2-derivada-do-mapa-v0_2.ps1"
if (Test-Path -LiteralPath $d5) {
  $d5raw = Get-Content -LiteralPath $d5 -Raw
  if (-not [string]::IsNullOrWhiteSpace($d5raw)) {
    $d5raw2 = $d5raw
    $d5raw2 = $d5raw2.Replace("RunCmd (Join-Path `$repo 'tools\cv-verify.ps1') @()", "RunPs1 (Join-Path `$repo 'tools\cv-verify.ps1') @()")
    $d5raw2 = $d5raw2.Replace("RunCmd (Join-Path `$repo 'tools/cv-verify.ps1') @()", "RunPs1 (Join-Path `$repo 'tools/cv-verify.ps1') @()")

    if ($d5raw2 -ne $d5raw) {
      $bk2 = BackupFile $d5
      WriteUtf8NoBom $d5 $d5raw2
      Write-Host "[OK] patched: D5 script (RunCmd -> RunPs1)"
      if ($bk2) { Write-Host ("[BK] " + $bk2) }
    } else {
      Write-Host "[OK] D5 script: nada a trocar (talvez já corrigido)."
    }
  }
} else {
  Write-Host "[SKIP] D5 script não encontrado (ok)."
}

# --- VERIFY agora (sem args vazio)
RunPs1 (Join-Path $repo "tools\cv-verify.ps1") @()

# --- REPORT
$report = @"
# CV — Hotfix Infra v0_24 — RunPs1 + correção de verify call

## Causa raiz
- tools/_bootstrap.ps1: RunCmd exige args não-vazio.
- Alguns tijolos chamavam: RunCmd <script.ps1> @() → args vazio → STOP.

## Fix
- Adicionado helper **RunPs1(scriptPath, scriptArgs)** no tools/_bootstrap.ps1.
- Patch best-effort no D5 para usar RunPs1 ao rodar tools/cv-verify.ps1.

## Como usar daqui pra frente
- Para rodar um .ps1 via infra:
  - RunPs1 (Join-Path (Get-Location) 'tools/cv-verify.ps1') @()
- Ou no terminal:
  - pwsh -NoProfile -ExecutionPolicy Bypass -File tools/cv-verify.ps1

## Verify
- tools/cv-verify.ps1 (guard + lint + build) passou.
"@

WriteReport "cv-infra-hotfix-runps1-v0_24.md" $report | Out-Null
Write-Host "[OK] v0_24 aplicado e verificado."