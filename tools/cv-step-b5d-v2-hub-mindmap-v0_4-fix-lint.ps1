$ErrorActionPreference = "Stop"

function _NowTag { Get-Date -Format "yyyyMMdd-HHmmss" }

# --- Bootstrap (preferencial) ---
$boot = Join-Path $PSScriptRoot "_bootstrap.ps1"
if (Test-Path -LiteralPath $boot) { . $boot }

# --- Fallbacks (se bootstrap nao existir) ---
if (-not (Get-Command EnsureDir -ErrorAction SilentlyContinue)) {
  function EnsureDir([string]$p) { if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
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

function FindBraceBlock([string]$text, [int]$startIndex) {
  # assume que em startIndex existe o começo do token; acha o primeiro "{", e fecha contando chaves
  $open = $text.IndexOf("{", $startIndex)
  if ($open -lt 0) { return $null }
  $depth = 0
  for ($i = $open; $i -lt $text.Length; $i++) {
    $ch = $text[$i]
    if ($ch -eq "{") { $depth++ }
    elseif ($ch -eq "}") { $depth-- ; if ($depth -eq 0) { return @{ Open=$open; Close=$i } } }
  }
  return $null
}

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ts = _NowTag
Write-Host ("== cv-step-b5d v0_4 (fix lint deps) == " + $ts)
Write-Host ("[DIAG] Repo: " + $root)

$compAbs = Join-Path $root "src\components\v2\Cv2MindmapHubClient.tsx"
if (-not (Test-Path -LiteralPath $compAbs)) { throw ("[STOP] nao achei: " + $compAbs) }

$raw = Get-Content -LiteralPath $compAbs -Raw
$changed = $false

# 1) focus: function -> useCallback
$needle = "function focus(i: number) {"
$idx = $raw.IndexOf($needle)
if ($idx -ge 0) {
  $blk = FindBraceBlock $raw $idx
  if (-not $blk) { throw "[STOP] nao consegui brace-match do focus()" }

  $start = $idx
  $end = $blk.Close
  $old = $raw.Substring($start, ($end - $start + 1))

  $new = @"
  const focus = React.useCallback((i: number) => {
    const idx = (i + nodes.length) % nodes.length;
    setActive(idx);
    requestAnimationFrame(() => {
      const el = refs.current[idx];
      if (el) el.focus();
    });
  }, [nodes.length]);
"@

  $raw = $raw.Substring(0, $start) + $new + $raw.Substring($end + 1)
  $changed = $true
  Write-Host "[PATCH] focus() virou useCallback com deps [nodes.length]"
} else {
  Write-Host "[SKIP] nao achei 'function focus(i: number) {' (talvez ja corrigido)"
}

# 2) onKeyDown deps: [active, nodes.length] -> [active, focus]
# (fazemos por regex simples)
$before = $raw
$raw = [regex]::Replace($raw, "\}\s*,\s*\[\s*active\s*,\s*nodes\.length\s*\]\s*\)\s*;", "}, [active, focus]);")
if ($raw -ne $before) {
  $changed = $true
  Write-Host "[PATCH] onKeyDown deps -> [active, focus]"
} else {
  Write-Host "[SKIP] nao achei deps exatamente como [active, nodes.length] (talvez ja esteja ok)"
}

if ($changed) {
  $bk = BackupFile $compAbs
  if ($bk) { Write-Host ("[BK] " + $bk) }
  WriteUtf8NoBom $compAbs $raw
  Write-Host ("[OK] patched: " + $compAbs)
} else {
  Write-Host "[OK] nada pra mudar."
}

# VERIFY
$verify = Join-Path $root "tools\cv-verify.ps1"
if (Test-Path -LiteralPath $verify) {
  Write-Host ("[RUN] " + $verify)
  & pwsh -NoProfile -ExecutionPolicy Bypass -File $verify
  if ($LASTEXITCODE -ne 0) { throw ("[STOP] cv-verify falhou (exit=" + $LASTEXITCODE + ")") }
} else {
  $npm = (Get-Command npm.cmd -ErrorAction Stop).Path
  Write-Host "[RUN] npm run lint"
  & $npm run lint
  if ($LASTEXITCODE -ne 0) { throw ("[STOP] lint falhou (exit=" + $LASTEXITCODE + ")") }
  Write-Host "[RUN] npm run build"
  & $npm run build
  if ($LASTEXITCODE -ne 0) { throw ("[STOP] build falhou (exit=" + $LASTEXITCODE + ")") }
}

# REPORT
$repDir = Join-Path $root "reports"
EnsureDir $repDir
$rep = Join-Path $repDir ("cv-step-b5d-v2-hub-mindmap-fixlint-" + $ts + ".md")
$repText = @(
  "# CV — B5d v0_4 — Fix lint (React Compiler deps)",
  "",
  "- when: " + $ts,
  "- file: src/components/v2/Cv2MindmapHubClient.tsx",
  "",
  "## Changes",
  "- focus() -> useCallback deps [nodes.length]",
  "- onKeyDown deps -> [active, focus]",
  "",
  "## Verify",
  "- OK"
) -join "`r`n"
WriteUtf8NoBom $rep $repText
Write-Host ("[REPORT] " + $rep)

Write-Host "[DONE] Lint deve passar agora."