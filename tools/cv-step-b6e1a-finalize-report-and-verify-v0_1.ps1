param(
  [switch]$OpenReport
)

$ErrorActionPreference = "Stop"

# Root robusto
$here = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($here)) { $here = (Get-Location).Path }

$root = $null
try { $root = (Resolve-Path (Join-Path $here "..")).Path } catch { $root = (Get-Location).Path }
if (!(Test-Path -LiteralPath (Join-Path $root "package.json"))) { $root = (Get-Location).Path }

function EnsureDir([string]$p) {
  if ([string]::IsNullOrWhiteSpace($p)) { return }
  if (!(Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

function WriteUtf8NoBom([string]$path, [string]$content) {
  $enc = New-Object System.Text.UTF8Encoding($false)
  [IO.File]::WriteAllText($path, $content, $enc)
}

function Rel([string]$rootPath, [string]$fullPath) {
  try {
    $rp = (Resolve-Path -LiteralPath $fullPath).Path
    $rr = $rootPath.TrimEnd("\","/")
    if ($rp.StartsWith($rr)) { return $rp.Substring($rr.Length).TrimStart("\","/") }
    return $rp
  } catch { return $fullPath }
}

$stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
$step  = "cv-step-b6e1a-finalize-report-and-verify-v0_1"

Write-Host ("== " + $step + " == " + $stamp)
Write-Host ("[DIAG] Root: " + $root)

# REPORT
$repDir = Join-Path $root "reports"
EnsureDir $repDir

$reportPath = Join-Path $repDir ($step + "-" + $stamp + ".md")

$rep = @()
$rep += "# CV — B6e1 finalize: report + verify"
$rep += ""
$rep += ("- when: " + $stamp)
$rep += "- status: B6e1 aplicou patches; falhou só no NewReport (bootstrap)."
$rep += ""
$rep += "## Arquivos do B6e1"
$rep += "- src/components/v2/Cv2ProvasGroupedClient.tsx"
$rep += "- src/app/c/[slug]/v2/provas/page.tsx"
$rep += ""
$rep += "## VERIFY"
$rep += "- tools/cv-verify.ps1 (guard + lint + build)"

WriteUtf8NoBom $reportPath ($rep -join "`n")
Write-Host ("[REPORT] " + (Rel $root $reportPath))

# VERIFY
$verify = Join-Path $root "tools\cv-verify.ps1"
if (Test-Path -LiteralPath $verify) {
  Write-Host "[RUN] tools\cv-verify.ps1"
  & $verify
} else {
  Write-Host "[WARN] tools\cv-verify.ps1 não encontrado — pulei verify"
}

Write-Host "[OK] B6e1a finalizado."
if ($OpenReport) { try { Invoke-Item $reportPath } catch { } }