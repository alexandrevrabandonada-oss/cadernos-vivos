# cv-step-b5k2-v2-hub-fix-unclosed-div-v0_1.ps1
# Fix: JSX <div> sem fechamento no Hub V2 + remove eslint-disable inútil no Cv2MapRail
# Fluxo: DIAG -> PATCH -> VERIFY -> REPORT

$ErrorActionPreference = "Stop"

function Get-Root {
  (Resolve-Path ".").Path
}

$root = Get-Root

# --- bootstrap (preferir tools/_bootstrap.ps1) ---
$bootstrap = Join-Path $root "tools/_bootstrap.ps1"
if (Test-Path $bootstrap) {
  . $bootstrap
} else {
  function EnsureDir([string]$p) { if (-not (Test-Path $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
  function WriteUtf8NoBom([string]$p, [string]$content) {
    EnsureDir (Split-Path -Parent $p)
    $enc = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($p, $content, $enc)
  }
  function BackupFile([string]$p) {
    if (-not (Test-Path $p)) { return $null }
    $bkDir = Join-Path $root "tools/_patch_backup"
    EnsureDir $bkDir
    $stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
    $name = (Split-Path $p -Leaf)
    $bk = Join-Path $bkDir ($stamp + "-" + $name + ".bak")
    Copy-Item -Force $p $bk
    return $bk
  }
  function Run([string]$cmd, [string[]]$args) {
    Write-Host ("[RUN] " + $cmd + " " + ($args -join " "))
    $p = Start-Process -FilePath $cmd -ArgumentList $args -NoNewWindow -Wait -PassThru
    if ($p.ExitCode -ne 0) { throw ("[STOP] falhou (exit " + $p.ExitCode + "): " + $cmd + " " + ($args -join " ")) }
  }
}

$stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
Write-Host ("== cv-step-b5k2-v2-hub-fix-unclosed-div-v0_1 == " + $stamp)
Write-Host ("[DIAG] Repo: " + $root)

# --- targets ---
$hub = Join-Path $root "src/app/c/[slug]/v2/page.tsx"
if (-not (Test-Path $hub)) { throw ("[STOP] não achei: " + $hub) }

$mapRail = Join-Path $root "src/components/v2/Cv2MapRail.tsx"

# --- helpers ---
function Count-OpeningDivTags([string]$raw) {
  # match <div ...> inclusive multiline; ignore </div> and self-closing <div ... />
  $matches = [regex]::Matches($raw, "<div\b[^>]*>", [Text.RegularExpressions.RegexOptions]::Singleline)
  $open = 0
  foreach ($m in $matches) {
    $v = $m.Value
    if ($v -match "^</div") { continue }
    if ($v -match "<div\b[^>]*\/\s*>$") { continue } # self closing
    $open++
  }
  return $open
}

function Get-IndentBeforeMainClose([string]$raw) {
  # pega a indentação do </main> final
  $rx = [regex]::new("(\r?\n)(\s*)</main>", [Text.RegularExpressions.RegexOptions]::RightToLeft)
  $m = $rx.Match($raw)
  if ($m.Success) { return $m.Groups[2].Value }
  return "  "
}

# --- DIAG hub ---
$raw = Get-Content -Raw $hub
$openDiv = Count-OpeningDivTags $raw
$closeDiv = ([regex]::Matches($raw, "</div>")).Count
$missing = $openDiv - $closeDiv

$legacyHits = ([regex]::Matches($raw, "Núcleo do universo")).Count
$mindmapHits = ([regex]::Matches($raw, "Cv2MindmapHubClient")).Count

Write-Host ("[DIAG] Hub div open=" + $openDiv + " close=" + $closeDiv + " missing=" + $missing)
Write-Host ("[DIAG] Hub legacy 'Núcleo do universo' hits=" + $legacyHits + " | mindmap hits=" + $mindmapHits)

# --- PATCH hub: se faltar </div>, injeta antes do </main> ---
$bkHub = BackupFile $hub
if ($missing -gt 0) {
  $idx = $raw.LastIndexOf("</main>")
  if ($idx -lt 0) { throw "[STOP] não achei </main> no Hub pra inserir fechamento" }

  $indentMain = Get-IndentBeforeMainClose $raw
  $indentDiv = $indentMain + "  "

  $closers = ""
  for ($i=0; $i -lt $missing; $i++) {
    $closers += ($indentDiv + "</div>`r`n")
  }

  # garante que tem quebra antes dos closers
  $insert = "`r`n" + $closers
  $raw2 = $raw.Insert($idx, $insert)

  WriteUtf8NoBom $hub $raw2
  Write-Host ("[PATCH] Hub: inseriu " + $missing + " </div> antes do </main>")
  if ($bkHub) { Write-Host ("[BK] " + $bkHub) }
} else {
  Write-Host "[SKIP] Hub: não detectei </div> faltando (pelo contador)."
}

# --- PATCH map rail: remove eslint-disable inútil na primeira linha ---
if (Test-Path $mapRail) {
  $lines = Get-Content $mapRail
  if ($lines.Count -gt 0 -and ($lines[0] -match "eslint-disable" -and $lines[0] -match "no-unused-vars")) {
    $bk = BackupFile $mapRail
    $new = $lines | Select-Object -Skip 1
    WriteUtf8NoBom $mapRail ($new -join "`r`n")
    Write-Host "[PATCH] Cv2MapRail: removeu eslint-disable no-unused-vars (unused)"
    if ($bk) { Write-Host ("[BK] " + $bk) }
  } else {
    Write-Host "[SKIP] Cv2MapRail: nenhum eslint-disable no-unused-vars na linha 1."
  }
} else {
  Write-Host "[SKIP] Cv2MapRail.tsx não existe (ok)."
}

# --- VERIFY ---
$verify = Join-Path $root "tools/cv-verify.ps1"
if (Test-Path $verify) {
  Run "pwsh" @("-NoProfile","-ExecutionPolicy","Bypass","-File",$verify)
} else {
  Run "npm" @("run","lint")
  Run "npm" @("run","build")
}

# --- REPORT ---
EnsureDir (Join-Path $root "reports")
$report = Join-Path $root ("reports/cv-step-b5k2-v2-hub-fix-unclosed-div-v0_1-" + $stamp + ".md")

$rawAfter = Get-Content -Raw $hub
$openDiv2 = Count-OpeningDivTags $rawAfter
$closeDiv2 = ([regex]::Matches($rawAfter, "</div>")).Count
$missing2 = $openDiv2 - $closeDiv2
$legacyHits2 = ([regex]::Matches($rawAfter, "Núcleo do universo")).Count

$md = @()
$md += "# CV — Step B5K2: Hub V2 fix unclosed <div> (v0_1)"
$md += ""
$md += "- When: $stamp"
$md += "- Repo: $root"
$md += ""
$md += "## DIAG (before)"
$md += "- Hub div open=$openDiv close=$closeDiv missing=$missing"
$md += "- Legacy hits 'Núcleo do universo' = $legacyHits"
$md += "- Mindmap marker hits = $mindmapHits"
$md += ""
$md += "## PATCH"
$md += "- Hub: inserted missing </div> before </main> (if needed)"
$md += "- Cv2MapRail: removed unused eslint-disable (if present)"
$md += ""
$md += "## DIAG (after)"
$md += "- Hub div open=$openDiv2 close=$closeDiv2 missing=$missing2"
$md += "- Legacy hits 'Núcleo do universo' = $legacyHits2"
$md += ""
$md += "## Notes"
$md += "- Se ainda houver duplicação visual no Hub, o próximo tijolo é 'remover bloco legado com brace-matching seguro', sem quebrar JSX."

WriteUtf8NoBom $report ($md -join "`r`n")
Write-Host ("[REPORT] " + $report)

Write-Host "[OK] step concluído."