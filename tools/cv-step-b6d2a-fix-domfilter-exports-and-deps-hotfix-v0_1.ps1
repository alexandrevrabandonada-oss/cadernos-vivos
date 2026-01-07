param([switch]$OpenReport)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path

# bootstrap (se existir)
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
function RelPathTiny([string]$base, [string]$full) {
  try {
    $b = $base.TrimEnd('\','/')
    $f = $full
    if ($f.StartsWith($b)) {
      $r = $f.Substring($b.Length).TrimStart('\','/')
      if ($r.Length -gt 0) { return $r }
    }
  } catch {}
  return $full
}

$stamp = (Get-Date -Format "yyyyMMdd-HHmmss")
$step  = "cv-step-b6d2a-fix-domfilter-exports-and-deps-hotfix-v0_1"

Write-Host ("== " + $step + " == " + $stamp) -ForegroundColor Cyan
Write-Host ("[DIAG] Root: " + $root)

EnsureDirSafe (Join-Path $root "reports")
EnsureDirSafe (Join-Path $root "tools\_patch_backup")

$targetRel = "src\components\v2\Cv2DomFilterClient.tsx"
$target = Join-Path $root $targetRel
if (-not (Test-Path -LiteralPath $target)) { throw ("[STOP] target nao encontrado: " + $targetRel) }

$bk = BackupFileSafe $target
$raw = Get-Content -Raw -LiteralPath $target
if ($null -eq $raw -or $raw.Trim().Length -eq 0) { throw "[STOP] arquivo vazio" }

$changed = $false

# --- 1) remover linha inválida (se ainda existir)
$lines = $raw -split "`r?`n"
$out = New-Object System.Collections.Generic.List[string]
foreach ($ln in $lines) {
  if ($ln.Trim() -eq "export { default as Cv2DomFilterClient };") { $changed = $true; continue }
  $out.Add($ln) | Out-Null
}
$txt = ($out -join "`n")

# --- 2) foldText tipado
# troca somente a assinatura, sem mexer no resto
$txt2 = $txt -replace '(?m)^\s*function\s+foldText\s*\(\s*input\s*\)\s*\{', 'function foldText(input: unknown): string {'
if ($txt2 -ne $txt) { $txt = $txt2; $changed = $true }

# --- 3) deps: se houver useEffect com skipSelector usado, garantir no array
# (não tentamos ser espertos demais; só cobrimos os casos comuns do nosso componente)
$txt2 = $txt -replace '(?m)\},\s*\[\s*props\.rootId\s*,\s*qFold\s*\]\s*\)\s*;', '}, [props.rootId, qFold, skipSelector]);'
if ($txt2 -ne $txt) { $txt = $txt2; $changed = $true }

# --- 4) garantir named export válido (não usa default)
if ($txt -notmatch '(?m)^\s*export\s*\{\s*Cv2DomFilterClient\s*\}\s*;\s*$') {
  if ($txt -match '(?m)^\s*export\s+default\s+function\s+Cv2DomFilterClient\s*\(' -or
      $txt -match '(?m)^\s*function\s+Cv2DomFilterClient\s*\(') {
    $txt = $txt.TrimEnd() + "`n`nexport { Cv2DomFilterClient };`n"
    $changed = $true
  }
}

if ($changed) {
  WriteUtf8NoBomSafe $target $txt
  Write-Host ("[PATCH] wrote -> " + $targetRel)
  Write-Host ("[BK] tools/_patch_backup/" + (Split-Path -Leaf $bk))
} else {
  Write-Host "[PATCH] no changes needed"
}

# --- REPORT
$reportRel  = ("reports\" + $step + "-" + $stamp + ".md")
$reportPath = Join-Path $root $reportRel

$rep = @()
$rep += "# CV — Step B6d2a: Hotfix domfilter exports + deps"
$rep += ""
$rep += "- when: " + $stamp
$rep += "- file: " + $targetRel
$rep += "- backup: tools/_patch_backup/" + (Split-Path -Leaf $bk)
$rep += ""
$rep += "## Changes"
$rep += "- Remove invalid `export { default as ... }` (se existir)."
$rep += "- Ensure `foldText(input: unknown): string`."
$rep += "- Add `skipSelector` to deps (caso padrão)."
$rep += "- Ensure named export `export { Cv2DomFilterClient };` (válido)."
$rep += ""
$rep += "## Verify"
$rep += "- tools/cv-verify.ps1"

WriteUtf8NoBomSafe $reportPath ($rep -join "`n")
Write-Host ("[REPORT] " + $reportRel)

# --- VERIFY
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

Write-Host "[OK] B6d2a aplicado." -ForegroundColor Green
if ($OpenReport) { try { Invoke-Item $reportPath } catch {} }