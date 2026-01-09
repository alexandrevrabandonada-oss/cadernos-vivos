param()
$ErrorActionPreference = "Stop"

$stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

Write-Host ("== cv-hotfix-b6u3-cv2-polish-interactions-v0_1 == " + $stamp)
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

$globalsRel = "src\app\globals.css"
$globalsAbs = Join-Path $repoRoot $globalsRel
if (!(Test-Path -LiteralPath $globalsAbs)) { throw "[STOP] não achei src/app/globals.css" }

$raw = Get-Content -LiteralPath $globalsAbs -Raw

if ($raw -match "CV2 POLISH INTERACTIONS") {
  Write-Host "SKIP: globals.css já tem CV2 POLISH INTERACTIONS"
} else {
  $bk = BackupFile $globalsAbs

  $appendLines = @(
    "",
    "",
    "/* ===== CV2 POLISH INTERACTIONS (cards + inputs) ===== */",
    "/* CV2 POLISH INTERACTIONS */",
    "",
    "/* Cards (hub/portais) */",
    ".cv2-card {",
    "  cursor: pointer;",
    "  transition: transform 120ms ease, border-color 120ms ease, background 120ms ease;",
    "}",
    ".cv2-card:hover {",
    "  transform: translateY(-1px);",
    "  background: rgba(255,255,255,0.08);",
    "  border-color: rgba(255,255,255,0.28);",
    "}",
    ".cv2-card:active {",
    "  transform: translateY(0px);",
    "}",
    ".cv2-card:focus-within {",
    "  outline: 2px solid rgba(255,255,255,0.35);",
    "  outline-offset: 2px;",
    "}",
    ".cv2-card a {",
    "  color: inherit;",
    "  text-decoration: none;",
    "}",
    "",
    "/* Inputs dentro de roots CV2 (evita a faixa clara estourada) */",
    "[id^=""cv2-""][id$=""-root""] input,",
    "[id^=""cv2-""][id$=""-root""] textarea {",
    "  background: rgba(255,255,255,0.08);",
    "  border: 1px solid rgba(255,255,255,0.16);",
    "  color: rgba(255,255,255,0.92);",
    "}",
    "[id^=""cv2-""][id$=""-root""] input::placeholder,",
    "[id^=""cv2-""][id$=""-root""] textarea::placeholder {",
    "  color: rgba(255,255,255,0.55);",
    "}",
    "",
    "/* ===== /CV2 POLISH INTERACTIONS ===== */",
    ""
  )

  $append = ($appendLines -join "`n")
  WriteUtf8NoBom $globalsAbs ($raw.TrimEnd() + $append)

  Write-Host ("[PATCH] " + $globalsRel + " (append CV2 POLISH INTERACTIONS)")
  Write-Host ("[BK]    tools\_patch_backup\" + (Split-Path -Leaf $bk))
}

# VERIFY
$npm = (Get-Command npm.cmd -ErrorAction Stop).Path

Write-Host "[RUN] npm run lint"
$lintOut = (& $npm run lint 2>&1 | Out-String)
$lintExit = $LASTEXITCODE
if ($lintExit -ne 0) { Write-Host $lintOut; throw ("[STOP] lint falhou (exit=" + $lintExit + ")") }

Write-Host "[RUN] npm run build"
$buildOut = (& $npm run build 2>&1 | Out-String)
$buildExit = $LASTEXITCODE
if ($buildExit -ne 0) { Write-Host $buildOut; throw ("[STOP] build falhou (exit=" + $buildExit + ")") }

# REPORT
$repDir = Join-Path $repoRoot "reports"
EnsureDir $repDir
$rep = Join-Path $repDir ($stamp + "-cv-hotfix-b6u3-cv2-polish-interactions.md")

$body = @(
  ("# CV HOTFIX B6U3 — CV2 Polish Interactions — " + $stamp),
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
Write-Host "[OK] HOTFIX B6U3 concluído (CV2 polish aplicado)."