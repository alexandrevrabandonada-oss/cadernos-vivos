$ErrorActionPreference = "Stop"

function _NowTag { Get-Date -Format "yyyyMMdd-HHmmss" }

# Bootstrap
$boot = Join-Path $PSScriptRoot "_bootstrap.ps1"
if (Test-Path -LiteralPath $boot) { . $boot }

# Fallbacks (caso rode fora do contexto esperado)
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
Write-Host ("== CV HOTFIX — Mindmap lint (remove useCallback onKeyDown) v0_1 == " + $stamp)
Write-Host ("[DIAG] Repo: " + $repoRoot)

$rel = "src/components/v2/Cv2MindmapHubClient.tsx"
$abs = Join-Path $repoRoot $rel

if (-not (Test-Path -LiteralPath $abs)) {
  throw ("[STOP] não achei: " + $abs)
}

$lines = Get-Content -LiteralPath $abs
$changed = $false

# acha linha do useCallback do onKeyDown
$start = -1
for ($i=0; $i -lt $lines.Count; $i++) {
  if ($lines[$i] -match "const\s+onKeyDown\s*=\s*React\.useCallback\s*\(") { $start = $i; break }
}

if ($start -ge 0) {
  # troca a linha de abertura: React.useCallback((e...) => {  ==> (e...) => {
  $indent = ($lines[$start] -replace "^(\s*).*",'$1')
  # tenta preservar assinatura de evento dentro dos parênteses, mas remove wrapper
  # exemplo esperado: const onKeyDown = React.useCallback((e: React.KeyboardEvent) => {
  $lines[$start] = ($lines[$start] -replace "const\s+onKeyDown\s*=\s*React\.useCallback\s*\(\s*\(", "const onKeyDown = (") 
  $lines[$start] = ($lines[$start] -replace "\)\s*=>\s*\{", ") => {") # garante formato

  # acha a linha que fecha o callback com deps: "}, [ ... ]);" ou algo equivalente
  $close = -1
  for ($j=$start+1; $j -lt $lines.Count; $j++) {
    if ($lines[$j] -match "^\s*\},\s*\[") { $close = $j; break }
  }

  if ($close -lt 0) {
    Write-Host "[WARN] achei start do onKeyDown, mas não achei a linha '}, [deps])'. SKIP."
  } else {
    $indent2 = ($lines[$close] -replace "^(\s*).*",'$1')
    $lines[$close] = ($indent2 + "};")

    # se a próxima linha for só ']);' (deps em múltiplas linhas), remove
    if ($close + 1 -lt $lines.Count) {
      if ($lines[$close + 1] -match "^\s*\]\)\;\s*$" -or $lines[$close + 1] -match "^\s*\]\);\s*$") {
        $lines = @($lines[0..$close] + $lines[($close+2)..($lines.Count-1)])
      }
    }

    $changed = $true
    $bk = BackupFile $abs
    if ($bk) { Write-Host ("[BK] " + $bk) }
    WriteUtf8NoBom $abs ($lines -join "`n")
    Write-Host ("[PATCH] " + $rel + " (removed React.useCallback wrapper)")
  }
} else {
  Write-Host "[SKIP] não achei 'const onKeyDown = React.useCallback(' — nada pra fazer."
}

# ------------------------------------------------------------
# VERIFY
# ------------------------------------------------------------
$npm = (Get-Command npm.cmd -ErrorAction Stop).Path
$verifyAbs = Join-Path $repoRoot "tools/cv-verify.ps1"

Write-Host "[RUN] npm run lint"
$lintOut = (& $npm run lint 2>&1 | Out-String)
$lintExit = $LASTEXITCODE
if ($lintExit -ne 0) { Write-Host $lintOut; throw ("[STOP] lint falhou (exit=" + $lintExit + ")") }

Write-Host "[RUN] npm run build"
$buildOut = (& $npm run build 2>&1 | Out-String)
$buildExit = $LASTEXITCODE
if ($buildExit -ne 0) { Write-Host $buildOut; throw ("[STOP] build falhou (exit=" + $buildExit + ")") }

if (Test-Path -LiteralPath $verifyAbs) {
  Write-Host ("[RUN] " + $verifyAbs)
  & pwsh -NoProfile -ExecutionPolicy Bypass -File $verifyAbs
  if ($LASTEXITCODE -ne 0) { throw ("[STOP] cv-verify falhou (exit=" + $LASTEXITCODE + ")") }
}

# ------------------------------------------------------------
# REPORT
# ------------------------------------------------------------
$repDir = Join-Path $repoRoot "reports"
EnsureDir $repDir
$rep = Join-Path $repDir ($stamp + "-cv-hotfix-b5d-mindmap-lint.md")

$body = @(
  ("# CV HOTFIX — Mindmap lint (onKeyDown) — " + $stamp),
  "",
  ("Repo: " + $repoRoot),
  "",
  "## PATCH",
  ("- " + $rel),
  ("- changed: " + $changed),
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
Write-Host "[OK] HOTFIX concluído (Mindmap sem preserve-manual-memoization)."