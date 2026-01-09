$ErrorActionPreference = "Stop"

function _NowTag { Get-Date -Format "yyyyMMdd-HHmmss" }

# Bootstrap (se existir) + fallbacks
$boot = Join-Path $PSScriptRoot "_bootstrap.ps1"
if (Test-Path -LiteralPath $boot) { . $boot }

if (-not (Get-Command EnsureDir -ErrorAction SilentlyContinue)) {
  function EnsureDir([string]$p) { if ($p -and -not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
}
if (-not (Get-Command WriteUtf8NoBom -ErrorAction SilentlyContinue)) {
  function WriteUtf8NoBom([string]$p, [string]$t) {
    EnsureDir (Split-Path -Parent $p)
    [IO.File]::WriteAllText($p, $t, [Text.UTF8Encoding]::new($false))
  }
}
if (-not (Get-Command BackupFile -ErrorAction SilentlyContinue)) {
  function BackupFile([string]$p) {
    if (-not (Test-Path -LiteralPath $p)) { return $null }
    $bkDir = Join-Path $PSScriptRoot "_patch_backup"
    EnsureDir $bkDir
    $ts = Get-Date -Format "yyyyMMdd-HHmmss"
    $leaf = Split-Path -Leaf $p
    $dst = Join-Path $bkDir ($ts + "-" + $leaf + ".bak")
    Copy-Item -LiteralPath $p -Destination $dst -Force
    return $dst
  }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$stamp = _NowTag
Write-Host ("== CV HOTFIX B6V — fix title/title0 in Hub V2 == " + $stamp)
Write-Host ("[DIAG] Repo: " + $repoRoot)

$hubRel = "src/app/c/[slug]/v2/page.tsx"
$hubAbs = Join-Path $repoRoot $hubRel
if (-not (Test-Path -LiteralPath $hubAbs)) { throw ("[STOP] não achei: " + $hubAbs) }

$raw = Get-Content -Raw -LiteralPath $hubAbs

$changed = $false
$raw2 = $raw

# pega qualquer variação de spacing
$hasCore = ($raw2 -match "<Cv2CoreNodes\b")
if (-not $hasCore) { throw "[STOP] não encontrei <Cv2CoreNodes ...> no Hub V2 (talvez a injeção não tenha sido salva)." }

# Caso 1: tem title={title}
if ($raw2 -match "title\s*=\s*\{\s*title\s*\}") {
  if ($raw2 -match "\btitle0\b") {
    $raw2 = [regex]::Replace($raw2, "title\s*=\s*\{\s*title\s*\}", "title={title0}")
    $changed = $true
    Write-Host "[PATCH] troquei title={title} -> title={title0}"
  } else {
    # remove a prop inteira (com espaço antes)
    $raw2 = [regex]::Replace($raw2, "\s+title\s*=\s*\{\s*title\s*\}", "")
    $changed = $true
    Write-Host "[PATCH] removi title={title} (não existe title0)"
  }
}

if (-not $changed) {
  Write-Host "[SKIP] nada para mudar (já está ok ou não existe title={title})."
} else {
  $bk = BackupFile $hubAbs
  if ($bk) { Write-Host ("[BK]    tools/_patch_backup/" + (Split-Path -Leaf $bk)) }
  WriteUtf8NoBom $hubAbs $raw2
  Write-Host ("[OK] patched: " + $hubRel)
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
$rep = Join-Path $repDir ($stamp + "-cv-hotfix-b6v-core-title0.md")

$body = @(
  ("# CV HOTFIX B6V — fix title/title0 (Hub V2) — " + $stamp),
  "",
  ("Repo: " + $repoRoot),
  "",
  "## PATCH",
  ("- " + $hubRel),
  "",
  "## VERIFY",
  ("- lint exit: " + $lintExit),
  ("- build exit: " + $buildExit)
) -join "`n"

WriteUtf8NoBom $rep $body
Write-Host ("[REPORT] reports\" + (Split-Path -Leaf $rep))
Write-Host "[OK] HOTFIX concluído (Hub V2 build OK)."