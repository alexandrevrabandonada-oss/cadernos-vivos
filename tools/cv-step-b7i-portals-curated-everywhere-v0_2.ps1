# cv-step-b7i-portals-curated-everywhere-v0_2
# Portais V2: trocar V2Portals -> Cv2PortalsCurated em todas as portas V2 (+ coreNodes quando possível)
# DIAG → PATCH → VERIFY → REPORT (report sempre sai)
$ErrorActionPreference = "Stop"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$repoRoot = (Resolve-Path ".").Path
$nl = [Environment]::NewLine

function EnsureDir([string]$abs) { if (-not (Test-Path -LiteralPath $abs)) { [IO.Directory]::CreateDirectory($abs) | Out-Null } }
function ReadText([string]$abs) { if (-not (Test-Path -LiteralPath $abs)) { return $null }; return [IO.File]::ReadAllText($abs) }
function WriteText([string]$abs, [string]$text) { $enc = New-Object System.Text.UTF8Encoding($false); EnsureDir (Split-Path -Parent $abs); [IO.File]::WriteAllText($abs, $text, $enc) }
function BackupFile([string]$rel) {
  $abs = Join-Path $repoRoot $rel
  if (-not (Test-Path -LiteralPath $abs)) { return }
  $bkDir = Join-Path $repoRoot "tools\_patch_backup"
  EnsureDir $bkDir
  $dst = Join-Path $bkDir ($stamp + "-" + (Split-Path -Leaf $abs) + ".bak")
  Copy-Item -LiteralPath $abs -Destination $dst -Force
}

function FindV2PagesWith([string]$needle) {
  $base = Join-Path $repoRoot "src\app\c\[slug]\v2"
  if (-not (Test-Path -LiteralPath $base)) { return @() }
  $files = Get-ChildItem -LiteralPath $base -Recurse -File -Filter "page.tsx" -ErrorAction SilentlyContinue
  $hits = @()
  foreach ($f in $files) {
    $raw = ReadText $f.FullName
    if ($null -ne $raw -and $raw.Contains($needle)) { $hits += $f.FullName }
  }
  return $hits
}

function DetectCoreExpr([string]$raw) {
  if ($null -eq $raw) { return $null }
  if ($raw -match "\bdata\.meta\b") { return "data.meta?.coreNodes" }
  if ($raw -match "\bcaderno\.meta\b") { return "caderno.meta?.coreNodes" }
  if ($raw -match "\bdoc\.meta\b") { return "doc.meta?.coreNodes" }
  if ($raw -match "const\s+meta\s*=" -or $raw -match "const\s*\{\s*meta\s*\}\s*=") { return "meta?.coreNodes" }
  return $null
}

function PatchFile([string]$abs) {
  $raw = ReadText $abs
  if ($null -eq $raw) { return @{ changed=$false; note="empty" } }
  $orig = $raw
  $coreExpr = DetectCoreExpr $raw

  # Import swap / remove
  $raw = $raw.Replace('import V2Portals from "@/components/v2/V2Portals";', 'import Cv2PortalsCurated from "@/components/v2/Cv2PortalsCurated";')

  # Se já tem Cv2PortalsCurated e ainda sobrou import V2Portals (variante), remove por regex simples
  $hasCv2Import = ($raw -match 'import\s+Cv2PortalsCurated\s+from\s+"@/components/v2/Cv2PortalsCurated";' -or
                   $raw -match 'import\s+Cv2PortalsCurated\s+from\s+''@/components/v2/Cv2PortalsCurated'';')
  if ($hasCv2Import) {
    $raw = [regex]::Replace($raw, '^\s*import\s+V2Portals\s+from\s+"@/components/v2/V2Portals";\s*\r?\n', "", [System.Text.RegularExpressions.RegexOptions]::Multiline)
    $raw = [regex]::Replace($raw, '^\s*import\s+V2Portals\s+from\s+''@/components/v2/V2Portals'';\s*\r?\n', "", [System.Text.RegularExpressions.RegexOptions]::Multiline)
  }

  # JSX: troca tags (self-closing e par)
  if ($raw.Contains("<V2Portals")) {
    $raw = $raw.Replace("<V2Portals", "<Cv2PortalsCurated")
    $raw = $raw.Replace("</V2Portals>", "</Cv2PortalsCurated>")
  }

  # Injetar coreNodes nas tags self-closing que não tenham coreNodes ainda
  if ($coreExpr) {
    $raw = [regex]::Replace(
      $raw,
      '<Cv2PortalsCurated\b([^>]*)\/>',
      {
        param($m)
        $attrs = $m.Groups[1].Value
        if ($attrs -match '\bcoreNodes\s*=') { return $m.Value }
        return '<Cv2PortalsCurated' + $attrs + ' coreNodes={' + $coreExpr + '} />'
      },
      [System.Text.RegularExpressions.RegexOptions]::Singleline
    )
  }

  $changed = ($raw -ne $orig)
  if ($changed) {
    # backup usando rel
    $rel = $abs.Substring($repoRoot.Length).TrimStart('\','/')
    BackupFile $rel
    WriteText $abs ($raw.TrimEnd() + $nl)
  }

  return @{ changed=$changed; core=$coreExpr }
}

# ---------- main ----------
EnsureDir (Join-Path $repoRoot "reports")
EnsureDir (Join-Path $repoRoot "tools\_patch_backup")

$rep = Join-Path $repoRoot ("reports\" + $stamp + "-cv-step-b7i-portals-curated-everywhere.md")
$r = New-Object System.Collections.Generic.List[string]
$r.Add("# Tijolo B7I v0_2 — Portais curados (Cv2PortalsCurated) everywhere — " + $stamp) | Out-Null
$r.Add("") | Out-Null
$r.Add("Repo: " + $repoRoot) | Out-Null
$r.Add("") | Out-Null

# DIAG pre
$hitsPre = FindV2PagesWith "<V2Portals"
$r.Add("## DIAG (pre)") | Out-Null
$r.Add("") | Out-Null
$r.Add("- files with <V2Portals: " + $hitsPre.Count) | Out-Null
foreach ($h in $hitsPre) { $r.Add("  - " + $h) | Out-Null }
$r.Add("") | Out-Null

# PATCH
$r.Add("## PATCH") | Out-Null
$r.Add("") | Out-Null

# Mesmo se não achar <V2Portals, ainda vamos procurar por import V2Portals
$targets = @()
$targets += $hitsPre
$hitsImp = FindV2PagesWith 'import V2Portals'
foreach ($h in $hitsImp) { if (-not ($targets -contains $h)) { $targets += $h } }

if ($targets.Count -eq 0) {
  $r.Add("- nada a fazer: não achei <V2Portals nem import V2Portals nas pages V2") | Out-Null
  $r.Add("") | Out-Null
} else {
  foreach ($fp in $targets) {
    $res = PatchFile $fp
    if ($res.changed) {
      $r.Add("[PATCH] " + $fp + ($(if($res.core){ " (coreNodes=" + $res.core + ")" } else { " (coreNodes=none)" }))) | Out-Null
    } else {
      $r.Add("[OK] no change: " + $fp) | Out-Null
    }
  }
  $r.Add("") | Out-Null
}

# DIAG post
$hitsPost = FindV2PagesWith "<V2Portals"
$r.Add("## DIAG (post)") | Out-Null
$r.Add("") | Out-Null
$r.Add("- remaining files with <V2Portals: " + $hitsPost.Count) | Out-Null
foreach ($h in $hitsPost) { $r.Add("  - " + $h) | Out-Null }
$r.Add("") | Out-Null

# VERIFY (sempre escreve report; se falhar, marca e dá throw no fim)
$failed = $false

function RunNpm([string[]]$argv) {
  $npmCmd = $null
  try { $npmCmd = (Get-Command npm.cmd -ErrorAction Stop).Path } catch { $npmCmd = $null }
  if (-not $npmCmd) {
    try { $npmCmd = (Get-Command npm -ErrorAction Stop).Path } catch { $npmCmd = "npm.cmd" }
  }

  $cmdLine = "[RUN] " + $npmCmd + " " + ($argv -join " ")
  Write-Host $cmdLine
  & $npmCmd @argv
  if ($LASTEXITCODE -ne 0) { throw ("npm failed: " + ($argv -join " ")) }
}

$r.Add("## VERIFY") | Out-Null
$r.Add("") | Out-Null

try {
  RunNpm @("run","lint")
  $r.Add("- npm run lint: OK") | Out-Null
} catch {
  $failed = $true
  $r.Add("- npm run lint: FAIL") | Out-Null
  $r.Add("  " + $_.Exception.Message) | Out-Null
}

try {
  RunNpm @("run","build")
  $r.Add("- npm run build: OK") | Out-Null
} catch {
  $failed = $true
  $r.Add("- npm run build: FAIL") | Out-Null
  $r.Add("  " + $_.Exception.Message) | Out-Null
}

$r.Add("") | Out-Null
$r.Add("## Git status (post)") | Out-Null
try { $r.Add((git status | Out-String).TrimEnd()) | Out-Null } catch { $r.Add("ERR: git status") | Out-Null }
$r.Add("") | Out-Null

WriteText $rep ([string]::Join($nl, $r.ToArray()) + $nl)
Write-Host ("[REPORT] " + $rep)

if ($failed) { throw "B7I v0_2: verify failed (see report)." }
Write-Host "[OK] B7I v0_2 finalizado."