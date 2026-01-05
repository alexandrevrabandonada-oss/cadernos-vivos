# CV — V2 Hotfix — VERIFY sem $args + normalize.ts mood/uiDef estáveis — v0_6b
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

function EnsureDir($p) {
  if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}
function WriteUtf8NoBom($path, $text) {
  EnsureDir (Split-Path -Parent $path)
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($path, $text, $enc)
}
function BackupFile($path) {
  if (-not (Test-Path -LiteralPath $path)) { return $null }
  $bkRoot = Join-Path (Get-Location) "tools\_patch_backup"
  EnsureDir $bkRoot
  $stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
  $name = (Split-Path -Leaf $path)
  $dest = Join-Path $bkRoot ($stamp + "-" + $name)
  Copy-Item -LiteralPath $path -Destination $dest -Force
  return $dest
}
function RunNpm([string]$npmExe, [string[]]$cmdArgs) {
  Write-Host ("[RUN] " + $npmExe + " " + ($cmdArgs -join " "))
  & $npmExe @cmdArgs
  if ($LASTEXITCODE -ne 0) { throw ("[STOP] comando falhou (exit " + $LASTEXITCODE + "): " + $npmExe + " " + ($cmdArgs -join " ")) }
}

$repo = Get-Location
Write-Host ("[DIAG] Repo: " + $repo)

$normalize = Join-Path $repo "src\lib\v2\normalize.ts"
$reports = Join-Path $repo "reports"
EnsureDir $reports

# resolve npm.cmd como string única
$npmCmd = $null
$cmd = Get-Command "npm.cmd" -ErrorAction SilentlyContinue
if ($cmd) { $npmCmd = $cmd.Source } else { $npmCmd = "npm.cmd" }
Write-Host ("[DIAG] npm.cmd: " + $npmCmd)

Write-Host ("[DIAG] normalize: " + $normalize)
if (-not (Test-Path -LiteralPath $normalize)) {
  Write-Host "[WARN] normalize.ts não encontrado. Vou só rodar lint/build."
} else {
  $bk = BackupFile $normalize
  $lines = Get-Content -LiteralPath $normalize

  $moodPatched = $false
  $uiPatched = $false

  for ($i=0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]

    # troca a linha inteira do const mood = ...
    if (-not $moodPatched -and $line -match '^\s*const\s+mood\s*=') {
      $lines[$i] = '  const mood = asStr(o["mood"]) || "urban";'
      $moodPatched = $true
      continue
    }

    # troca a linha inteira do const uiDef = ...
    if (-not $uiPatched -and $line -match '^\s*const\s+uiDef\s*=') {
      $lines[$i] = '  const uiDef = (((asStr(uiObj ? uiObj["default"] : undefined) as UiDefault | undefined) || "v1") as UiDefault);'
      $uiPatched = $true
      continue
    }
  }

  if ($moodPatched -or $uiPatched) {
    WriteUtf8NoBom $normalize (($lines -join "`n") + "`n")
    Write-Host ("[OK] patched: normalize.ts (mood=" + $moodPatched + ", uiDef=" + $uiPatched + ")")
    if ($bk) { Write-Host ("[BK] " + $bk) }
  } else {
    Write-Host "[WARN] Não achei 'const mood =' e/ou 'const uiDef ='. Não alterei normalize.ts."
  }
}

# VERIFY
RunNpm $npmCmd @("run","lint")
RunNpm $npmCmd @("run","build")

# REPORT
$reportPath = Join-Path $reports "cv-v2-hotfix-verify-and-normalize-v0_6b.md"
$rep = @(
  "# CV — Hotfix v0_6b — VERIFY + normalize.ts",
  "",
  "## O que foi corrigido",
  "- VERIFY: não usa mais `$args` (variável automática do PowerShell), então npm recebe os argumentos corretamente.",
  "- normalize.ts: mood tem default (urban) e uiDef é forçado para UiDefault.",
  "",
  "## Verify",
  "- npm run lint",
  "- npm run build",
  ""
) -join "`n"
WriteUtf8NoBom $reportPath $rep
Write-Host ("[OK] Report: " + $reportPath)
Write-Host "[OK] v0_6b aplicado."