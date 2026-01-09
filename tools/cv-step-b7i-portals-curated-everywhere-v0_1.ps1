# == cv-step-b7i-portals-curated-everywhere-v0_1 ==
# Portais V2: trocar V2Portals -> Cv2PortalsCurated em todas as portas V2 (+ coreNodes quando possível)
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

function NowStamp() { return (Get-Date).ToString("yyyyMMdd-HHmmss") }

function EnsureDir([string]$p) {
  if ([string]::IsNullOrWhiteSpace($p)) { return }
  if (!(Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

function WriteUtf8NoBom([string]$path, [string]$content) {
  $enc = New-Object System.Text.UTF8Encoding($false)
  [IO.File]::WriteAllText($path, $content, $enc)
}

function BackupFile([string]$root, [string]$absPath) {
  if (!(Test-Path -LiteralPath $absPath)) { return }
  $bkRoot = Join-Path $root "tools/_patch_backup"
  EnsureDir $bkRoot
  $rel = $absPath.Substring($root.Length).TrimStart('\','/')
  $relSafe = $rel -replace '[\\/:*?"<>|]', '_'
  $dst = Join-Path $bkRoot ((NowStamp) + "__" + $relSafe)
  Copy-Item -Force $absPath $dst
}

function FindAllV2PortalUsages([string]$root) {
  $base = Join-Path $root "src/app/c/[slug]/v2"
  if (!(Test-Path -LiteralPath $base)) { return @() }
  $files = Get-ChildItem -Path $base -Recurse -File -Filter "page.tsx" -ErrorAction SilentlyContinue
  $hits = @()
  foreach ($f in $files) {
    $raw = Get-Content -Raw -Encoding UTF8 $f.FullName
    if ($raw -match "<V2Portals\b") { $hits += $f.FullName }
  }
  return $hits
}

function DetectCoreExpr([string]$raw) {
  # tenta achar uma expressão segura pra coreNodes
  if ($raw -match "\bdata\.meta\b") { return "data.meta.coreNodes" }
  if ($raw -match "\bcaderno\.meta\b") { return "caderno.meta.coreNodes" }

  # meta pode existir como variável (const meta = ... | const { meta } = ...)
  if ($raw -match "const\s+meta\s*=") { return "meta.coreNodes" }
  if ($raw -match "const\s*\{\s*meta\s*\}\s*=") { return "meta.coreNodes" }
  if ($raw -match "\bmeta\b" -and $raw -match "\bmeta\.\w+") { return "meta.coreNodes" }

  return $null
}

function PatchOne([string]$root, [string]$filePath, [System.Collections.Generic.List[string]]$log) {
  if (!(Test-Path -LiteralPath $filePath)) { return }

  $raw = Get-Content -Raw -Encoding UTF8 $filePath
  $orig = $raw
  $changed = $false

  $coreExpr = DetectCoreExpr $raw

  # 1) import: V2Portals -> Cv2PortalsCurated
  $importV2 = 'import V2Portals from "@/components/v2/V2Portals";'
  $importCv2 = 'import Cv2PortalsCurated from "@/components/v2/Cv2PortalsCurated";'

  if ($raw -like "*$importV2*") {
    if ($raw -like "*$importCv2*") {
      # já tem Cv2PortalsCurated: remove import do V2Portals
      $raw = $raw -replace [Regex]::Escape($importV2) + "\r?\n", ""
    } else {
      $raw = $raw -replace [Regex]::Escape($importV2), $importCv2
    }
    $changed = $true
  } else {
    # variações (aspas simples / espaçamento)
    $rxImp = [regex]'import\s+V2Portals\s+from\s+["'']@/components/v2/V2Portals["''];'
    if ($rxImp.IsMatch($raw)) {
      if ($raw -notmatch 'import\s+Cv2PortalsCurated\s+from\s+["'']@/components/v2/Cv2PortalsCurated["''];') {
        $raw = $rxImp.Replace($raw, $importCv2)
      } else {
        $raw = $rxImp.Replace($raw, "")
      }
      $changed = $true
    }
  }

  # 2) JSX: <V2Portals ... /> -> <Cv2PortalsCurated ... coreNodes={...} />
  if ($raw -match "<V2Portals\b") {
    $rx = New-Object System.Text.RegularExpressions.Regex("<V2Portals\b[^>]*\/>", [System.Text.RegularExpressions.RegexOptions]::Singleline)
    $m = $rx.Matches($raw)
    if ($m.Count -gt 0) {
      foreach ($mm in $m) {
        $tag = $mm.Value
        $newTag = $tag.Replace("<V2Portals", "<Cv2PortalsCurated")

        if (($null -ne $coreExpr) -and ($newTag -notmatch "\bcoreNodes\s*=")) {
          # injeta antes do "/>"
          $newTag = $newTag -replace "\s*\/>$", (" coreNodes={" + $coreExpr + "} />")
        }
        if ($newTag -ne $tag) {
          $raw = $raw.Replace($tag, $newTag)
          $changed = $true
        }
      }
    }
  }

  if ($changed -and ($raw -ne $orig)) {
    BackupFile $root $filePath
    WriteUtf8NoBom $filePath $raw
    $log.Add("[PATCH] updated: " + $filePath + ($coreExpr ? (" (coreNodes=" + $coreExpr + ")") : " (coreNodes=none)")) | Out-Null
  } else {
    $log.Add("[OK] no change: " + $filePath) | Out-Null
  }
}
function RunCmd {
  param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [object[]]$all
  )
  if (-not $all -or $all.Count -lt 1) { throw "RunCmd: missing cmd" }
  $cmd = [string]$all[0]
  $rest = @()
  if ($all.Count -gt 1) { $rest = $all[1..($all.Count-1)] }
  $cwd = $null
  $argsList = New-Object System.Collections.Generic.List[string]
  foreach ($x in $rest) {
    if (-not $cwd -and $x -is [string]) {
      $s = [string]$x
      if (Test-Path -LiteralPath $s -PathType Container) {
        $pj = Join-Path $s "package.json"
        if (Test-Path -LiteralPath $pj) { $cwd = $s; continue }
      }
    }
    if ($x -is [string[]]) {
      foreach ($y in $x) { if ($y -ne $null -and ([string]$y) -ne "") { $argsList.Add([string]$y) | Out-Null } }
    } elseif ($x -is [System.Collections.IEnumerable] -and -not ($x -is [string])) {
      foreach ($y in $x) { if ($y -ne $null -and ([string]$y) -ne "") { $argsList.Add([string]$y) | Out-Null } }
    } else {
      if ($x -ne $null -and ([string]$x) -ne "") { $argsList.Add([string]$x) | Out-Null }
    }
  }
  if (-not $cwd) { $cwd = (Resolve-Path ".").Path }
  $cmdArgs = @($argsList.ToArray())
  $old = Get-Location
  try {
    Set-Location $cwd
    Write-Host ("[RUN] " + $cmd + ($(if($cmdArgs.Count -gt 0){ " " + ($cmdArgs -join " ") } else { "" })))
    $out = & $cmd @cmdArgs 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw ("Command failed: " + $cmd + " " + ($cmdArgs -join " ") + "`n" + $out) }
    return $out.TrimEnd()
  } finally {
    Set-Location $old
  }
}


# ---------------- main
$root = (Resolve-Path ".").Path
$stamp = NowStamp
$title = "Tijolo B7I — Portais curados (Cv2PortalsCurated) em todas as portas V2 — " + $stamp

$log = New-Object System.Collections.Generic.List[string]
$log.Add("# " + $title) | Out-Null
$log.Add("") | Out-Null
$log.Add("Repo: " + $root) | Out-Null
$log.Add("") | Out-Null

# DIAG
$hitsPre = FindAllV2PortalUsages $root
$log.Add("## DIAG (pre)") | Out-Null
$log.Add("") | Out-Null
$log.Add("- V2Portals occurrences (files): " + $hitsPre.Count) | Out-Null
foreach ($h in $hitsPre) { $log.Add("  - " + $h) | Out-Null }
$log.Add("") | Out-Null

# PATCH
$log.Add("## PATCH") | Out-Null
$log.Add("") | Out-Null

foreach ($fp in $hitsPre) {
  PatchOne $root $fp $log
}
$log.Add("") | Out-Null

# DIAG post
$hitsPost = FindAllV2PortalUsages $root
$log.Add("## DIAG (post)") | Out-Null
$log.Add("") | Out-Null
$log.Add("- remaining '<V2Portals' files: " + $hitsPost.Count) | Out-Null
foreach ($h in $hitsPost) { $log.Add("  - " + $h) | Out-Null }
$log.Add("") | Out-Null

# VERIFY
$log.Add("## VERIFY") | Out-Null
$log.Add("") | Out-Null

$npm = $null
try { $npm = (Get-Command npm.cmd -ErrorAction Stop).Source } catch { $npm = "npm.cmd" }

try {
  RunCmd $npm @("run","lint")
  $log.Add("- npm run lint: OK") | Out-Null
} catch {
  $log.Add("- npm run lint: FAIL") | Out-Null
  $log.Add("  " + $_.Exception.Message) | Out-Null
  throw
}

try {
  RunCmd $npm @("run","build")
  $log.Add("- npm run build: OK") | Out-Null
} catch {
  $log.Add("- npm run build: FAIL") | Out-Null
  $log.Add("  " + $_.Exception.Message) | Out-Null
  throw
}

# REPORT
EnsureDir (Join-Path $root "reports")
$reportPath = Join-Path $root ("reports/" + $stamp + "-cv-step-b7i-portals-curated-everywhere.md")
WriteUtf8NoBom $reportPath ($log -join "`r`n")
Write-Host ("OK: report -> " + $reportPath)
