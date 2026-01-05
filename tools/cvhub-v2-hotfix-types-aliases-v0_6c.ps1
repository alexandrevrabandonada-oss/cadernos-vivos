# CV — V2 Hotfix — types.ts aliases (AcervoV2/MapaV2/DebateV2/RegistroV2) — v0_6c
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

# resolve npm.cmd
$npmCmd = $null
$cmd = Get-Command "npm.cmd" -ErrorAction SilentlyContinue
if ($cmd) { $npmCmd = $cmd.Source } else { $npmCmd = "npm.cmd" }
Write-Host ("[DIAG] npm.cmd: " + $npmCmd)

$types = Join-Path $repo "src\lib\v2\types.ts"
Write-Host ("[DIAG] types: " + $types)
if (-not (Test-Path -LiteralPath $types)) { throw "[STOP] Não achei src/lib/v2/types.ts" }

$bk = BackupFile $types
$lines = Get-Content -LiteralPath $types

# já existe?
$already = $false
foreach ($l in $lines) {
  if ($l -match 'export\s+type\s+MapaV2\s*=') { $already = $true; break }
}
if ($already) {
  Write-Host "[OK] types.ts já tem aliases (MapaV2 etc). Nada a fazer."
} else {
  # inserir logo depois do JsonValue (bloco de tipos base)
  $idx = -1
  for ($i=0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'export\s+type\s+JsonValue\s*=') { $idx = $i; break }
  }
  if ($idx -lt 0) { throw "[STOP] Não achei 'export type JsonValue =' em types.ts" }

  # acha o fim do bloco JsonValue (até encontrar uma linha vazia depois dele, ou próximo export)
  $insertAt = $idx + 1
  for ($j=$idx+1; $j -lt $lines.Count; $j++) {
    if ($lines[$j].Trim() -eq "") { $insertAt = $j + 1; break }
    if ($lines[$j].Trim().StartsWith("export ")) { $insertAt = $j; break }
    $insertAt = $j + 1
  }

  $aliasBlock = @(
    "",
    "// Aliases V2 (mantém normalize.ts compatível; tudo é JsonValue por enquanto)",
    "export type MapaV2 = JsonValue;",
    "export type AcervoV2 = JsonValue;",
    "export type DebateV2 = JsonValue;",
    "export type RegistroV2 = JsonValue;",
    ""
  )

  $new = @()
  for ($k=0; $k -lt $lines.Count; $k++) {
    if ($k -eq $insertAt) { $new += $aliasBlock }
    $new += $lines[$k]
  }

  WriteUtf8NoBom $types (($new -join "`n") + "`n")
  Write-Host "[OK] patched: types.ts (aliases adicionados)"
  if ($bk) { Write-Host ("[BK] " + $bk) }
}

# VERIFY
RunNpm $npmCmd @("run","lint")
RunNpm $npmCmd @("run","build")

# REPORT
$reports = Join-Path $repo "reports"
EnsureDir $reports
$reportPath = Join-Path $reports "cv-v2-hotfix-types-aliases-v0_6c.md"
$rep = @(
  "# CV — Hotfix v0_6c — types.ts aliases",
  "",
  "## Problema",
  "- normalize.ts importa AcervoV2/MapaV2/DebateV2/RegistroV2, mas types.ts não exportava esses nomes.",
  "",
  "## Fix",
  "- Adicionados aliases em src/lib/v2/types.ts (todos como JsonValue por enquanto).",
  "",
  "## Verify",
  "- npm run lint",
  "- npm run build",
  ""
) -join "`n"
WriteUtf8NoBom $reportPath $rep
Write-Host ("[OK] Report: " + $reportPath)
Write-Host "[OK] v0_6c aplicado."