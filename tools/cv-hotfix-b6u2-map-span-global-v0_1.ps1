param()
$ErrorActionPreference = "Stop"

$stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

Write-Host ("== cv-hotfix-b6u2-map-span-global-v0_1 == " + $stamp)
Write-Host ("[DIAG] Repo: " + $repoRoot)

function EnsureDir([string]$p) { if (!(Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function BackupFile([string]$abs) {
  $bkDir = Join-Path $repoRoot "tools\_patch_backup"
  EnsureDir $bkDir
  $leaf = (Split-Path -Leaf $abs) -replace "[\\\/:\s]", "_"
  $bk = Join-Path $bkDir ($stamp + "-" + $leaf + ".bak")
  Copy-Item -LiteralPath $abs -Destination $bk -Force
  return $bk
}
function WriteUtf8NoBom([string]$abs, [string]$content) { [IO.File]::WriteAllText($abs, $content, [Text.UTF8Encoding]::new($false)) }

# ------------------------------------------------------------
# PATCH globals.css (global selectors for primary + pill)
# ------------------------------------------------------------
$globalsRel = "src\app\globals.css"
$globalsAbs = Join-Path $repoRoot $globalsRel

if (!(Test-Path -LiteralPath $globalsAbs)) { throw "[STOP] não achei src/app/globals.css" }

$raw = Get-Content -LiteralPath $globalsAbs -Raw
if ($raw -match "CV2 MAP FIRST GLOBAL") {
  Write-Host "SKIP: globals.css já tem CV2 MAP FIRST GLOBAL"
} else {
  $bk = BackupFile $globalsAbs

  $appendLines = @(
    "",
    "",
    "/* ===== CV2 MAP FIRST GLOBAL (span + pill) ===== */",
    "/* CV2 MAP FIRST GLOBAL */",
    ".cv2-card {",
    "  display: flex;",
    "  flex-direction: column;",
    "  gap: 6px;",
    "}",
    "",
    ".cv2-card--primary {",
    "  grid-column: span 2;",
    "  background: rgba(255,255,255,0.06);",
    "  border-color: rgba(255,255,255,0.20);",
    "}",
    "",
    "@media (max-width: 780px) {",
    "  .cv2-card--primary {",
    "    grid-column: auto;",
    "  }",
    "}",
    "",
    ".cv2-pill {",
    "  font-size: 11px;",
    "  padding: 4px 8px;",
    "  border-radius: 999px;",
    "  border: 1px solid rgba(255,255,255,0.16);",
    "  background: rgba(255,255,255,0.06);",
    "  opacity: 0.9;",
    "}",
    "/* ===== /CV2 MAP FIRST GLOBAL ===== */",
    ""
  )
  $append = ($appendLines -join "`n")
  WriteUtf8NoBom $globalsAbs ($raw.TrimEnd() + $append)

  Write-Host ("[PATCH] " + $globalsRel + " (append CV2 MAP FIRST GLOBAL)")
  Write-Host ("[BK]    tools\_patch_backup\" + (Split-Path -Leaf $bk))
}

# ------------------------------------------------------------
# VERIFY
# ------------------------------------------------------------
$npm = (Get-Command npm.cmd -ErrorAction Stop).Path

Write-Host "[RUN] npm run lint"
$lintOut = (& $npm run lint 2>&1 | Out-String)
$lintExit = $LASTEXITCODE
if ($lintExit -ne 0) { Write-Host $lintOut; throw ("[STOP] lint falhou (exit=" + $lintExit + ")") }

Write-Host "[RUN] npm run build"
$buildOut = (& $npm run build 2>&1 | Out-String)
$buildExit = $LASTEXITCODE
if ($buildExit -ne 0) { Write-Host $buildOut; throw ("[STOP] build falhou (exit=" + $buildExit + ")") }

# ------------------------------------------------------------
# REPORT
# ------------------------------------------------------------
$repDir = Join-Path $repoRoot "reports"
EnsureDir $repDir
$rep = Join-Path $repDir ($stamp + "-cv-hotfix-b6u2-map-span-global.md")

$body = @(
  ("# CV HOTFIX B6U2 — Map span global — " + $stamp),
  "",
  ("Repo: " + $repoRoot),
  "",
  "## PATCH",
  ("- " + $globalsRel),
  "",
  "## VERIFY",
  ("- lint exit: " + $lintExit),
  ("- build exit: " + $buildExit),
  "",
  "--- LINT OUTPUT START ---",
  $lintOut.TrimEnd(),
  "--- LINT OUTPUT END ---",
  "",
  "--- BUILD OUTPUT START ---",
  $buildOut.TrimEnd(),
  "--- BUILD OUTPUT END ---"
) -join "`n"

WriteUtf8NoBom $rep $body
Write-Host ("[REPORT] reports\" + (Split-Path -Leaf $rep))
Write-Host "[OK] HOTFIX B6U2 concluído (Mapa agora span 2 colunas)."