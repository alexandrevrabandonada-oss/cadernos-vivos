# cv-step-b7k-hub-focus-hide-edge-hints-v0_1
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
function TryRun([string]$label, [scriptblock]$sb) {
  try { $out = & $sb 2>&1 | Out-String; return @("## " + $label, "", $out.TrimEnd(), "") }
  catch { return @("## " + $label, "", ("ERR: " + $_.Exception.Message), "") }
}
function AddLines([System.Collections.Generic.List[string]]$list, [object]$block) {
  if ($null -eq $block) { return }
  foreach ($x in @($block)) { $list.Add([string]$x) | Out-Null }
}

EnsureDir (Join-Path $repoRoot "reports")
EnsureDir (Join-Path $repoRoot "tools\_patch_backup")

$rep = Join-Path $repoRoot ("reports\" + $stamp + "-cv-step-b7k-hub-focus-hide-edge-hints.md")
$r = New-Object System.Collections.Generic.List[string]
$r.Add("# Tijolo B7K — Hub Focus (hide edge hints) — " + $stamp) | Out-Null
$r.Add("") | Out-Null
$r.Add("Repo: " + $repoRoot) | Out-Null
$r.Add("") | Out-Null

AddLines $r (TryRun "Git status (pre)" { git status })

# Frases que aparecem nos cantos (a gente usa isso pra achar o componente exato)
$needles = @(
  "O fio narrativo",
  "Datas, viradas",
  "Documentos, dados e rastros",
  "Caminhos guiados para avançar",
  "Perguntas, tensões"
)

$srcRoot = Join-Path $repoRoot "src"
if (-not (Test-Path -LiteralPath $srcRoot)) { throw "Missing src/" }

# Procura em src/ (rápido o suficiente)
$hits = @()
foreach ($n in $needles) {
  $m = Get-ChildItem -LiteralPath $srcRoot -Recurse -File -Include *.ts,*.tsx -ErrorAction SilentlyContinue |
    Where-Object {
      $raw = ReadText $_.FullName
      ($null -ne $raw) -and ($raw.IndexOf($n, [StringComparison]::OrdinalIgnoreCase) -ge 0)
    } |
    Select-Object -First 50

  foreach ($f in $m) {
    $hits += [PSCustomObject]@{ needle=$n; file=$f.FullName }
  }
}

$r.Add("## DIAG — onde estão os callouts?") | Out-Null
$r.Add("") | Out-Null
if ($hits.Count -eq 0) {
  $r.Add("[WARN] não encontrei as frases em src/ (talvez mudaram o texto).") | Out-Null
  $r.Add("") | Out-Null
} else {
  foreach ($h in $hits) { $r.Add("- " + $h.needle + " -> " + $h.file) | Out-Null }
  $r.Add("") | Out-Null
}

# Extrai classes próximas às frases (pra esconder só o bloco certo)
$classes = New-Object System.Collections.Generic.HashSet[string]

function NearestClassName([string]$raw, [int]$idx) {
  if ($idx -lt 0) { return $null }
  $start = [Math]::Max(0, $idx - 400)
  $chunk = $raw.Substring($start, $idx - $start)
  $m = [regex]::Matches($chunk, 'className\s*=\s*"([^"]+)"')
  if ($m.Count -eq 0) { return $null }
  $last = $m[$m.Count - 1].Groups[1].Value
  # pega o primeiro token (classe principal)
  $tok = ($last -split '\s+')[0]
  if ($tok -and ($tok.StartsWith("cv2") -or $tok.StartsWith("cv-"))) { return $tok }
  return $tok
}

$r.Add("## DIAG — classes candidatas (próximas às frases)") | Out-Null
$r.Add("") | Out-Null

foreach ($h in $hits) {
  $raw = ReadText $h.file
  if ($null -eq $raw) { continue }
  $idx = $raw.IndexOf($h.needle, [StringComparison]::OrdinalIgnoreCase)
  if ($idx -ge 0) {
    $cls = NearestClassName $raw $idx
    if ($cls) {
      $classes.Add($cls) | Out-Null
      $r.Add("- " + $h.needle + " => class: " + $cls) | Out-Null
    } else {
      $r.Add("- " + $h.needle + " => class: (não detectei)") | Out-Null
    }
  }
}
$r.Add("") | Out-Null

# PATCH: adiciona CSS pra esconder as classes detectadas DENTRO do canvas do mindmap
$cssRel = "src\app\globals.css"
$cssAbs = Join-Path $repoRoot $cssRel
if (-not (Test-Path -LiteralPath $cssAbs)) { throw ("Missing: " + $cssRel) }

$cssRaw = ReadText $cssAbs
if ($null -eq $cssRaw) { throw ("Empty: " + $cssRel) }

$r.Add("## PATCH") | Out-Null
$r.Add("") | Out-Null

if ($classes.Count -eq 0) {
  $r.Add("[WARN] não achei classes para esconder. Sem patch de CSS.") | Out-Null
  $r.Add("") | Out-Null
} elseif ($cssRaw -match "CV2 — Hub Focus: hide edge hints") {
  $r.Add("- skip: globals.css já tem bloco Hub Focus") | Out-Null
  $r.Add("") | Out-Null
} else {
  BackupFile $cssRel

  $cssLines = New-Object System.Collections.Generic.List[string]
  $cssLines.Add("") | Out-Null
  $cssLines.Add("/* ============================= */") | Out-Null
  $cssLines.Add("/* CV2 — Hub Focus: hide edge hints */") | Out-Null
  $cssLines.Add("/* ============================= */") | Out-Null
  foreach ($c in $classes) {
    if (-not [string]::IsNullOrWhiteSpace($c)) {
      $cssLines.Add(".cv2-mindmap ." + $c + "{display:none !important;}") | Out-Null
    }
  }
  $cssLines.Add("") | Out-Null

  WriteText $cssAbs ($cssRaw.TrimEnd() + $nl + ([string]::Join($nl, $cssLines.ToArray())) + $nl)
  $r.Add("- globals.css: added Hub Focus hide rules (" + $classes.Count + " classes)") | Out-Null
  $r.Add("") | Out-Null
}

# VERIFY
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

if ($failed) { throw "B7K: verify failed (see report)." }
Write-Host "[OK] B7K finalizado."