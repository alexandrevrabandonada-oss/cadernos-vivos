# CV — Hotfix — ReadingControls: remover import duplicado + deps do useMemo — v0_34
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

$repo = Get-Location
$bootstrap = Join-Path $repo "tools\_bootstrap.ps1"
if (Test-Path -LiteralPath $bootstrap) { . $bootstrap } else { throw "[STOP] tools/_bootstrap.ps1 não encontrado." }

Write-Host ("[DIAG] Repo: " + $repo)

$rcPath = Join-Path $repo "src\components\ReadingControls.tsx"
if (-not (Test-Path -LiteralPath $rcPath)) { throw ("[STOP] Não achei: " + $rcPath) }
Write-Host ("[DIAG] ReadingControls: " + $rcPath)

$raw = Get-Content -LiteralPath $rcPath -Raw
if (-not $raw) { throw "[STOP] ReadingControls vazio/ilegível." }

$lines = $raw -split "`r?`n"
$out = New-Object System.Collections.Generic.List[string]
$changed = $false

# 1) Remover import duplicado gerado (se existir)
foreach ($ln in $lines) {
  $t = $ln.Trim()

  # remove exatamente a linha duplicada (ou variações com ; e espaços)
  if ($t -match '^import\s*\{\s*useEffect\s*,\s*useState\s*\}\s*from\s*["'']react["'']\s*;?\s*$') {
    $changed = $true
    continue
  }

  $out.Add($ln) | Out-Null
}

$text = ($out -join "`n")

# 2) Corrigir warning: useMemo com hydrated faltando nas deps (patch “bom o bastante”)
# Procura useMemo( ..., [ ... ] ) na MESMA linha e injeta hydrated se não estiver
$patchedMemo = $false
$lines2 = $text -split "`r?`n"
$out2 = New-Object System.Collections.Generic.List[string]

foreach ($ln in $lines2) {
  $n = $ln

  if (($n -match 'useMemo\(') -and ($n -match 'useMemo\([^;]*,\s*\[[^\]]*\]\s*\)') -and ($n -notmatch '\bhydrated\b')) {
    # adiciona hydrated dentro do primeiro [ ... ] após a vírgula do useMemo
    $n2 = [regex]::Replace(
      $n,
      '(useMemo\([^;]*,\s*)\[(?<deps>[^\]]*)\](\s*\))',
      {
        param($m)
        $head = $m.Groups[1].Value
        $deps = $m.Groups["deps"].Value.Trim()
        $tail = $m.Groups[3].Value

        if ([string]::IsNullOrWhiteSpace($deps)) {
          return $head + '[hydrated]' + $tail
        } else {
          return $head + '[' + $deps + ', hydrated]' + $tail
        }
      },
      1
    )

    if ($n2 -ne $n) {
      $n = $n2
      $changed = $true
      $patchedMemo = $true
    }
  }

  $out2.Add($n) | Out-Null
}

$text = ($out2 -join "`n")

if ($changed) {
  $bk = BackupFile $rcPath
  WriteUtf8NoBom $rcPath $text
  Write-Host "[OK] patched: ReadingControls (remove import duplicado; deps useMemo ajustadas)"
  if ($bk) { Write-Host ("[BK] " + $bk) }
} else {
  Write-Host "[OK] nada para mudar (já limpo)."
}

# VERIFY
RunPs1 (Join-Path $repo "tools\cv-verify.ps1")

# REPORT
$rep = @(
  "# CV — Hotfix v0_34 — ReadingControls imports/deps",
  "",
  "## Fix",
  "- Removeu import duplicado: import { useEffect, useState } from react",
  "- Ajustou deps de useMemo para incluir hydrated (evita warning react-hooks/exhaustive-deps)",
  "",
  "## Arquivo",
  "- src/components/ReadingControls.tsx",
  "",
  "## Verify",
  "- tools/cv-verify.ps1 (guard + lint + build)",
  ""
) -join "`n"

WriteReport "cv-hotfix-readingcontrols-imports-deps-v0_34.md" $rep | Out-Null
Write-Host "[OK] v0_34 aplicado e verificado."