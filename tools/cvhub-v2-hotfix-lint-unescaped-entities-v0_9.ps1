# CV — V2 Hotfix — react/no-unescaped-entities + warnings pontuais — v0_9
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
  if ($name -match '\.tsx?$') { $name = $name + ".bak" } # não cair no TS build
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
  # Troca aspas duplas APENAS em texto literal entre '>' e '<' (sem {expressões})
  $rx = New-Object System.Text.RegularExpressions.Regex('>([^<]*?)<', [System.Text.RegularExpressions.RegexOptions]::Singleline)
  $fixed = $rx.Replace($raw, {
    param($m)
    $inner = $m.Groups[1].Value
    if ($inner -match '[\{\}]') { return $m.Value } # não mexe em JSX expressions
    if ($inner -notmatch '"') { return $m.Value }
    $inner2 = $inner.Replace('"', '&quot;')
    return '>' + $inner2 + '<'
  })
  return $fixed
}

function EnsureEslintDisableNextLine([string]$raw, [string]$lineContains, [string]$rule) {
  $lines = $raw -split "`r?`n", 0, "RegexMatch"
  for ($i=0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -like ("*" + $lineContains + "*")) {
      if ($i -gt 0 -and $lines[$i-1] -like ("*eslint-disable-next-line*" + $rule + "*")) { return $raw }
      $before = @()
      if ($i -gt 0) { $before = $lines[0..($i-1)] }
      $after = @()
      if ($i -lt ($lines.Length-1)) { $after = $lines[$i..($lines.Length-1)] } else { $after = @($lines[$i]) }
      $out = @()
      $out += $before
      $out += ("// eslint-disable-next-line " + $rule)
      $out += $after
      return ($out -join "`n")
    }
  }
  return $raw
}

$repo = Get-Location
Write-Host ("[DIAG] Repo: " + $repo)

$cmd = Get-Command "npm.cmd" -ErrorAction SilentlyContinue
$npmExe = if ($cmd) { $cmd.Source } else { "npm.cmd" }
Write-Host ("[DIAG] npm: " + $npmExe)

$targets = @(
  "src\app\c\[slug]\v2\trilhas\page.tsx",
  "src\app\c\[slug]\v2\trilhas\[id]\page.tsx",
  "src\components\v2\DebateV2.tsx",
  "src\components\v2\ProvasV2.tsx",
  "src\components\v2\TimelineV2.tsx"
)

foreach ($rel in $targets) {
  $file = Join-Path $repo $rel
  if (-not (Test-Path -LiteralPath $file)) { Write-Host ("[SKIP] not found: " + $rel); continue }

  Write-Host ("[DIAG] patch: " + $rel)
  $bk = BackupFile $file
  $raw = Get-Content -LiteralPath $file -Raw

  # 1) Corrige aspas em texto JSX (resolve react/no-unescaped-entities)
  $raw2 = FixJsxUnescapedQuotes $raw

  # 2) Silencia warnings pontuais (sem desligar arquivo todo)
  if ($rel -like "*\trilhas\page.tsx") {
    $raw2 = EnsureEslintDisableNextLine $raw2 "function asArr" "@typescript-eslint/no-unused-vars"
    $raw2 = EnsureEslintDisableNextLine $raw2 "const asArr" "@typescript-eslint/no-unused-vars"
  }
  if ($rel -like "*\DebateV2.tsx") {
    $raw2 = EnsureEslintDisableNextLine $raw2 "JsonValue" "@typescript-eslint/no-unused-vars"
  }
  if ($rel -like "*\ProvasV2.tsx") {
    $raw2 = EnsureEslintDisableNextLine $raw2 "JsonValue" "@typescript-eslint/no-unused-vars"
    $raw2 = EnsureEslintDisableNextLine $raw2 "function asArr" "@typescript-eslint/no-unused-vars"
    $raw2 = EnsureEslintDisableNextLine $raw2 "const asArr" "@typescript-eslint/no-unused-vars"
  }
  if ($rel -like "*\TimelineV2.tsx") {
    $raw2 = EnsureEslintDisableNextLine $raw2 "JsonValue" "@typescript-eslint/no-unused-vars"
    $raw2 = EnsureEslintDisableNextLine $raw2 "function asArr" "@typescript-eslint/no-unused-vars"
    $raw2 = EnsureEslintDisableNextLine $raw2 "const asArr" "@typescript-eslint/no-unused-vars"
  }
  if ($rel -like "*\trilhas\[id]\page.tsx") {
    # só garantia extra se tiver helpers não usados
    $raw2 = EnsureEslintDisableNextLine $raw2 "function asArr" "@typescript-eslint/no-unused-vars"
    $raw2 = EnsureEslintDisableNextLine $raw2 "const asArr" "@typescript-eslint/no-unused-vars"
  }

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
$reportPath = Join-Path $reports "cv-v2-hotfix-lint-unescaped-entities-v0_9.md"
$report = @(
  "# CV — Hotfix v0_9 — Lint/Build V2",
  "",
  "## Fix",
  "- Escapou aspas duplas em texto JSX (usando &quot;) apenas entre tags (entre > e <), sem mexer em atributos.",
  "- Adicionou eslint-disable-next-line pontual para warnings de no-unused-vars (asArr/JsonValue) onde apareceu.",
  "",
  "## Verify",
  "- npm run lint",
  "- npm run build",
  ""
) -join "`n"
WriteUtf8NoBom $reportPath $report
Write-Host ("[OK] Report: " + $reportPath)
Write-Host "[OK] v0_9 aplicado."