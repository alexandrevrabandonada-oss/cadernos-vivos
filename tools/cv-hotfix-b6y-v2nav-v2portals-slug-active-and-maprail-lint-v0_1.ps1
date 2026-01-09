# cv-hotfix-b6y-v2nav-v2portals-slug-active-and-maprail-lint-v0_1
$ErrorActionPreference = "Stop"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Write-Host ("== cv-hotfix-b6y-v2nav-v2portals-slug-active-and-maprail-lint-v0_1 == " + $stamp)

$repoRoot = (Resolve-Path ".").Path

# ------------------------------------------------------------
# bootstrap
# ------------------------------------------------------------
$boot = Join-Path $repoRoot "tools\_bootstrap.ps1"
if (Test-Path -LiteralPath $boot) {
  . $boot
} else {
  function EnsureDir([string]$p){ [IO.Directory]::CreateDirectory($p) | Out-Null }
  function WriteUtf8NoBom([string]$p,[string]$c){ $enc=New-Object System.Text.UTF8Encoding($false); [IO.File]::WriteAllText($p,$c,$enc) }
  function BackupFile([string]$p){
    $bkDir = Join-Path $repoRoot "tools\_patch_backup"
    EnsureDir $bkDir
    $leaf = Split-Path -Leaf $p
    $dest = Join-Path $bkDir ($stamp + "-" + $leaf + ".bak")
    Copy-Item -LiteralPath $p -Destination $dest -Force
    return $dest
  }
}

function RunNpm([string[]]$npmArgs) {
  $npm = (Get-Command npm.cmd -ErrorAction Stop).Path
  $out = (& $npm @npmArgs 2>&1 | Out-String)
  return @{ out=$out; code=$LASTEXITCODE }
}

function InferActive([string]$abs) {
  $p = $abs.Replace("\","/").ToLowerInvariant()
  if ($p -match "/v2/mapa/page\.tsx$") { return "mapa" }
  if ($p -match "/v2/linha-do-tempo/page\.tsx$") { return "linha-do-tempo" }
  if ($p -match "/v2/linha/page\.tsx$") { return "linha" }
  if ($p -match "/v2/provas/page\.tsx$") { return "provas" }
  if ($p -match "/v2/trilhas/\[id\]/page\.tsx$") { return "trilhas" }
  if ($p -match "/v2/trilhas/page\.tsx$") { return "trilhas" }
  if ($p -match "/v2/debate/page\.tsx$") { return "debate" }
  if ($p -match "/v2/page\.tsx$") { return "hub" }
  return "hub"
}

Write-Host ("[DIAG] Repo: " + $repoRoot)

# ------------------------------------------------------------
# PATCH A: pages V2 - V2Nav/V2Portals props
# ------------------------------------------------------------
$v2Root = Join-Path $repoRoot "src\app\c\[slug]\v2"
if (-not (Test-Path -LiteralPath $v2Root)) { throw ("[STOP] não achei: " + $v2Root) }

$pages = Get-ChildItem -LiteralPath $v2Root -Recurse -Filter "page.tsx" | ForEach-Object { $_.FullName }
if (-not $pages -or $pages.Count -eq 0) { throw "[STOP] não achei pages V2" }

$patched = New-Object System.Collections.Generic.List[string]

foreach ($abs in $pages) {
  $raw = Get-Content -LiteralPath $abs -Raw
  if (-not $raw) { continue }

  $active = InferActive $abs
  $lines = $raw -split "`r?`n"
  $out = New-Object System.Collections.Generic.List[string]
  $changed = $false

  foreach ($ln0 in $lines) {
    $ln = $ln0

    # ---- V2Nav ----
    if ($ln -match "<V2Nav\b") {
      # só mexe se for self-closing (evita quebrar tag multi-line)
      if ($ln -match "/>") {
        if ($ln -match "\bcurrent=") { $ln = $ln -replace "\bcurrent\s*=", "active="; $changed = $true }
        if ($ln -notmatch "\bslug\s*=") {
          $ln = $ln -replace "<V2Nav\b", "<V2Nav slug={slug}"
          $changed = $true
        }
        if (($ln -notmatch "\bactive\s*=") -and ($ln -notmatch "\bcurrent\s*=")) {
          $ln = $ln -replace "/>\s*$", (" active=""" + $active + """ />")
          $changed = $true
        }
      }
    }

    # ---- V2Portals ----
    if ($ln -match "<V2Portals\b") {
      if ($ln -match "/>") {
        if ($ln -match "\bcurrent=") { $ln = $ln -replace "\bcurrent\s*=", "active="; $changed = $true }
        if ($ln -notmatch "\bslug\s*=") {
          $ln = $ln -replace "<V2Portals\b", "<V2Portals slug={slug}"
          $changed = $true
        }
        if (($ln -notmatch "\bactive\s*=") -and ($ln -notmatch "\bcurrent\s*=")) {
          $ln = $ln -replace "/>\s*$", (" active=""" + $active + """ />")
          $changed = $true
        }
      }
    }

    $out.Add($ln) | Out-Null
  }

  if ($changed) {
    $bk = BackupFile $abs
    $rel = $abs.Substring($repoRoot.Length).TrimStart("\")
    Write-Host ("[PATCH] " + $rel)
    Write-Host ("[BK]    tools/_patch_backup/" + (Split-Path -Leaf $bk))
    WriteUtf8NoBom $abs (($out -join "`n").TrimEnd() + "`n")
    $patched.Add($rel) | Out-Null
  }
}

if ($patched.Count -eq 0) {
  Write-Host "[SKIP] Nenhuma page.tsx V2 precisou ajuste de props."
} else {
  Write-Host ("[DIAG] pages patched: " + $patched.Count)
}

# ------------------------------------------------------------
# PATCH B: Cv2MapRail.tsx - remove eslint-disable no-unused-vars inútil
# ------------------------------------------------------------
$railRel = "src\components\v2\Cv2MapRail.tsx"
$railAbs = Join-Path $repoRoot $railRel
if (Test-Path -LiteralPath $railAbs) {
  $r = Get-Content -LiteralPath $railAbs
  $r2 = New-Object System.Collections.Generic.List[string]
  $railChanged = $false

  foreach ($l in $r) {
    $trim = $l.Trim()
    $isDisable =
      ($trim -eq "/* eslint-disable @typescript-eslint/no-unused-vars */") -or
      ($trim -eq "// eslint-disable-next-line @typescript-eslint/no-unused-vars") -or
      ($trim -eq "// eslint-disable @typescript-eslint/no-unused-vars")

    if ($isDisable) { $railChanged = $true; continue }
    $r2.Add($l) | Out-Null
  }

  if ($railChanged) {
    $bk = BackupFile $railAbs
    Write-Host ("[PATCH] " + $railRel + " (remove unused eslint-disable no-unused-vars)")
    Write-Host ("[BK]    tools/_patch_backup/" + (Split-Path -Leaf $bk))
    WriteUtf8NoBom $railAbs (($r2 -join "`n").TrimEnd() + "`n")
  } else {
    Write-Host ("[SKIP] " + $railRel + " sem eslint-disable no-unused-vars no topo (ou já limpo).")
  }
} else {
  Write-Host ("[SKIP] " + $railRel + " não existe (ok).")
}

# ------------------------------------------------------------
# VERIFY
# ------------------------------------------------------------
$verify = Join-Path $repoRoot "tools\cv-verify.ps1"
if (Test-Path -LiteralPath $verify) {
  Write-Host ("[RUN] " + $verify)
  & $verify
  if ($LASTEXITCODE -ne 0) { throw ("[STOP] cv-verify falhou (exit=" + $LASTEXITCODE + ")") }
}

Write-Host "[RUN] npm run lint"
$r1 = RunNpm @("run","lint")
Write-Host $r1.out
if ($r1.code -ne 0) { throw ("[STOP] lint falhou (exit=" + $r1.code + ")") }

Write-Host "[RUN] npm run build"
$r2 = RunNpm @("run","build")
Write-Host $r2.out
if ($r2.code -ne 0) { throw ("[STOP] build falhou (exit=" + $r2.code + ")") }

# ------------------------------------------------------------
# REPORT
# ------------------------------------------------------------
$repDir = Join-Path $repoRoot "reports"
EnsureDir $repDir
$rep = Join-Path $repDir ($stamp + "-cv-hotfix-b6y-v2nav-v2portals-props.md")

$body = @(
("# CV HOTFIX B6Y — V2Nav/V2Portals props (slug+active) + MapRail lint — " + $stamp),
"",
("Repo: " + $repoRoot),
"",
"## PATCH",
"Pages patched:",
($patched | ForEach-Object { "  - " + $_ }),
("- MapRail: " + $railRel),
"",
"## VERIFY",
("- lint exit: " + $r1.code),
("- build exit: " + $r2.code)
) -join "`n"

WriteUtf8NoBom $rep ($body + "`n")
Write-Host ("[REPORT] reports/" + (Split-Path -Leaf $rep))
Write-Host "[OK] HOTFIX B6Y concluído (props consistentes + lint/build ok)."