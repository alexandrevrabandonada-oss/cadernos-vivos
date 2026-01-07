param([switch]$OpenReport)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path

$boot = Join-Path $PSScriptRoot "_bootstrap.ps1"
if (Test-Path -LiteralPath $boot) { . $boot }

function EnsureDirSafe([string]$p) {
  if (Get-Command EnsureDir -ErrorAction SilentlyContinue) { EnsureDir $p; return }
  if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}
function WriteUtf8NoBomSafe([string]$p, [string]$content) {
  if (Get-Command WriteUtf8NoBom -ErrorAction SilentlyContinue) { WriteUtf8NoBom $p $content; return }
  [IO.File]::WriteAllText($p, $content, [Text.UTF8Encoding]::new($false))
}
function BackupFileSafe([string]$p) {
  if (Get-Command BackupFile -ErrorAction SilentlyContinue) { return (BackupFile $p) }
  $bkDir = Join-Path $root "tools\_patch_backup"
  EnsureDirSafe $bkDir
  $stamp = (Get-Date -Format "yyyyMMdd-HHmmss")
  $bk = Join-Path $bkDir ($stamp + "-" + (Split-Path -Leaf $p) + ".bak")
  Copy-Item -LiteralPath $p -Destination $bk -Force
  return $bk
}

$stamp = (Get-Date -Format "yyyyMMdd-HHmmss")
$step  = "cv-step-b6d1-fix-domfilter-named-export-and-deps-v0_1"

Write-Host ("== " + $step + " == " + $stamp) -ForegroundColor Cyan
Write-Host ("[DIAG] Root: " + $root)

EnsureDirSafe (Join-Path $root "reports")
EnsureDirSafe (Join-Path $root "tools\_patch_backup")

$compRel = "src\components\v2\Cv2DomFilterClient.tsx"
$comp = Join-Path $root $compRel
if (-not (Test-Path -LiteralPath $comp)) { throw ("[STOP] nao achei: " + $compRel) }

$bk = BackupFileSafe $comp
$raw = Get-Content -Raw -LiteralPath $comp
if ($null -eq $raw -or $raw.Trim().Length -eq 0) { throw "[STOP] arquivo vazio" }

$patched = $raw

# 1) reduzir warning: skipSelector vira useMemo + entra nos deps
$from1 = '  const skipSelector = props.skipSelector || "[data-cv2-filter-ui=1]";'
$to1   = '  const skipSelector = useMemo(() => props.skipSelector || "[data-cv2-filter-ui=1]", [props.skipSelector]);'
if ($patched.Contains($from1)) { $patched = $patched.Replace($from1, $to1) }

$from2 = '  }, [props.rootId, props.itemSelector, props.skipSelector, qFold, activeDomain]);'
$to2   = '  }, [props.rootId, props.itemSelector, props.skipSelector, qFold, activeDomain, skipSelector]);'
if ($patched.Contains($from2)) { $patched = $patched.Replace($from2, $to2) }

# 2) compat: re-export default como named (pra manter import { Cv2DomFilterClient } funcionando)
$aliasLine = 'export { default as Cv2DomFilterClient };'
if ($patched -notmatch [regex]::Escape($aliasLine)) {
  $patched = $patched.TrimEnd() + "`n`n" + $aliasLine + "`n"
}

if ($patched -ne $raw) {
  WriteUtf8NoBomSafe $comp $patched
  Write-Host ("[PATCH] wrote -> " + $compRel)
  Write-Host ("[BK] tools/_patch_backup/" + (Split-Path -Leaf $bk))
} else {
  Write-Host "[PATCH] no changes needed"
}

# REPORT (sem NewReport)
$reportRel = ("reports\" + $step + "-" + $stamp + ".md")
$reportPath = Join-Path $root $reportRel

$rep = @()
$rep += "# CV — Step B6d1: Fix DomFilter export + deps"
$rep += ""
$rep += "- when: " + $stamp
$rep += "- file: " + $compRel
$rep += "- backup: tools/_patch_backup/" + (Split-Path -Leaf $bk)
$rep += ""
$rep += "## O QUE MUDA"
$rep += "- Adiciona `export { default as Cv2DomFilterClient }` pra compat com `import { Cv2DomFilterClient } ...`."
$rep += "- Ajusta skipSelector (useMemo) + deps do useEffect pra remover warning do exhaustive-deps."
$rep += ""
$rep += "## VERIFY"
$rep += "- tools/cv-verify.ps1"

WriteUtf8NoBomSafe $reportPath ($rep -join "`n")
Write-Host ("[REPORT] " + $reportRel)

# VERIFY
$verify = Join-Path $root "tools\cv-verify.ps1"
if (Test-Path -LiteralPath $verify) {
  Write-Host "[RUN] tools/cv-verify.ps1"
  & pwsh -NoProfile -ExecutionPolicy Bypass -File $verify
} else {
  Write-Host "[RUN] npm run lint"
  & npm run lint
  Write-Host "[RUN] npm run build"
  & npm run build
}

Write-Host "[OK] B6d1 aplicado." -ForegroundColor Green
if ($OpenReport) { try { Invoke-Item $reportPath } catch {} }