# cv-hotfix-b7k2-hub-focus-mark-edge-hints-v0_1
# Marca os callouts do hub (edge hints) com data-cv2-edgehint="1" e oculta via CSS
# DIAG → PATCH → VERIFY → REPORT
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

function InsertAttrNear([string]$raw, [string]$needle) {
  $idx = $raw.IndexOf($needle, [StringComparison]::OrdinalIgnoreCase)
  if ($idx -lt 0) { return @{ raw=$raw; changed=$false; note="not_found" } }

  # procura um "<div" (ou "<section") próximo ANTES do texto
  $start = [Math]::Max(0, $idx - 900)
  $chunk = $raw.Substring($start, $idx - $start)

  $candidates = @("<div", "<section", "<aside", "<article")
  $bestPos = -1
  $bestTok = $null
  foreach ($tok in $candidates) {
    $p = $chunk.LastIndexOf($tok, [StringComparison]::OrdinalIgnoreCase)
    if ($p -gt $bestPos) { $bestPos = $p; $bestTok = $tok }
  }
  if ($bestPos -lt 0) { return @{ raw=$raw; changed=$false; note="no_tag_before" } }

  $absPos = $start + $bestPos

  # acha o fim da tag de abertura
  $gt = $raw.IndexOf(">", $absPos)
  if ($gt -lt 0) { return @{ raw=$raw; changed=$false; note="no_gt" } }

  $openTag = $raw.Substring($absPos, $gt - $absPos + 1)

  if ($openTag -match 'data-cv2-edgehint\s*=') {
    return @{ raw=$raw; changed=$false; note="already_marked" }
  }

  # injeta atributo antes do ">"
  $openTag2 = $openTag.TrimEnd(">")
  $openTag2 = $openTag2 + ' data-cv2-edgehint="1">'
  $raw2 = $raw.Substring(0, $absPos) + $openTag2 + $raw.Substring($gt + 1)

  return @{ raw=$raw2; changed=$true; note=("marked_on_" + $bestTok) }
}

function RunNpm([string[]]$argv) {
  $npmCmd = $null
  try { $npmCmd = (Get-Command npm.cmd -ErrorAction Stop).Path } catch { $npmCmd = $null }
  if (-not $npmCmd) {
    try { $npmCmd = (Get-Command npm -ErrorAction Stop).Path } catch { $npmCmd = "npm.cmd" }
  }
  Write-Host ("[RUN] " + $npmCmd + " " + ($argv -join " "))
  & $npmCmd @argv
  if ($LASTEXITCODE -ne 0) { throw ("npm failed: " + ($argv -join " ")) }
}

EnsureDir (Join-Path $repoRoot "reports")
EnsureDir (Join-Path $repoRoot "tools\_patch_backup")

$rep = Join-Path $repoRoot ("reports\" + $stamp + "-cv-hotfix-b7k2-hub-focus-mark-edge-hints.md")
$r = New-Object System.Collections.Generic.List[string]
$r.Add("# Hotfix B7K2 — Hub Focus (mark edge hints) — " + $stamp) | Out-Null
$r.Add("") | Out-Null
$r.Add("Repo: " + $repoRoot) | Out-Null
$r.Add("") | Out-Null

# --- alvo
$mmRel = "src\components\v2\Cv2MindmapHubClient.tsx"
$mmAbs = Join-Path $repoRoot $mmRel
if (-not (Test-Path -LiteralPath $mmAbs)) { throw ("Missing: " + $mmRel) }

$needles = @(
  "O fio narrativo",
  "Datas, viradas",
  "Documentos, dados e rastros",
  "Caminhos guiados para avançar"
)

$r.Add("## DIAG") | Out-Null
$r.Add("") | Out-Null
$r.Add("- target: " + $mmRel) | Out-Null
foreach ($n in $needles) { $r.Add("- needle: " + $n) | Out-Null }
$r.Add("") | Out-Null

$raw = ReadText $mmAbs
if ($null -eq $raw) { throw ("Empty: " + $mmRel) }

# mostra pequenos trechos (pra auditoria)
foreach ($n in $needles) {
  $i = $raw.IndexOf($n, [StringComparison]::OrdinalIgnoreCase)
  if ($i -ge 0) {
    $a = [Math]::Max(0, $i - 80)
    $b = [Math]::Min($raw.Length - 1, $i + 120)
    $snip = $raw.Substring($a, $b - $a + 1).Replace("`r"," ").Replace("`n"," ")
    $r.Add("### Snip: " + $n) | Out-Null
    $r.Add($snip) | Out-Null
    $r.Add("") | Out-Null
  } else {
    $r.Add("### Snip: " + $n) | Out-Null
    $r.Add("[WARN] not found") | Out-Null
    $r.Add("") | Out-Null
  }
}

# --- PATCH A: marcar elementos próximos
BackupFile $mmRel
$changedAny = $false

$r.Add("## PATCH A — mark data-cv2-edgehint") | Out-Null
$r.Add("") | Out-Null

foreach ($n in $needles) {
  $res = InsertAttrNear $raw $n
  $raw = $res.raw
  $r.Add("- " + $n + " => " + $res.note + ($(if($res.changed){" (changed)"}else{" (nochange)"}))) | Out-Null
  if ($res.changed) { $changedAny = $true }
}
$r.Add("") | Out-Null

if ($changedAny) {
  WriteText $mmAbs ($raw.TrimEnd() + $nl)
  $r.Add("[OK] wrote " + $mmRel) | Out-Null
} else {
  $r.Add("[WARN] nenhum mark aplicado (talvez já estava marcado ou estrutura mudou).") | Out-Null
}
$r.Add("") | Out-Null

# --- PATCH B: CSS hide rule (baseado no data attr)
$cssRel = "src\app\globals.css"
$cssAbs = Join-Path $repoRoot $cssRel
if (-not (Test-Path -LiteralPath $cssAbs)) { throw ("Missing: " + $cssRel) }

$cssRaw = ReadText $cssAbs
if ($null -eq $cssRaw) { throw ("Empty: " + $cssRel) }

$r.Add("## PATCH B — CSS hide rule") | Out-Null
$r.Add("") | Out-Null

if ($cssRaw -match "CV2 — Hub Focus: edge hints via data-attr") {
  $r.Add("- skip: globals.css já tem bloco") | Out-Null
} else {
  BackupFile $cssRel
  $block = @(
    "",
    "/* ================================ */",
    "/* CV2 — Hub Focus: edge hints via data-attr */",
    "/* ================================ */",
    ".cv2-mindmap [data-cv2-edgehint=""1""]{",
    "  display:none !important;",
    "}",
    ""
  ) -join $nl
  WriteText $cssAbs ($cssRaw.TrimEnd() + $block + $nl)
  $r.Add("- appended hide rule to globals.css") | Out-Null
}
$r.Add("") | Out-Null

# --- VERIFY
$failed = $false
$r.Add("## VERIFY") | Out-Null
$r.Add("") | Out-Null

try { RunNpm @("run","lint"); $r.Add("- npm run lint: OK") | Out-Null } catch { $failed = $true; $r.Add("- npm run lint: FAIL") | Out-Null; $r.Add("  " + $_.Exception.Message) | Out-Null }
try { RunNpm @("run","build"); $r.Add("- npm run build: OK") | Out-Null } catch { $failed = $true; $r.Add("- npm run build: FAIL") | Out-Null; $r.Add("  " + $_.Exception.Message) | Out-Null }

$r.Add("") | Out-Null
$r.Add("## Git status (post)") | Out-Null
try { $r.Add((git status | Out-String).TrimEnd()) | Out-Null } catch { $r.Add("ERR: git status") | Out-Null }
$r.Add("") | Out-Null

WriteText $rep ([string]::Join($nl, $r.ToArray()) + $nl)
Write-Host ("[REPORT] " + $rep)

if ($failed) { throw "B7K2: verify failed (see report)." }
Write-Host "[OK] B7K2 finalizado."