param([switch]$OpenReport)

$ErrorActionPreference = 'Stop'

# -----------------------
# DIAG
# -----------------------
$root = Split-Path -Parent $PSScriptRoot
$boot = Join-Path $PSScriptRoot "_bootstrap.ps1"
if (Test-Path $boot) { . $boot } else { throw "[STOP] tools/_bootstrap.ps1 não encontrado" }

$step = "cv-step-b6d2-fix-domfilter-exports-and-deps-v0_1"
$ts = (Get-Date).ToString("yyyyMMdd-HHmmss")
Write-Host ("== " + $step + " == " + $ts)
Write-Host ("[DIAG] Root: " + $root)

$target = Join-Path $root "src\components\v2\Cv2DomFilterClient.tsx"
if (!(Test-Path $target)) { throw ("[STOP] alvo não encontrado: " + $target) }

BackupFile $target | Out-Null

$raw = Get-Content -Raw -LiteralPath $target
if ($null -eq $raw -or $raw.Trim().Length -eq 0) { throw "[STOP] Cv2DomFilterClient.tsx vazio/ilegível" }

$rep = @()
$rep += "# CV — Step B6d2: Fix domfilter exports + deps (final)"
$rep += ""
$rep += "- when: " + $ts
$rep += "- file: src\components\v2\Cv2DomFilterClient.tsx"
$rep += ""

# -----------------------
# PATCH (line-based, parser-safe)
# -----------------------
$lines = Get-Content -LiteralPath $target

$changed = $false

# 1) remove linha inválida: export { default as Cv2DomFilterClient };
$newLines = New-Object System.Collections.Generic.List[string]
foreach ($ln in $lines) {
  if ($ln -match '^\s*export\s*\{\s*default\s+as\s+Cv2DomFilterClient\s*\}\s*;\s*$') {
    $changed = $true
    continue
  }
  $newLines.Add($ln) | Out-Null
}

# 2) garantir foldText tipado (evita "implicit any" no build)
for ($i = 0; $i -lt $newLines.Count; $i++) {
  $ln = $newLines[$i]
  if ($ln -match '^\s*function\s+foldText\s*\(') {
    # canonicaliza a assinatura (mantém o bloco seguinte intacto)
    if ($ln -notmatch 'input:\s*unknown' -or $ln -notmatch '\)\s*:\s*string') {
      $indent = ($ln -replace '^(\s*).*$', '$1')
      $newLines[$i] = ($indent + 'function foldText(input: unknown): string {')
      $changed = $true
    }
    break
  }
}

# 3) deps do useEffect: incluir skipSelector quando existir o padrão [props.rootId, qFold]
for ($i = 0; $i -lt $newLines.Count; $i++) {
  $ln = $newLines[$i]
  if ($ln -match '^\s*\},\s*\[\s*props\.rootId\s*,\s*qFold\s*\]\s*\)\s*;\s*$') {
    $indent = ($ln -replace '^(\s*).*$', '$1')
    $newLines[$i] = ($indent + '}, [props.rootId, qFold, skipSelector]);')
    $changed = $true
  }
}

# 4) garantir named export sem sintaxe inválida
# - se já existe export { Cv2DomFilterClient }; ou export function/const Cv2DomFilterClient => ok
$joined = ($newLines -join "`n")
$hasNamed =
  ($joined -match 'export\s+\{\s*Cv2DomFilterClient\s*\}') -or
  ($joined -match 'export\s+function\s+Cv2DomFilterClient\s*\(') -or
  ($joined -match 'export\s+const\s+Cv2DomFilterClient\s*=')

if (-not $hasNamed) {
  # Se existe "export default function Cv2DomFilterClient" ou "function Cv2DomFilterClient"
  $hasNameInScope =
    ($joined -match 'export\s+default\s+function\s+Cv2DomFilterClient\s*\(') -or
    ($joined -match '^\s*function\s+Cv2DomFilterClient\s*\(')

  if ($hasNameInScope) {
    $newLines.Add("") | Out-Null
    $newLines.Add("export { Cv2DomFilterClient };") | Out-Null
    $changed = $true
  }
}

if ($changed) {
  WriteUtf8NoBom $target ($newLines -join "`n")
  Write-Host ("[PATCH] wrote -> " + (RelPathSafe $root $target))
  $rep += "## ACTIONS"
  $rep += "- Removed invalid `export { default as Cv2DomFilterClient };` line (turbopack parse-safe)."
  $rep += "- Ensured `foldText(input: unknown): string` signature (no implicit any)."
  $rep += "- Added `skipSelector` to effect deps when applicable."
  $rep += "- Ensured named export `export { Cv2DomFilterClient };` when possible."
} else {
  Write-Host "[PATCH] no changes needed (já estava OK)"
  $rep += "## ACTIONS"
  $rep += "- No-op: arquivo já estava no formato esperado."
}

# -----------------------
# REPORT
# -----------------------
$reportPath = NewReport $step ($rep -join "`n")
Write-Host ("[REPORT] " + (RelPathSafe $root $reportPath))

# -----------------------
# VERIFY
# -----------------------
$verify = Join-Path $root "tools\cv-verify.ps1"
if (Test-Path $verify) {
  Write-Host ("[RUN] " + (RelPathSafe $root $verify))
  & $verify
} else {
  Write-Host "[WARN] tools/cv-verify.ps1 não encontrado — rodando lint+build"
  StopOnExit (& $env:ComSpec /c 'npm run lint') | Out-Null
  StopOnExit (& $env:ComSpec /c 'npm run build') | Out-Null
}

Write-Host "[OK] B6d2 aplicado."

if ($OpenReport) {
  try { Invoke-Item $reportPath } catch { }
}