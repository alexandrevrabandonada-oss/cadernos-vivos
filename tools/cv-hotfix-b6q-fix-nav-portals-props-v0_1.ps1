param()
$ErrorActionPreference = "Stop"

# repoRoot robusto (script em tools/)
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Write-Host ("== cv-hotfix-b6q-fix-nav-portals-props-v0_1 == " + (Get-Date).ToString("yyyyMMdd-HHmmss"))
Write-Host ("[DIAG] Repo: " + $repoRoot)

function EnsureDir([string]$p) { if (!(Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function BackupFile([string]$p) {
  $bkDir = Join-Path $repoRoot "tools\_patch_backup"
  EnsureDir $bkDir
  $stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
  $leaf  = Split-Path -Leaf $p
  $bk    = Join-Path $bkDir ($stamp + "-" + $leaf + ".bak")
  Copy-Item -LiteralPath $p -Destination $bk -Force
  return $bk
}
function WriteUtf8NoBom([string]$p, [string]$s) { [IO.File]::WriteAllText($p, $s, [Text.UTF8Encoding]::new($false)) }

$patched = @()
$v2Dir = Join-Path $repoRoot "src\app\c\[slug]\v2"
if (!(Test-Path -LiteralPath $v2Dir)) { throw ("[STOP] não achei: " + $v2Dir) }

Write-Host ("[DIAG] scanning: " + $v2Dir)
$pages = Get-ChildItem -LiteralPath $v2Dir -Recurse -File -Filter page.tsx

foreach ($f in $pages) {
  $raw = Get-Content -Raw -LiteralPath $f.FullName
  $p   = $raw

  # 1) V2Nav: current= -> active=
  $p = ($p -replace "<V2Nav([^>]*?)\scurrent=", "<V2Nav$1 active=")

  # 2) V2Portals: active= -> current=
  $p = ($p -replace "<V2Portals([^>]*?)\sactive=", "<V2Portals$1 current=")

  if ($p -ne $raw) {
    $bk = BackupFile $f.FullName
    WriteUtf8NoBom $f.FullName $p
    $rel = $f.FullName.Substring($repoRoot.Length + 1)
    $patched += $rel
    Write-Host ("[PATCH] " + $rel)
    Write-Host ("[BK]    tools\_patch_backup\" + (Split-Path -Leaf $bk))
  }
}

if ($patched.Count -eq 0) {
  Write-Host "[SKIP] nenhuma página V2 precisou ajuste de props (V2Nav/V2Portals)."
}

# VERIFY (usa caminho real do npm pra não cair em npmExe/cmd.Source)
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
$stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
$rep = Join-Path $repDir ($stamp + "-cv-hotfix-b6q-fix-nav-portals-props.md")

$body = @(
  ("# CV HOTFIX B6Q — props V2Nav/V2Portals — " + $stamp),
  "",
  ("Repo: " + $repoRoot),
  "",
  "## PATCH",
  (if ($patched.Count -gt 0) { ($patched | Sort-Object -Unique | ForEach-Object { "- " + $_ }) } else { "- (nenhuma mudança)" }),
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
Write-Host "[OK] B6Q concluído (props padronizadas + lint/build OK)."
