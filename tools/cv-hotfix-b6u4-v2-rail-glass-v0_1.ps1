param()
$ErrorActionPreference = "Stop"

$stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

Write-Host ("== cv-hotfix-b6u4-v2-rail-glass-v0_1 == " + $stamp)
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

function AddClassToFirstReturnRoot([string]$raw, [string]$classToAdd) {
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
    return @{ ok=$false; out=$raw; why=("root tag not div/nav/section: " + ($tag.Substring(0, [Math]::Min(20,$tag.Length)))) }
  }

  if ($tag -match "className\s*=\s*`"([^`"]*)`"") {
    $existing = $Matches[1]
    if ($existing -match [regex]::Escape($classToAdd)) {
      return @{ ok=$false; out=$raw; why="already has class" }
    }
    $newExisting = ($existing.Trim() + " " + $classToAdd).Trim()
    $newTag = [regex]::Replace($tag, "className\s*=\s*`"([^`"]*)`"", ('className="' + $newExisting + '"'), 1)
    $out = $raw.Substring(0,$j) + $newTag + $raw.Substring($k+1)
    return @{ ok=$true; out=$out; why="patched existing className" }
  }

  if ($tag -match "className\s*=\s*{") {
    # className é expressão; não mexe pra não quebrar
    return @{ ok=$false; out=$raw; why="className is expression" }
  }

  # inserir className logo após o nome da tag
  if ($tag -match "^<div\b") { $newTag = $tag -replace "^<div\b", ('<div className="' + $classToAdd + '"') }
  elseif ($tag -match "^<nav\b") { $newTag = $tag -replace "^<nav\b", ('<nav className="' + $classToAdd + '"') }
  else { $newTag = $tag -replace "^<section\b", ('<section className="' + $classToAdd + '"') }

  $out2 = $raw.Substring(0,$j) + $newTag + $raw.Substring($k+1)
  return @{ ok=$true; out=$out2; why="inserted className" }
}

# 1) Patch components: add stable classes (best-effort)
$targets = @(
  @{ rel="src\components\v2\V2QuickNav.tsx"; cls="cv2-quicknav" },
  @{ rel="src\components\v2\V2Nav.tsx";      cls="cv2-topnav"   },
  @{ rel="src\components\v2\V2Portals.tsx";  cls="cv2-portals"  }
)

$patched = @()

foreach ($t in $targets) {
  $abs = Join-Path $repoRoot $t.rel
  if (!(Test-Path -LiteralPath $abs)) { Write-Host ("[WARN] missing: " + $t.rel); continue }
  $raw = Get-Content -LiteralPath $abs -Raw
  $res = AddClassToFirstReturnRoot $raw $t.cls
  if ($res.ok) {
    $bk = BackupFile $abs
    WriteUtf8NoBom $abs $res.out
    Write-Host ("[PATCH] " + $t.rel + " (" + $res.why + ")")
    Write-Host ("[BK]    tools\_patch_backup\" + (Split-Path -Leaf $bk))
    $patched += $t.rel
  } else {
    Write-Host ("[SKIP] " + $t.rel + " (" + $res.why + ")")
  }
}

# 2) CSS: glass rail + nav/link polish (scoped)
$globalsRel = "src\app\globals.css"
$globalsAbs = Join-Path $repoRoot $globalsRel
if (!(Test-Path -LiteralPath $globalsAbs)) { throw "[STOP] não achei src/app/globals.css" }

$g = Get-Content -LiteralPath $globalsAbs -Raw
if ($g -match "CV2 RAIL GLASS") {
  Write-Host "SKIP: globals.css já tem CV2 RAIL GLASS"
} else {
  $bk = BackupFile $globalsAbs
  $lines = @(
    "",
    "",
    "/* ===== CV2 RAIL GLASS (Concreto Zen) ===== */",
    "/* CV2 RAIL GLASS */",
    "",
    "/* QuickNav rail (aquela faixa clara) */",
    ".cv2-quicknav {",
    "  background: rgba(255,255,255,0.06) !important;",
    "  border: 1px solid rgba(255,255,255,0.14) !important;",
    "  backdrop-filter: blur(10px);",
    "  -webkit-backdrop-filter: blur(10px);",
    "}",
    ".cv2-quicknav a, .cv2-quicknav button {",
    "  color: rgba(255,255,255,0.78);",
    "  text-decoration: none;",
    "}",
    ".cv2-quicknav a:hover, .cv2-quicknav button:hover {",
    "  color: rgba(255,255,255,0.92);",
    "}",
    "",
    "/* Top nav pills */",
    ".cv2-topnav a, .cv2-topnav button {",
    "  transition: transform 120ms ease, border-color 120ms ease, background 120ms ease;",
    "}",
    ".cv2-topnav a:hover, .cv2-topnav button:hover {",
    "  transform: translateY(-1px);",
    "}",
    "",
    "/* Portals cards: ensure hover/focus even if inline styles exist */",
    ".cv2-portals .cv2-card:hover {",
    "  background: rgba(255,255,255,0.08) !important;",
    "  border-color: rgba(255,255,255,0.28) !important;",
    "}",
    "",
    "/* ===== /CV2 RAIL GLASS ===== */",
    ""
  )

  WriteUtf8NoBom $globalsAbs ($g.TrimEnd() + ($lines -join "`n"))
  Write-Host ("[PATCH] " + $globalsRel + " (append CV2 RAIL GLASS)")
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
$rep = Join-Path $repDir ($stamp + "-cv-hotfix-b6u4-v2-rail-glass.md")

$body = @(
  ("# CV HOTFIX B6U4 — V2 Rail Glass — " + $stamp),
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
Write-Host "[OK] HOTFIX B6U4 concluído (rail vidro fosco + classes estáveis)."