# cv-step-b7j-hub-tighten-mindmap-v0_1
# Ajusta o Hub V2: aproxima nós do mindmap + melhora cards via CSS
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

$rep = Join-Path $repoRoot ("reports\" + $stamp + "-cv-step-b7j-hub-tighten-mindmap.md")
$r = New-Object System.Collections.Generic.List[string]
$r.Add("# Tijolo B7J — Hub tighten (mindmap + CSS) — " + $stamp) | Out-Null
$r.Add("") | Out-Null
$r.Add("Repo: " + $repoRoot) | Out-Null
$r.Add("") | Out-Null

AddLines $r (TryRun "Git status (pre)" { git status })

# --- Patch A: aproximar os nós do mindmap (Cv2MindmapHubClient POS) ---
$mmRel = "src\components\v2\Cv2MindmapHubClient.tsx"
$mmAbs = Join-Path $repoRoot $mmRel
if (-not (Test-Path -LiteralPath $mmAbs)) { throw ("Missing: " + $mmRel) }
BackupFile $mmRel

$raw = ReadText $mmAbs
if ($null -eq $raw) { throw ("Empty: " + $mmRel) }

# bloco exato do POS que o B7G2 escreveu
$oldPos = @(
'const POS: Record<DoorId, { x: number; y: number }> = {',
'  "mapa": { x: 50, y: 18 },',
'  "linha": { x: 22, y: 34 },',
'  "linha-do-tempo": { x: 18, y: 62 },',
'  "provas": { x: 78, y: 34 },',
'  "trilhas": { x: 82, y: 62 },',
'  "debate": { x: 50, y: 82 }',
'};'
) -join $nl

# versão “constelação fechada” (mais perto do centro)
$newPos = @(
'const POS: Record<DoorId, { x: number; y: number }> = {',
'  "mapa": { x: 50, y: 22 },',
'  "linha": { x: 30, y: 38 },',
'  "linha-do-tempo": { x: 30, y: 64 },',
'  "provas": { x: 70, y: 38 },',
'  "trilhas": { x: 70, y: 64 },',
'  "debate": { x: 50, y: 82 }',
'};'
) -join $nl

$raw2 = $raw.Replace($oldPos, $newPos)
if ($raw2 -eq $raw) {
  $r.Add("## Patch A") | Out-Null
  $r.Add("- WARN: não consegui substituir o bloco POS (formato diferente).") | Out-Null
  $r.Add("") | Out-Null
} else {
  WriteText $mmAbs ($raw2.TrimEnd() + $nl)
  $r.Add("## Patch A") | Out-Null
  $r.Add("- updated: " + $mmRel + " (POS closer to center)") | Out-Null
  $r.Add("") | Out-Null
}

# --- Patch B: CSS para dar mais “portal” pros cards do mindmap ---
$cssRel = "src\app\globals.css"
$cssAbs = Join-Path $repoRoot $cssRel
if (-not (Test-Path -LiteralPath $cssAbs)) { throw ("Missing: " + $cssRel) }

$cssRaw = ReadText $cssAbs
if ($null -eq $cssRaw) { throw ("Empty: " + $cssRel) }

if ($cssRaw -match "CV2 — Hub Tighten") {
  $r.Add("## Patch B") | Out-Null
  $r.Add("- skip: globals.css já tem CV2 — Hub Tighten") | Out-Null
  $r.Add("") | Out-Null
} else {
  BackupFile $cssRel
  $cssBlock = @(
    '',
    '/* ============================= */',
    '/* CV2 — Hub Tighten (mindmap)   */',
    '/* ============================= */',
    '.cv2-mindmap{position:relative;max-width:980px;margin:18px auto 8px;min-height:560px;}',
    '.cv2-mindmapLines{opacity:.9;}',
    '.cv2-mindmapNode{transform:translate(-50%,-50%);max-width:220px;}',
    '.cv2-mindmapNodeA{display:block;padding:10px 12px;border-radius:16px;border:1px solid rgba(255,255,255,.10);background:rgba(0,0,0,.28);text-decoration:none;}',
    '.cv2-mindmapNodeA:hover{border-color:rgba(255,255,255,.22);background:rgba(0,0,0,.34);}',
    '.cv2-mindmapNode.is-active .cv2-mindmapNodeA{border-color:rgba(255,220,120,.35);box-shadow:0 0 0 1px rgba(255,220,120,.10);}',
    '.cv2-mindmapNodeLabel{font-weight:800;letter-spacing:.01em;}',
    '.cv2-mindmapNodeDesc{margin-top:3px;font-size:12px;opacity:.78;line-height:1.25;}',
    '.cv2-mindmapCenterCard{padding:14px 14px 12px;}',
    '.cv2-mindmapHint{font-size:12px;opacity:.72;margin-top:4px;}',
    '.cv2-mindmapCtas{display:flex;flex-wrap:wrap;gap:10px;margin-top:10px;}',
    '@media (max-width: 900px){.cv2-mindmap{min-height:520px}.cv2-mindmapNode{max-width:180px}}',
    '@media (max-width: 560px){.cv2-mindmapNode{max-width:160px}}',
    ''
  ) -join $nl

  WriteText $cssAbs ($cssRaw.TrimEnd() + $cssBlock + $nl)
  $r.Add("## Patch B") | Out-Null
  $r.Add("- globals.css: appended CV2 — Hub Tighten (mindmap)") | Out-Null
  $r.Add("") | Out-Null
}

# --- VERIFY ---
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

if ($failed) { throw "B7J: verify failed (see report)." }
Write-Host "[OK] B7J finalizado."