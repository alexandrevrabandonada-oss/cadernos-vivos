# CV HOTFIX B7N4 — Fix: meta undefined in /v2/mapa + robust Run() in B7N script
# DIAG -> PATCH -> VERIFY -> REPORT

$ErrorActionPreference = "Stop"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Write-Host ("== CV HOTFIX B7N4 == " + $stamp)

$root = (Resolve-Path ".").Path

function EnsureDir([string]$p){
  if(-not (Test-Path -LiteralPath $p)){
    New-Item -ItemType Directory -Force -Path $p | Out-Null
  }
}

function WriteUtf8NoBom([string]$path, [string]$content){
  EnsureDir (Split-Path -Parent $path)
  $enc = New-Object System.Text.UTF8Encoding($false)
  [IO.File]::WriteAllText($path, $content, $enc)
}

function BackupFile([string]$absPath){
  if(Test-Path -LiteralPath $absPath){
    $bdir = Join-Path $root ("tools\_patch_backup\" + $stamp)
    EnsureDir $bdir
    $dst = Join-Path $bdir ([IO.Path]::GetFileName($absPath))
    Copy-Item -LiteralPath $absPath -Destination $dst -Force
    return $dst
  }
  return $null
}

function FindNpmExe {
  $c = Get-Command "npm.cmd" -ErrorAction SilentlyContinue
  if ($c -and $c.Path) { return $c.Path }
  $c = Get-Command "npm" -ErrorAction SilentlyContinue
  if ($c -and $c.Source) { return $c.Source }
  throw "npm not found in PATH"
}

function RunNpm([string]$npmExe, [string[]]$cmdArgs){
  $argLine = ""
  if ($cmdArgs -and $cmdArgs.Count -gt 0) { $argLine = ($cmdArgs -join " ") }
  Write-Host ("[RUN] " + $npmExe + " " + $argLine)
  & $npmExe @cmdArgs
  if ($LASTEXITCODE -ne 0) { throw ("Command failed: npm " + $argLine) }
}

$reportsDir = Join-Path $root "reports"
EnsureDir $reportsDir
$reportPath = Join-Path $reportsDir ($stamp + "-cv-hotfix-b7n4-fix-meta-undefined-and-runnpm.md")

$log = New-Object System.Collections.Generic.List[string]
$log.Add("# CV HOTFIX B7N4 — meta undefined + RunNpm robusto — " + $stamp) | Out-Null
$log.Add("") | Out-Null
$log.Add("Root: " + $root) | Out-Null
$log.Add("") | Out-Null

# Files (IMPORTANT: [slug] exige -LiteralPath)
$mapPageRel = "src\app\c\[slug]\v2\mapa\page.tsx"
$mapPageAbs = Join-Path $root $mapPageRel

$coreRel = "src\components\v2\Cv2CoreHighlights.tsx"
$coreAbs = Join-Path $root $coreRel

$b7nRel = "tools\cv-step-b7n-map-core-highlights-v0_2.ps1"
$b7nAbs = Join-Path $root $b7nRel

# -------------------------
# DIAG
# -------------------------
$log.Add("## DIAG") | Out-Null
$log.Add("") | Out-Null
$log.Add("- map page exists (LiteralPath): " + (Test-Path -LiteralPath $mapPageAbs)) | Out-Null
$log.Add("- core component exists: " + (Test-Path -LiteralPath $coreAbs)) | Out-Null
$log.Add("- b7n script exists: " + (Test-Path -LiteralPath $b7nAbs)) | Out-Null
$log.Add("") | Out-Null

if (-not (Test-Path -LiteralPath $mapPageAbs)) { throw ("Missing: " + $mapPageRel) }
if (-not (Test-Path -LiteralPath $coreAbs))    { throw ("Missing: " + $coreRel) }

# -------------------------
# PATCH A) Map page: remove meta={meta} (meta não existe na page)
# -------------------------
$log.Add("## PATCH A — /v2/mapa: remover meta={meta} em <Cv2CoreHighlights ...>") | Out-Null
$log.Add("") | Out-Null

$bkA = BackupFile $mapPageAbs
$rawA = Get-Content -LiteralPath $mapPageAbs -Raw
$patchedA = $rawA

# Remove attribute meta={meta} only inside Cv2CoreHighlights tag
$patchedA = [regex]::Replace(
  $patchedA,
  '(<Cv2CoreHighlights\b[^>]*?)\s+meta=\{meta\}',
  '$1'
)

if ($patchedA -eq $rawA) {
  $log.Add("[OK] nada a mudar (não achei meta={meta} na tag).") | Out-Null
} else {
  WriteUtf8NoBom $mapPageAbs $patchedA
  $log.Add("[OK] atualizado: " + $mapPageRel) | Out-Null
  if ($bkA) { $log.Add("- backup: " + $bkA.Substring($root.Length+1)) | Out-Null }
}
$log.Add("") | Out-Null

# -------------------------
# PATCH B) Component: meta opcional (hardening)
# -------------------------
$log.Add("## PATCH B — Cv2CoreHighlights: tornar props.meta opcional") | Out-Null
$log.Add("") | Out-Null

$bkB = BackupFile $coreAbs
$rawB = Get-Content -LiteralPath $coreAbs -Raw
$patchedB = $rawB

$patchedB = [regex]::Replace(
  $patchedB,
  'export function Cv2CoreHighlights\(props:\s*\{\s*slug:\s*string;\s*meta:\s*unknown;\s*current\?:\s*string\s*\}\)',
  'export function Cv2CoreHighlights(props: { slug: string; meta?: unknown; current?: string })'
)

if ($patchedB -eq $rawB) {
  $log.Add("[OK] já estava opcional (ou padrão diferente).") | Out-Null
} else {
  WriteUtf8NoBom $coreAbs $patchedB
  $log.Add("[OK] atualizado: " + $coreRel) | Out-Null
  if ($bkB) { $log.Add("- backup: " + $bkB.Substring($root.Length+1)) | Out-Null }
}
$log.Add("") | Out-Null

# -------------------------
# PATCH C) B7N script: Run sem $args (evita bug) + calls separadas
# -------------------------
$log.Add("## PATCH C — B7N v0_2: Run() robusto (sem `$args`)") | Out-Null
$log.Add("") | Out-Null

if (Test-Path -LiteralPath $b7nAbs) {
  $bkC = BackupFile $b7nAbs
  $rawC = Get-Content -LiteralPath $b7nAbs -Raw
  $patchedC = $rawC

  $newRun = @()
  $newRun += 'function Run([string]$cmd, [string[]]$cmdArgs){'
  $newRun += '  $argLine = ""'
  $newRun += '  if ($cmdArgs -and $cmdArgs.Count -gt 0) { $argLine = ($cmdArgs -join " ") }'
  $newRun += '  Write-Host ("[RUN] " + $cmd + " " + $argLine)'
  $newRun += '  & $cmd @cmdArgs'
  $newRun += '  if ($LASTEXITCODE -ne 0) { throw ("Command failed: " + $cmd + " " + $argLine) }'
  $newRun += '}'
  $newRunBlock = ($newRun -join "`n")

  # Replace any existing Run(...) { ... } block that references & $cmd @args
  $patchedC = [regex]::Replace(
    $patchedC,
    '(?s)function\s+Run\s*\([^\)]*\)\s*\{.*?&\s*\$cmd\s+@args.*?\}',
    $newRunBlock
  )

  # Also replace variants where it used @args and param $args
  $patchedC = [regex]::Replace(
    $patchedC,
    '(?s)function\s+Run\s*\([^\)]*\)\s*\{.*?&\s*\$cmd\s+@args.*?\}',
    $newRunBlock
  )

  # Fix call sites to avoid array-binding weirdness
  $patchedC = [regex]::Replace($patchedC, 'Run\s+\$npm\s+\("run","lint"\)', 'Run $npm "run" "lint"')
  $patchedC = [regex]::Replace($patchedC, 'Run\s+\$npm\s+\("run","build"\)', 'Run $npm "run" "build"')
  $patchedC = [regex]::Replace($patchedC, 'Run\s+\$npm\s+@\(\s*"run"\s*,\s*"lint"\s*\)', 'Run $npm "run" "lint"')
  $patchedC = [regex]::Replace($patchedC, 'Run\s+\$npm\s+@\(\s*"run"\s*,\s*"build"\s*\)', 'Run $npm "run" "build"')

  if ($patchedC -eq $rawC) {
    $log.Add("[OK] B7N script: nada a mudar (pode já estar corrigido).") | Out-Null
  } else {
    WriteUtf8NoBom $b7nAbs $patchedC
    $log.Add("[OK] atualizado: " + $b7nRel) | Out-Null
    if ($bkC) { $log.Add("- backup: " + $bkC.Substring($root.Length+1)) | Out-Null }
  }
} else {
  $log.Add("[WARN] sem " + $b7nRel + " (skip).") | Out-Null
}
$log.Add("") | Out-Null

# -------------------------
# VERIFY
# -------------------------
$log.Add("## VERIFY") | Out-Null
$log.Add("") | Out-Null

$npm = FindNpmExe
try {
  RunNpm $npm @("run","lint")
  RunNpm $npm @("run","build")
  $log.Add("[OK] lint/build OK") | Out-Null
} catch {
  $log.Add("[ERR] verify falhou: " + $_.Exception.Message) | Out-Null
  $log.Add("Dica: rode manual: npm run lint / npm run build e cole o output.") | Out-Null
}

WriteUtf8NoBom $reportPath ($log -join "`n")
Write-Host ("[OK] report -> " + $reportPath)
Write-Host "DONE."