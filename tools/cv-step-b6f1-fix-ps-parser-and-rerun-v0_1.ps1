param(
  [switch]$OpenReport
)

$ErrorActionPreference = "Stop"

function WriteUtf8NoBomLocal([string]$filePath, [string]$content) {
  $enc = New-Object System.Text.UTF8Encoding($false)
  $dir = Split-Path -Parent $filePath
  if ($dir -and !(Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [IO.File]::WriteAllText($filePath, $content, $enc)
}

function RelLocal([string]$root, [string]$fullPath) {
  try {
    $rp = (Resolve-Path -LiteralPath $fullPath).Path
    $rr = $root.TrimEnd("\","/")
    if ($rp.StartsWith($rr)) { return $rp.Substring($rr.Length).TrimStart("\","/") }
    return $rp
  } catch { return $fullPath }
}

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$targetRel = "tools\cv-step-b6f-v2-provas-grouped-stabilize-v0_1.ps1"
$target = Join-Path $root $targetRel

Write-Host ("== B6f1 fix parser == " + (Get-Date).ToString("yyyyMMdd-HHmmss"))
Write-Host ("[DIAG] Root: " + $root)

if (!(Test-Path -LiteralPath $target)) {
  throw ("[STOP] não achei o B6f v0_1 em: " + $targetRel)
}

$raw = Get-Content -Raw -LiteralPath $target

# troca a linha que quebra o parser (aspas com \")
$needle = '$rep += "- Garante wrapper data-cv2-provas-list=\"1\" ao redor do ProvasV2."'
$replacement = '$rep += ''- Garante wrapper data-cv2-provas-list="1" ao redor do ProvasV2.'''

$patched = $raw.Replace($needle, $replacement)

if ($patched -eq $raw) {
  # fallback: tenta achar qualquer linha do $rep que contenha data-cv2-provas-list=\"1\"
  $lines = $raw -split "`r?`n"
  $out = @()
  $changed = $false
  foreach ($ln in $lines) {
    if (!$changed -and $ln -match '^\s*\$rep\s*\+=\s*".*data-cv2-provas-list=\\\"1\\\".*"\s*$') {
      $out += $replacement
      $changed = $true
    } else {
      $out += $ln
    }
  }
  $patched = ($out -join "`n")
  if (!$changed) {
    Write-Host "[WARN] Não encontrei a linha exata pra trocar, mas vou seguir e tentar rodar mesmo assim."
  } else {
    Write-Host "[OK] Linha do REPORT corrigida (fallback)."
  }
} else {
  Write-Host "[OK] Linha do REPORT corrigida."
}

WriteUtf8NoBomLocal $target $patched
Write-Host ("[PATCH] wrote -> " + (RelLocal $root $target))

# re-run do B6f v0_1 agora que ele parseia
Write-Host ("[RUN] " + (RelLocal $root $target))
if ($OpenReport) {
  pwsh -NoProfile -ExecutionPolicy Bypass -File $target -OpenReport
} else {
  pwsh -NoProfile -ExecutionPolicy Bypass -File $target
}