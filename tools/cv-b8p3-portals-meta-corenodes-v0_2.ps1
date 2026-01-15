param([switch]$OpenReport)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function EnsureDir([string]$p){
  if(-not (Test-Path -LiteralPath $p)){
    New-Item -ItemType Directory -Force -Path $p | Out-Null
  }
}
function WriteUtf8NoBom([string]$path,[string]$content){
  $enc = [Text.UTF8Encoding]::new($false)
  [IO.File]::WriteAllText($path, $content, $enc)
}
function AppendUtf8NoBom([string]$path,[string]$content){
  $enc = [Text.UTF8Encoding]::new($false)
  [IO.File]::AppendAllText($path, $content, $enc)
}
function BackupFile([string]$src,[string]$dstDir){
  EnsureDir $dstDir
  if(Test-Path -LiteralPath $src){
    Copy-Item -Force -LiteralPath $src -Destination (Join-Path $dstDir (Split-Path $src -Leaf)) | Out-Null
  }
}
function NowStamp(){ (Get-Date).ToString("yyyyMMdd-HHmmss") }

$repoRoot   = (Resolve-Path ".").Path
$reportsDir = Join-Path $repoRoot "reports"
$toolsDir   = Join-Path $repoRoot "tools"
EnsureDir $reportsDir

$stamp = NowStamp
$reportPath = Join-Path $reportsDir ("{0}-cv-b8p3-portals-meta-corenodes-v0_2.md" -f $stamp)
WriteUtf8NoBom $reportPath ("# CV B8P3 v0.2 — Portais: meta.coreNodes fallback`n`n- Data: **$stamp**`n- Repo: $repoRoot`n`n")

function H2([string]$t){ AppendUtf8NoBom $reportPath ("## " + $t + "`n`n") }
function LI([string]$t){ AppendUtf8NoBom $reportPath ("- " + $t + "`n") }

$target = Join-Path $repoRoot "src\components\v2\Cv2PortalsCurated.tsx"
if(-not (Test-Path -LiteralPath $target)){ throw "Arquivo não encontrado: $target" }

H2 "DIAG"
LI ("target: " + $target)

$raw = Get-Content -Raw -Encoding UTF8 -LiteralPath $target
if([string]::IsNullOrWhiteSpace($raw)){ throw "Arquivo vazio: $target" }

$backupDir = Join-Path $toolsDir ("_patch_backup\b8p3-portals-meta-corenodes-" + $stamp)
BackupFile $target $backupDir
H2 "PATCH"
LI ("backup: " + $backupDir)

$changed = $false

# 1) Props: adicionar meta?: unknown (se ainda não tiver)
$needleProps = "type Props = { slug: string; active?: string; current?: string; coreNodes?: CoreNodesV2 };"
$replProps   = "type Props = { slug: string; active?: string; current?: string; coreNodes?: CoreNodesV2; meta?: unknown };"
if($raw.Contains($needleProps)){
  $raw = $raw.Replace($needleProps, $replProps)
  $changed = $true
  LI "Props: +meta?: unknown"
} elseif($raw -match "meta\?\s*:"){
  LI "Props: meta já existe (ok)"
} else {
  LI "Props: não achei a linha exata (skip)"
}

# 2) helper isRecord (se ainda não tiver)
if($raw -notmatch "function isRecord\("){
  $idx = $raw.IndexOf("type Props =")
  if($idx -gt 0){
    $insert = @"
function isRecord(v: unknown): v is Record<string, unknown> {
  return !!v && typeof v === "object" && !Array.isArray(v);
}

"@
    $raw = $raw.Insert($idx, $insert)
    $changed = $true
    LI "add helper: isRecord()"
  } else {
    LI "isRecord: não consegui inserir (skip)"
  }
} else {
  LI "isRecord: já existe (ok)"
}

# 3) fallback meta.coreNodes (se ainda estiver na forma antiga)
$needleOrder = "const order = coreNodesToDoorOrder(props.coreNodes);"
$replOrder = @"
const coreNodes =
  props.coreNodes ??
  (isRecord(props.meta) ? (props.meta["coreNodes"] as CoreNodesV2 | undefined) : undefined);
const order = coreNodesToDoorOrder(coreNodes);
"@
if($raw.Contains($needleOrder)){
  $raw = $raw.Replace($needleOrder, $replOrder)
  $changed = $true
  LI "order: fallback meta.coreNodes aplicado"
} elseif($raw -match "props\.meta\[""coreNodes""\]"){
  LI "order: fallback já existe (ok)"
} else {
  LI "order: não achei o alvo exato (skip)"
}

if($changed){
  WriteUtf8NoBom $target $raw
  LI ("wrote: " + $target)
} else {
  LI "sem mudanças (já estava patchado)"
}

H2 "VERIFY (runner canônico — quoting seguro)"
$runner = Join-Path $repoRoot "tools\cv-runner.ps1"
if(-not (Test-Path -LiteralPath $runner)){ throw "Runner não encontrado: $runner" }

$pwsh = (Get-Command pwsh -ErrorAction Stop).Source
AppendUtf8NoBom $reportPath "[RUN] tools/cv-runner.ps1`n~~~`n"
$out = & $pwsh -NoProfile -ExecutionPolicy Bypass -File $runner 2>&1
$code2 = $LASTEXITCODE
if($null -ne $out){
  foreach($l in $out){ AppendUtf8NoBom $reportPath (([string]$l) + "`n") }
}
AppendUtf8NoBom $reportPath ("~~~`nexit: " + $code2 + "`n`n")

if($code2 -ne 0){
  throw ("Runner failed with exit " + $code2 + " (veja o report)")
}

H2 "DONE"
LI ("report: " + $reportPath)

Write-Host ("[REPORT] " + $reportPath)
if($OpenReport){
  try { Start-Process $reportPath | Out-Null } catch {}
}