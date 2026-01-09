param()
$ErrorActionPreference = "Stop"

$stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

Write-Host ("== cv-hotfix-b6u5-v2-quicknav-glass-dataattr-v0_1 == " + $stamp)
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

function AddDataAttrToFirstReturnRoot([string]$raw, [string]$dataValue) {
  $idx = $raw.IndexOf("return (")
  if ($idx -lt 0) { $idx = $raw.IndexOf("return(") }
  if ($idx -lt 0) { return @{ ok=$false; out=$raw; why="no return(" } }

  $j = $raw.IndexOf("<", $idx)
  if ($j -lt 0) { return @{ ok=$false; out=$raw; why="no tag after return" } }

  # pular fragment <>
  if ($j + 1 -lt $raw.Length -and $raw.Substring($j, 2) -eq "<>") {
    $j = $raw.IndexOf("<", $j + 2)
    if ($j -lt 0) { return @{ ok=$false; out=$raw; why="only fragment" } }
  }

  $k = $raw.IndexOf(">", $j)
  if ($k -lt 0) { return @{ ok=$false; out=$raw; why="unterminated tag" } }

  $tag = $raw.Substring($j, ($k - $j + 1))

  if (($tag -notmatch "^<div\b") -and ($tag -notmatch "^<nav\b") -and ($tag -notmatch "^<section\b")) {
    return @{ ok=$false; out=$raw; why=("root tag not div/nav/section") }
  }

  if ($tag -match "data-cv2\s*=") {
    return @{ ok=$false; out=$raw; why="already has data-cv2" }
  }

  if ($tag -match "^<div\b") { $newTag = $tag -replace "^<div\b", ('<div data-cv2="' + $dataValue + '"') }
  elseif ($tag -match "^<nav\b") { $newTag = $tag -replace "^<nav\b", ('<nav data-cv2="' + $dataValue + '"') }
  else { $newTag = $tag -replace "^<section\b", ('<section data-cv2="' + $dataValue + '"') }

  $out = $raw.Substring(0,$j) + $newTag + $raw.Substring($k+1)
  return @{ ok=$true; out=$out; why="inserted data-cv2" }
}

# 1) Marcar componentes V2 com data-cv2 (root)
$targets = @(
  @{ rel="src\components\v2\V2QuickNav.tsx"; data="quicknav" },
  @{ rel="src\components\v2\V2Nav.tsx";      data="topnav"   },
  @{ rel="src\components\v2\V2Portals.tsx";  data="portals"  }
)

$patched = @()

foreach ($t in $targets) {
  $abs = Join-Path $repoRoot $t.rel
  if (!(Test-Path -LiteralPath $abs)) { Write-Host ("[WARN] missing: " + $t.rel); continue }
  $raw = Get-Content -LiteralPath $abs -Raw
  $res = AddDataAttrToFirstReturnRoot $raw $t.data
  if ($res.ok) {
    $bk = BackupFile $abs
    WriteUtf8NoBom $abs $res.out
    Write-Host ("[PATCH] " + $t.rel + " (" + $res.why + " => " + $t.data + ")")
    Write-Host ("[BK]    tools\_patch_backup\" + (Split-Path -Leaf $bk))
    $patched += $t.rel
  } else {
    Write-Host ("[SKIP] " + $t.rel + " (" + $res.why + ")")
  }
}

# 2) CSS Concreto Zen: quicknav rail de vidro fosco + polimento de links/cards
$globalsRel = "src\app\globals.css"
$globalsAbs = Join-Path $repoRoot $globalsRel
if (!(Test-Path -LiteralPath $globalsAbs)) { throw "[STOP] não achei src/app/globals.css" }

$g = Get-Content -LiteralPath $globalsAbs -Raw
if ($g -match "CV2 QUICKNAV GLASS DATA") {
  Write-Host "SKIP: globals.css já tem CV2 QUICKNAV GLASS DATA"
} else {
  $bk = BackupFile $globalsAbs
  $css = @(
    "",
    "",
    "/* ===== CV2 QUICKNAV GLASS DATA (Concreto Zen) ===== */",
    "/* CV2 QUICKNAV GLASS DATA */",
    "",
    "[data-cv2=""quicknav""] {",
    "  background: rgba(0,0,0,0.22) !important;",
    "  border: 1px solid rgba(255,255,255,0.14) !important;",
    "  box-shadow: inset 0 1px 0 rgba(255,255,255,0.06);",
    "  backdrop-filter: blur(10px);",
    "  -webkit-backdrop-filter: blur(10px);",
    "}",
    "[data-cv2=""quicknav""] a, [data-cv2=""quicknav""] button {",
    "  color: rgba(255,255,255,0.74);",
    "  text-decoration: none;",
    "}",
    "[data-cv2=""quicknav""] a:hover, [data-cv2=""quicknav""] button:hover {",
    "  color: rgba(255,255,255,0.92);",
    "}",
    "",
    "/* Top nav pills: micro lift */",
    "[data-cv2=""topnav""] a, [data-cv2=""topnav""] button {",
    "  transition: transform 120ms ease, border-color 120ms ease, background 120ms ease;",
    "}",
    "[data-cv2=""topnav""] a:hover, [data-cv2=""topnav""] button:hover {",
    "  transform: translateY(-1px);",
    "}",
    "",
    "/* Portals: hover mais vivo (mesmo com inline styles) */",
    "[data-cv2=""portals""] .cv2-card:hover {",
    "  background: rgba(255,255,255,0.08) !important;",
    "  border-color: rgba(255,255,255,0.28) !important;",
    "}",
    "",
    "/* ===== /CV2 QUICKNAV GLASS DATA ===== */",
    ""
  ) -join "`n"

  WriteUtf8NoBom $globalsAbs ($g.TrimEnd() + $css)
  Write-Host ("[PATCH] " + $globalsRel + " (append CV2 QUICKNAV GLASS DATA)")
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
$rep = Join-Path $repDir ($stamp + "-cv-hotfix-b6u5-v2-quicknav-glass-dataattr.md")

$body = @(
  ("# CV HOTFIX B6U5 — V2 QuickNav Glass via data-cv2 — " + $stamp),
  "",
  ("Repo: " + $repoRoot),
  "",
  "## PATCH",
  ("- Components patched: " + ($patched.Count)),
  ($patched | ForEach-Object { "  - " + $_ }),
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
Write-Host "[OK] HOTFIX B6U5 concluído (QuickNav vidro fosco + data-cv2 estável)."