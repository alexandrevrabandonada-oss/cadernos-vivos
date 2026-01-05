# CV — Hotfix — Guard V2 parse error (regex ["'] quebrando) — v0_21
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

function EnsureDir([string]$p) { if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
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
  if ($name -match '\.ps1$') { $name = $name + ".bak" }
  $dest = Join-Path $bkRoot ($stamp + "-" + $name)
  Copy-Item -LiteralPath $path -Destination $dest -Force
  return $dest
}

$repo = Get-Location
Write-Host ("[DIAG] Repo: " + $repo)

$guardPath  = Join-Path $repo "tools\cv-guard-v2.ps1"
$verifyPath = Join-Path $repo "tools\cv-verify.ps1"

if (-not (Test-Path -LiteralPath $guardPath)) { throw ("[STOP] Não achei: " + $guardPath) }
if (-not (Test-Path -LiteralPath $verifyPath)) { throw ("[STOP] Não achei: " + $verifyPath) }

$bk = BackupFile $guardPath

# Reescreve o guard evitando regex com ["'] (causa ParserError)
$lines = @(
  '# CV — Guard V2 (anti-href regex + anti-import backslash)'
  '$ErrorActionPreference = ''Stop'''
  '. "$PSScriptRoot/_bootstrap.ps1"'
  ''
  '$repo = Get-Location'
  '$src  = Join-Path $repo ''src'''
  'if (-not (Test-Path -LiteralPath $src)) { throw (''[STOP] não achei src/: '' + $src) }'
  ''
  '$files = Get-ChildItem -LiteralPath $src -Recurse -File -Include *.ts,*.tsx'
  '$hits = @()'
  ''
  'foreach ($f in $files) {'
  '  $lines = Get-Content -LiteralPath $f.FullName'
  '  $i = 0'
  '  foreach ($ln in $lines) {'
  '    $i++'
  '    # 1) href regex/divisão em TSX (href={/c//v2...})'
  '    if ($ln -like ''*href={/c//*'') {'
  '      $hits += (''[href-regex] '' + $f.FullName + '':'' + $i + '' — Use href={"/c/" + slug + "..."} (string), nunca regex.'')'
  '      continue'
  '    }'
  '    # 2) import com backslash no module specifier (ex: from "@/components/v2\V2Nav")'
  '    $hasFrom = $ln.Contains(''from "'') -or $ln.Contains("from ''")'
  '    $hasAlias = $ln.Contains("@/")'
  '    $hasBackslash = $ln.Contains("\")'
  '    if ($hasFrom -and $hasAlias -and $hasBackslash) {'
  '      $hits += (''[import-backslash] '' + $f.FullName + '':'' + $i + '' — Use forward slash: "@/components/v2/V2Nav".'')'
  '      continue'
  '    }'
  '  }'
  '}'
  ''
  'if ($hits.Count -gt 0) {'
  '  Write-Host ''[STOP] Guard V2 falhou. Ocorrências:'''
  '  foreach ($h in $hits) { Write-Host ('' - '' + $h) }'
  '  throw ''[STOP] Corrija as ocorrências acima.'''
  '}'
  ''
  'Write-Host ''[OK] Guard V2 passou.'''
)

WriteUtf8NoBom $guardPath ($lines -join "`n")
Write-Host ("[OK] wrote: " + $guardPath)
if ($bk) { Write-Host ("[BK] " + $bk) }

# VERIFY
Write-Host "[RUN] tools/cv-verify.ps1"
& $verifyPath

# REPORT
$reports = Join-Path $repo "reports"
EnsureDir $reports
$reportPath = Join-Path $reports "cv-v2-hotfix-guard-parse-v0_21.md"
$report = @(
  "# CV — Hotfix v0_21 — Guard V2 parse (regex com aspas) corrigido"
  ""
  "## Causa raiz"
  "- O guard usava regex com `["']` dentro de string single-quoted, o `'` fechava a string e o parser via `]` solto."
  ""
  "## Fix"
  "- Removeu o `-match` frágil e trocou por `Contains()` + flags (`hasFrom/hasAlias/hasBackslash`)."
  ""
  "## Verify"
  "- tools/cv-verify.ps1 (Guard → lint → build)"
) -join "`n"
WriteUtf8NoBom $reportPath $report
Write-Host ("[OK] Report: " + $reportPath)

Write-Host "[OK] v0_21 aplicado."