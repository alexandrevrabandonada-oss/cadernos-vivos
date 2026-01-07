param()

$ErrorActionPreference = "Stop"
$root = (Get-Location).Path

# ---- bootstrap (preferencial) + fallbacks ----
$bootstrap = Join-Path $root "tools\_bootstrap.ps1"
if (Test-Path -LiteralPath $bootstrap) {
  . $bootstrap
}

if (-not (Get-Command EnsureDir -ErrorAction SilentlyContinue)) {
  function EnsureDir([string]$p) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}
if (-not (Get-Command Write-Utf8NoBom -ErrorAction SilentlyContinue)) {
  function Write-Utf8NoBom([string]$file, [string]$text) {
    $enc = [Text.UTF8Encoding]::new($false)
    [IO.File]::WriteAllText($file, $text, $enc)
  }
}
if (-not (Get-Command Backup-File -ErrorAction SilentlyContinue)) {
  function Backup-File([string]$file) {
    $bkDir = Join-Path $root "tools\_patch_backup"
    EnsureDir $bkDir
    $stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
    $leaf  = (Split-Path -Leaf $file).Replace(":", "_")
    $bk    = Join-Path $bkDir ($stamp + "-" + $leaf + ".bak")
    Copy-Item -LiteralPath $file -Destination $bk -Force
    return $bk
  }
}

function Find-GlobalsCss {
  $candidates = @(
    (Join-Path $root "src\app\globals.css"),
    (Join-Path $root "src\styles\globals.css"),
    (Join-Path $root "src\globals.css")
  )
  foreach ($c in $candidates) {
    if (Test-Path -LiteralPath $c) { return $c }
  }
  $found = Get-ChildItem -LiteralPath (Join-Path $root "src") -Recurse -File -Filter "globals.css" -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($found) { return $found.FullName }
  throw "[STOP] não achei globals.css em src/"
}

$globals = Find-GlobalsCss
if (!(Test-Path -LiteralPath $globals)) { throw "[STOP] não achei: $globals" }

$raw = Get-Content -Raw -LiteralPath $globals

$marker = "/* CV2 — Provas UI polish (B6k) */"
if ($raw -match [regex]::Escape($marker)) {
  Write-Host "[SKIP] globals.css já tem B6k"
  exit 0
}

$css = @(
  "",
  $marker,
  ".cv-v2 [data-cv2-provas-tools=""1""] {",
  "  display: flex;",
  "  flex-wrap: wrap;",
  "  gap: 10px;",
  "  align-items: center;",
  "  padding: 10px;",
  "  border-radius: 14px;",
  "  border: 1px solid rgba(255,255,255,0.10);",
  "  background: var(--cv2-surface-1, rgba(255,255,255,0.04));",
  "  box-shadow: 0 8px 24px rgba(0,0,0,0.25);",
  "}",
  "",
  ".cv-v2 [data-cv2-provas-tools=""1""] button {",
  "  appearance: none;",
  "  border: 1px solid rgba(255,255,255,0.14);",
  "  background: var(--cv2-surface-2, rgba(255,255,255,0.06));",
  "  color: inherit;",
  "  border-radius: 12px;",
  "  padding: 9px 12px;",
  "  font-weight: 650;",
  "  letter-spacing: 0.2px;",
  "  cursor: pointer;",
  "  transition: transform .06s ease, border-color .12s ease, background .12s ease;",
  "}",
  ".cv-v2 [data-cv2-provas-tools=""1""] button:hover {",
  "  border-color: rgba(255,255,255,0.24);",
  "  background: var(--cv2-surface-3, rgba(255,255,255,0.09));",
  "}",
  ".cv-v2 [data-cv2-provas-tools=""1""] button:active {",
  "  transform: translateY(1px);",
  "}",
  ".cv-v2 [data-cv2-provas-tools=""1""] button:focus-visible {",
  "  outline: 2px solid var(--cv2-accent, #F7C600);",
  "  outline-offset: 2px;",
  "}",
  "",
  ".cv-v2 [data-cv2-provas-tools=""1""] label {",
  "  display: inline-flex;",
  "  align-items: center;",
  "  gap: 8px;",
  "  padding: 7px 10px;",
  "  border-radius: 999px;",
  "  border: 1px solid rgba(255,255,255,0.10);",
  "  background: rgba(0,0,0,0.12);",
  "  user-select: none;",
  "}",
  ".cv-v2 [data-cv2-provas-tools=""1""] input[type=""checkbox""] {",
  "  width: 16px;",
  "  height: 16px;",
  "  accent-color: var(--cv2-accent, #F7C600);",
  "}",
  "",
  ".cv-v2 [data-cv2-filter-ui=""1""] {",
  "  border-radius: 14px;",
  "  border: 1px solid rgba(255,255,255,0.10);",
  "  background: rgba(0,0,0,0.14);",
  "  padding: 10px;",
  "}",
  ""
) -join "`n"

$bk = Backup-File $globals
Write-Utf8NoBom $globals ($raw.TrimEnd() + "`n" + $css)

Write-Host "[PATCH] " $globals
Write-Host ("[BK]    tools\_patch_backup\" + (Split-Path -Leaf $bk))
Write-Host "[RUN] npm run lint"
npm run lint