# CV — V2 Hotfix — MapaDockV2: restaurar onHash (build error) — v0_38
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

$repo = Get-Location
$bootstrap = Join-Path $repo "tools\_bootstrap.ps1"
if (-not (Test-Path -LiteralPath $bootstrap)) { throw "[STOP] tools/_bootstrap.ps1 não encontrado." }
. $bootstrap

Write-Host ("[DIAG] Repo: " + $repo)

$dockPath = Join-Path $repo "src\components\v2\MapaDockV2.tsx"
if (-not (Test-Path -LiteralPath $dockPath)) { throw ("[STOP] Não achei: " + $dockPath) }
Write-Host ("[DIAG] Dock: " + $dockPath)

$raw = Get-Content -LiteralPath $dockPath -Raw

# Se já tiver onHash definido, não faz nada.
if ($raw -match "const\s+onHash\s*=\s*\(\)\s*=>") {
  Write-Host "[OK] onHash já existe — nada a fazer."
} else {
  $lines = $raw -split "`r?`n"
  $out = New-Object System.Collections.Generic.List[string]
  $changed = $false

  foreach ($ln in $lines) {
    if ($ln -match "addEventListener\(`"hashchange`",\s*onHash\)") {
      $indent = ""
      if ($ln -match "^(\s*)") { $indent = $Matches[1] }

      # Insere a definição ANTES do addEventListener
      $out.Add($indent + 'const onHash = () => setSelectedId(readHashId());')
      $out.Add($ln)
      $changed = $true
      continue
    }

    $out.Add($ln)
  }

  if (-not $changed) {
    Write-Host "[WARN] Não achei addEventListener(""hashchange"", onHash). Talvez o arquivo mudou."
  } else {
    $bk = BackupFile $dockPath
    WriteUtf8NoBom $dockPath ($out -join "`n")
    Write-Host "[OK] patched: MapaDockV2.tsx (reinseriu const onHash ...)"
    if ($bk) { Write-Host ("[BK] " + $bk) }
  }
}

# VERIFY
RunPs1 (Join-Path $repo "tools\cv-verify.ps1") @()

# REPORT
$report = @(
  "# CV — Hotfix v0_38 — MapaDockV2: onHash restore",
  "",
  "## Causa",
  "- Script anterior removeu a definição de onHash, mas manteve addEventListener(..., onHash), quebrando build.",
  "",
  "## Fix",
  "- Reinseriu: const onHash = () => setSelectedId(readHashId()); antes do addEventListener('hashchange', onHash).",
  "",
  "## Verify",
  "- tools/cv-verify.ps1 (Guard → Lint → Build)",
  ""
) -join "`n"
WriteReport "cv-v2-hotfix-mapadock-onhash-v0_38.md" $report | Out-Null

Write-Host "[OK] v0_38 aplicado e verificado."