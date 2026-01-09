# cv-hotfix-b6p-portals-active-alias-v0_1
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = (Get-Location).Path
$stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")

function EnsureDir([string]$p) { if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function WriteUtf8NoBom([string]$file, [string]$content) {
  $dir = Split-Path -Parent $file
  if ($dir) { EnsureDir $dir }
  [IO.File]::WriteAllText($file, $content, [Text.UTF8Encoding]::new($false))
}
function BackupFile([string]$file) {
  $bkDir = Join-Path $repoRoot "tools\_patch_backup"
  EnsureDir $bkDir
  $leaf = (Split-Path -Leaf $file) -replace '[\\\/:]', '_'
  $bk = Join-Path $bkDir ("$stamp-$leaf.bak")
  Copy-Item -LiteralPath $file -Destination $bk -Force
  return $bk
}

Write-Host ("== cv-hotfix-b6p-portals-active-alias-v0_1 == " + $stamp)
Write-Host ("[DIAG] Repo: " + $repoRoot)

# ------------------------------------------------------------
# PATCH 1) V2Portals: aceitar active como alias de current
# ------------------------------------------------------------
$portalsRel = "src\components\v2\V2Portals.tsx"
$portals = Join-Path $repoRoot $portalsRel
if (-not (Test-Path -LiteralPath $portals)) { throw "[STOP] não achei " + $portalsRel }

$raw = Get-Content -Raw -LiteralPath $portals
$p = $raw

# 1a) ampliar tipo props
if ($p -match 'export\s+default\s+function\s+V2Portals\s*\(props:\s*\{\s*slug:\s*string;\s*current\?:\s*string;\s*title\?:\s*string\s*\}\s*\)') {
  $p = [regex]::Replace(
    $p,
    'export\s+default\s+function\s+V2Portals\s*\(props:\s*\{\s*slug:\s*string;\s*current\?:\s*string;\s*title\?:\s*string\s*\}\s*\)',
    'export default function V2Portals(props: { slug: string; current?: string; active?: string; title?: string })'
  )
}

# 1b) current = props.current -> current = props.current ?? props.active
if ($p -match 'const\s+current\s*=\s*props\.current\s*;') {
  $p = [regex]::Replace($p, 'const\s+current\s*=\s*props\.current\s*;', 'const current = (props.current ?? props.active);')
}

if ($p -ne $raw) {
  $bk = BackupFile $portals
  WriteUtf8NoBom $portals $p
  Write-Host ("[PATCH] " + $portalsRel)
  Write-Host ("[BK]    tools\_patch_backup\" + (Split-Path -Leaf $bk))
} else {
  Write-Host "[SKIP] V2Portals.tsx (sem mudanças necessárias)"
}

# ------------------------------------------------------------
# PATCH 2) Trocar usos antigos active= -> current= nas páginas V2
# ------------------------------------------------------------
$v2Dir = Join-Path $repoRoot "src\app\c\[slug]\v2"
if (-not (Test-Path -LiteralPath $v2Dir)) { throw "[STOP] não achei src/app/c/[slug]/v2" }

$patched = @()
$pages = Get-ChildItem -LiteralPath $v2Dir -Recurse -File -Filter page.tsx
foreach ($f in $pages) {
  $r = Get-Content -Raw -LiteralPath $f.FullName
  if ($r -notmatch '<V2Portals\b') { continue }
  if ($r -notmatch '\sactive\s*=') { continue }

  $q = $r.Replace(' active="', ' current="')
  if ($q -ne $r) {
    $bk2 = BackupFile $f.FullName
    WriteUtf8NoBom $f.FullName $q
    $rel = $f.FullName.Substring($repoRoot.Length+1)
    $patched += $rel
    Write-Host ("[PATCH] " + $rel)
    Write-Host ("[BK]    tools\_patch_backup\" + (Split-Path -Leaf $bk2))
  }
}

# ------------------------------------------------------------
# VERIFY (via cmd.exe pra evitar os “Unknown command: ...”)
# ------------------------------------------------------------
$npmPath = (where.exe npm | Select-Object -First 1)
if (-not $npmPath) { $npmPath = "npm" }

Write-Host "[RUN] npm run lint"
$lintOut = (cmd.exe /d /s /c "`"$npmPath`" run lint" 2>&1 | Out-String)
$lintExit = $LASTEXITCODE
if ($lintExit -ne 0) { Write-Host $lintOut; throw ("[STOP] lint falhou (exit=" + $lintExit + ")") }

Write-Host "[RUN] npm run build"
$buildOut = (cmd.exe /d /s /c "`"$npmPath`" run build" 2>&1 | Out-String)
$buildExit = $LASTEXITCODE
if ($buildExit -ne 0) { Write-Host $buildOut; throw ("[STOP] build falhou (exit=" + $buildExit + ")") }

# ------------------------------------------------------------
# REPORT
# ------------------------------------------------------------
$repDir = Join-Path $repoRoot "reports"
EnsureDir $repDir
$rep = Join-Path $repDir ($stamp + "-cv-hotfix-b6p-portals-active-alias.md")

$body = @(
  ("# CV HOTFIX — Portals active alias — " + $stamp),
  "",
  ("Repo: " + $repoRoot),
  "",
  "## PATCH",
  ("- Updated: " + $portalsRel + " (active alias)"),
  "- Pages updated (active -> current):",
  ($patched | ForEach-Object { "  - " + $_ }),
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
  "--- BUILD OUTPUT END ---",
  ""
) -join "`n"

WriteUtf8NoBom $rep $body
Write-Host ("[REPORT] reports\" + (Split-Path -Leaf $rep))
Write-Host "[OK] HOTFIX aplicado (V2Portals aceita active e páginas normalizadas)."