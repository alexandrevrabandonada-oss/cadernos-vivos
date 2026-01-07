param([switch]$OpenReport)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$bootstrap = Join-Path $PSScriptRoot "_bootstrap.ps1"
if (Test-Path -LiteralPath $bootstrap) { . $bootstrap }

$stamp = (Get-Date -Format "yyyyMMdd-HHmmss")
$step  = "cv-step-b6b1e-fix-domfilter-noimplicitany-v0_1"

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
if (-not (Test-Path -LiteralPath $fp)) { throw ("[STOP] target nao encontrado: " + $fpRel) }

$bk = BackupFile $fp
$raw = Get-Content -Raw -LiteralPath $fp
if ($null -eq $raw -or $raw.Trim().Length -eq 0) { throw "[STOP] arquivo vazio" }

$patched = $raw

# 1) foldText(input) -> foldText(input: unknown): string
$patched = [regex]::Replace(
  $patched,
  '(?m)^\s*function\s+foldText\s*\(\s*input\s*\)\s*\{',
  'function foldText(input: unknown): string {'
)

# 2) collectItems(root) -> collectItems(root: HTMLElement): HTMLElement[]
$patched = [regex]::Replace(
  $patched,
  '(?m)^\s*function\s+collectItems\s*\(\s*root\s*\)\s*\{',
  'function collectItems(root: HTMLElement): HTMLElement[] {'
)

# 3) Cv2DomFilterClient(props) -> tipa props
$patched = [regex]::Replace(
  $patched,
  '(?m)^\s*export\s+function\s+Cv2DomFilterClient\s*\(\s*props\s*\)\s*\{',
  'export function Cv2DomFilterClient(props: { rootId: string; placeholder?: string }) {'
)

# 4) useRef([]) -> useRef<HTMLElement[]>([])
$patched = $patched.Replace("const itemsRef = useRef([]);", "const itemsRef = useRef<HTMLElement[]>([]);")

if ($patched -ne $raw) {
  WriteUtf8NoBomSafe $fp $patched
  Write-Host ("[PATCH] wrote -> " + $fpRel)
  Write-Host ("[BK] " + (Rel $root $bk))
} else {
  Write-Host "[PATCH] no changes needed"
}

# report simples
$reportPath = Join-Path $root ("reports\" + $step + "-" + $stamp + ".md")
$rep = @()
$rep += "# CV — Step B6b1e: Fix noImplicitAny (Cv2DomFilterClient)"
$rep += ""
$rep += "- when: " + $stamp
$rep += "- file: " + $fpRel
$rep += "- backup: " + (Rel $root $bk)
$rep += "- action: add minimal TS types (unknown/string, HTMLElement, props, useRef<HTMLElement[]>)"
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

Write-Host "[OK] B6b1e aplicado." -ForegroundColor Green
if ($OpenReport) { try { Invoke-Item $reportPath } catch {} }