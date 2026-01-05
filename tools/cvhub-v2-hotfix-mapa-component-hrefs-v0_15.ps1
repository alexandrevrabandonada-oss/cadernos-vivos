# CV — V2 Hotfix — Corrigir hrefs regex (/c//v2) no componente MapaV2 — v0_15
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

function EnsureDir([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}
function WriteUtf8NoBom([string]$path, [string]$text) {
  EnsureDir (Split-Path -Parent $path)
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($path, $text, $enc)
}
function BackupFile([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) { return $null }
  $bkRoot = Join-Path (Get-Location) "tools\_patch_backup"
  EnsureDir $bkRoot
  $stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
  $name = (Split-Path -Leaf $path)
  if ($name -match '\.tsx?$') { $name = $name + ".bak" }
  $dest = Join-Path $bkRoot ($stamp + "-" + $name)
  Copy-Item -LiteralPath $path -Destination $dest -Force
  return $dest
}
function RunCmd([string]$Exe, [string[]]$CmdArgs) {
  Write-Host ("[RUN] " + $Exe + " " + ($CmdArgs -join " "))
  & $Exe @CmdArgs
  if ($LASTEXITCODE -ne 0) { throw ("[STOP] falhou (exit " + $LASTEXITCODE + "): " + $Exe + " " + ($CmdArgs -join " ")) }
}

$repo = Get-Location
Write-Host ("[DIAG] Repo: " + $repo)

$cmd = Get-Command "npm.cmd" -ErrorAction SilentlyContinue
$npm = if ($cmd) { $cmd.Source } else { "npm.cmd" }
Write-Host ("[DIAG] npm: " + $npm)

$mapComp = Join-Path $repo "src\components\v2\MapaV2.tsx"
Write-Host ("[DIAG] patch: " + $mapComp)
if (-not (Test-Path -LiteralPath $mapComp)) { throw ("[STOP] Não achei: " + $mapComp) }

$bk = BackupFile $mapComp
$raw = Get-Content -LiteralPath $mapComp -Raw
$raw2 = $raw

# Troca href={/c//v2...} (regex/divisão) por string com slug
$raw2 = $raw2.Replace('href={/c//v2}',        'href={"/c/" + slug + "/v2"}')
$raw2 = $raw2.Replace('href={/c//v2/debate}', 'href={"/c/" + slug + "/v2/debate"}')
$raw2 = $raw2.Replace('href={/c//v2/provas}', 'href={"/c/" + slug + "/v2/provas"}')
$raw2 = $raw2.Replace('href={/c//v2/trilhas}','href={"/c/" + slug + "/v2/trilhas"}')

if ($raw2 -eq $raw) {
  Write-Host "[WARN] Não encontrei href={/c//v2...} no MapaV2.tsx (talvez já tenha sido removido)."
} else {
  WriteUtf8NoBom $mapComp $raw2
  Write-Host "[OK] patched: MapaV2.tsx (hrefs corrigidos com slug)"
  if ($bk) { Write-Host ("[BK] " + $bk) }
}

# Scan rápido: se ainda existir em algum lugar
Write-Host "[DIAG] scan src por href={/c//v2..."
$hits = Select-String -Path (Join-Path $repo "src\**\*.tsx") -SimpleMatch -Pattern 'href={/c//v2' -ErrorAction SilentlyContinue
if ($hits) {
  Write-Host "[WARN] Ainda existem ocorrências em outros arquivos:"
  $hits | ForEach-Object { Write-Host (" - " + $_.Path + ":" + $_.LineNumber) }
} else {
  Write-Host "[OK] Nenhuma outra ocorrência encontrada em src/**/*.tsx."
}

RunCmd $npm @("run","lint")
RunCmd $npm @("run","build")

EnsureDir (Join-Path $repo "reports")
$reportPath = Join-Path $repo "reports\cv-v2-hotfix-mapa-component-hrefs-v0_15.md"
$reportLines = @(
  "# CV — Hotfix v0_15 — href regex no MapaV2 corrigido",
  "",
  "## Causa raiz",
  "- Em TSX, `href={/c//v2}` é interpretado como regex/divisão, gerando tipo `number` e quebrando `Link href` (Url).",
  "",
  "## Fix",
  "- Troca para `href={""/c/"" + slug + ""/v2""}` e variantes (debate/provas/trilhas).",
  "",
  "## Verify",
  "- npm run lint",
  "- npm run build",
  ""
) -join "`n"
WriteUtf8NoBom $reportPath $reportLines
Write-Host ("[OK] Report: " + $reportPath)
Write-Host "[OK] v0_15 aplicado."