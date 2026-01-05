# CV — V2 Hotfix — remover eslint-disable-next-line que caiu em JSX (parser error) — v0_10
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
function RunCmd([string]$exe, [string[]]$cmdArgs) {
  Write-Host ("[RUN] " + $exe + " " + ($cmdArgs -join " "))
  & $exe @cmdArgs
  if ($LASTEXITCODE -ne 0) { throw ("[STOP] falhou (exit " + $LASTEXITCODE + "): " + $exe + " " + ($cmdArgs -join " ")) }
}

function FixJsxUnescapedQuotes([string]$raw) {
  # Troca " -> &quot; somente em texto literal entre tags (>...<), sem {expressões}
  $rx = New-Object System.Text.RegularExpressions.Regex('>([^<]*?)<', [System.Text.RegularExpressions.RegexOptions]::Singleline)
  return $rx.Replace($raw, {
    param($m)
    $inner = $m.Groups[1].Value
    if ($inner -match '[\{\}]') { return $m.Value }
    if ($inner -notmatch '"') { return $m.Value }
    return '>' + $inner.Replace('"','&quot;') + '<'
  })
}

function RemoveBadEslintNextLine([string]$raw) {
  $lines = $raw -split "`r?`n", 0, "RegexMatch"
  $out = New-Object System.Collections.Generic.List[string]
  foreach ($ln in $lines) {
    if ($ln -match '^\s*//\s*eslint-disable-next-line\s+@typescript-eslint/no-unused-vars\s*$') { continue }
    if ($ln -match '^\s*//\s*eslint-disable-next-line\s+react/no-unescaped-entities\s*$') { continue }
    $out.Add($ln) | Out-Null
  }
  return ($out -join "`n")
}

$repo = Get-Location
Write-Host ("[DIAG] Repo: " + $repo)

$cmd = Get-Command "npm.cmd" -ErrorAction SilentlyContinue
$npmExe = if ($cmd) { $cmd.Source } else { "npm.cmd" }
Write-Host ("[DIAG] npm: " + $npmExe)

$targets = @(
  "src\components\v2\DebateV2.tsx",
  "src\components\v2\ProvasV2.tsx",
  "src\components\v2\TimelineV2.tsx",
  "src\app\c\[slug]\v2\trilhas\page.tsx",
  "src\app\c\[slug]\v2\trilhas\[id]\page.tsx"
)

foreach ($rel in $targets) {
  $file = Join-Path $repo $rel
  if (-not (Test-Path -LiteralPath $file)) { Write-Host ("[SKIP] not found: " + $rel); continue }

  Write-Host ("[DIAG] patch: " + $rel)
  $bk = BackupFile $file
  $raw = Get-Content -LiteralPath $file -Raw

  $raw2 = RemoveBadEslintNextLine $raw
  $raw2 = FixJsxUnescapedQuotes $raw2

  if ($raw2 -ne $raw) {
    WriteUtf8NoBom $file $raw2
    Write-Host ("[OK] patched: " + $rel)
    if ($bk) { Write-Host ("[BK] " + $bk) }
  } else {
    Write-Host ("[OK] no changes: " + $rel)
  }
}

# VERIFY
RunCmd $npmExe @("run","lint")
RunCmd $npmExe @("run","build")

# REPORT
$reports = Join-Path $repo "reports"
EnsureDir $reports
$reportPath = Join-Path $reports "cv-v2-hotfix-remove-bad-eslint-comments-v0_10.md"
$report = @(
  "# CV — Hotfix v0_10 — Parser error (Expression expected)",
  "",
  "## Causa raiz",
  "- Linhas // eslint-disable-next-line foram parar dentro de JSX em componentes React, o que quebra o parser.",
  "",
  "## Fix",
  "- Removeu // eslint-disable-next-line @typescript-eslint/no-unused-vars (e react/no-unescaped-entities) dos arquivos afetados.",
  "- Reaplicou ajuste de aspas em texto JSX (\" -> &quot;) onde necessário.",
  "",
  "## Verify",
  "- npm run lint",
  "- npm run build",
  ""
) -join "`n"
WriteUtf8NoBom $reportPath $report
Write-Host ("[OK] Report: " + $reportPath)
Write-Host "[OK] v0_10 aplicado."