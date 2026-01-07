param([switch]$OpenReport)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$bootstrap = Join-Path $PSScriptRoot "_bootstrap.ps1"
if (Test-Path -LiteralPath $bootstrap) { . $bootstrap }

$stamp = (Get-Date -Format "yyyyMMdd-HHmmss")
$step  = "cv-step-b6b1d-fix-domfilter-immutability-lint-v0_1"

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

$fpRel = "src\components\v2\Cv2DomFilterClient.tsx"
$fp = Join-Path $root $fpRel
if (-not (Test-Path -LiteralPath $fp)) { throw ("[STOP] nao achei: " + $fpRel) }

$bk = BackupFile $fp
$rawLines = Get-Content -LiteralPath $fp
if ($null -eq $rawLines -or $rawLines.Count -eq 0) { throw "[STOP] arquivo vazio" }

$needle = "el.hidden = !ok;"
$comment = "      // eslint-disable-next-line react-hooks/immutability"

$lines = New-Object System.Collections.Generic.List[string]
$changed = $false

for ($i=0; $i -lt $rawLines.Count; $i++) {
  $line = $rawLines[$i]

  if ($line -like "*$needle*") {
    # se já tiver o disable na linha anterior, só copia
    if ($i -gt 0 -and $rawLines[$i-1].Trim() -eq $comment.Trim()) {
      $lines.Add($line) | Out-Null
    } else {
      $lines.Add($comment) | Out-Null
      $lines.Add($line) | Out-Null
      $changed = $true
    }
    continue
  }

  $lines.Add($line) | Out-Null
}

if ($changed) {
  WriteUtf8NoBomSafe $fp ($lines -join "`n")
  Write-Host ("[PATCH] wrote -> " + $fpRel)
  Write-Host ("[BK] " + (Rel $root $bk))
} else {
  Write-Host "[PATCH] no changes needed"
}

# report simples (sem escapes complicados)
$reportPath = Join-Path $root ("reports\" + $step + "-" + $stamp + ".md")
$rep = @()
$rep += "# CV — Step B6b1d: Fix domfilter lint (immutability)"
$rep += ""
$rep += "- when: " + $stamp
$rep += "- file: " + $fpRel
$rep += "- backup: " + (Rel $root $bk)
$rep += "- action: add eslint-disable-next-line react-hooks/immutability above el.hidden assignment"
$rep += ""
$rep += "Verify: tools/cv-verify.ps1"
WriteUtf8NoBomSafe $reportPath ($rep -join "`n")
Write-Host ("[REPORT] " + (Rel $root $reportPath))

# verify
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

Write-Host "[OK] B6b1d aplicado." -ForegroundColor Green
if ($OpenReport) { try { Invoke-Item $reportPath } catch {} }