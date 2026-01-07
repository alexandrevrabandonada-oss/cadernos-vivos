param([switch]$OpenReport)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$bootstrap = Join-Path $PSScriptRoot "_bootstrap.ps1"
if (Test-Path -LiteralPath $bootstrap) { . $bootstrap }

$stamp = (Get-Date -Format "yyyyMMdd-HHmmss")
$step  = "cv-step-b6b1c2-fix-domfilter-skip-string-v0_1"

function EnsureDirLocal([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}
function Rel([string]$base, [string]$full) {
  try { return [System.IO.Path]::GetRelativePath($base, $full) } catch { return $full }
}
function WriteUtf8NoBomSafe([string]$p, [string]$content) {
  if (Get-Command WriteUtf8NoBom -ErrorAction SilentlyContinue) { WriteUtf8NoBom $p $content; return }
  [IO.File]::WriteAllText($p, $content, [Text.UTF8Encoding]::new($false))
}

Write-Host ("== " + $step + " == " + $stamp) -ForegroundColor Cyan
Write-Host ("[DIAG] Root: " + $root)

EnsureDirLocal (Join-Path $root "reports")
EnsureDirLocal (Join-Path $root "tools\_patch_backup")

$domPath = Join-Path $root "src\components\v2\Cv2DomFilterClient.tsx"
if (-not (Test-Path -LiteralPath $domPath)) { throw ("[STOP] nao achei: " + (Rel $root $domPath)) }

$bk = BackupFile $domPath
$raw = Get-Content -Raw -LiteralPath $domPath
if ($null -eq $raw -or $raw.Trim().Length -eq 0) { throw "[STOP] arquivo vazio" }

# troca qualquer "const skip = ....;" por uma linha segura
$replacement = "  const skip = '[data-cv2-filter-ui=""1""]';"
$patched = [regex]::Replace(
  $raw,
  '(?m)^\s*const\s+skip\s*=\s*.+?;\s*$',
  $replacement
)

# fallback extra: se existir a string quebrada literal, corrige também
$patched = $patched.Replace('"[data-cv2-filter-ui=\\"1\\"]"', "'[data-cv2-filter-ui=""1""]'")

if ($patched -ne $raw) {
  WriteUtf8NoBomSafe $domPath $patched
  Write-Host ("[PATCH] wrote -> " + (Rel $root $domPath))
  Write-Host ("[BK] " + (Rel $root $bk))
} else {
  Write-Host "[PATCH] no changes needed"
}

# report simples (sem escapes chatos)
$reportPath = Join-Path $root ("reports\" + $step + "-" + $stamp + ".md")
$rep = @()
$rep += "# CV — Step B6b1c2: Fix domfilter skip selector string"
$rep += ""
$rep += "- when: " + $stamp
$rep += "- file: " + (Rel $root $domPath)
$rep += "- backup: " + (Rel $root $bk)
$rep += "- action: set skip selector to [data-cv2-filter-ui=""1""] using single-quoted TS string"
$rep += ""
$rep += "Verify: tools/cv-verify.ps1"
WriteUtf8NoBomSafe $reportPath ($rep -join "`n")
Write-Host ("[REPORT] " + (Rel $root $reportPath))

$verify = Join-Path $root "tools\cv-verify.ps1"
if (Test-Path -LiteralPath $verify) {
  Write-Host ("[RUN] " + (Rel $root $verify))
  & pwsh -NoProfile -ExecutionPolicy Bypass -File $verify
} else {
  Write-Host "[RUN] npm run lint"
  & npm run lint
  Write-Host "[RUN] npm run build"
  & npm run build
}

Write-Host "[OK] B6b1c2 aplicado." -ForegroundColor Green
if ($OpenReport) { try { Invoke-Item $reportPath } catch {} }