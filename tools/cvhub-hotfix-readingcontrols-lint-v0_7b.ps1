param(
  [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function WL([string]$s) { Write-Host $s }
function TestP([string]$p) { return (Test-Path -LiteralPath $p) }

function EnsureDir([string]$p) {
  if (-not (TestP $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

function WriteUtf8NoBom([string]$p, [string]$content) {
  $parent = Split-Path -Parent $p
  if ($parent) { EnsureDir $parent }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($p, $content, $enc)
}

function BackupFile([string]$p) {
  if (TestP $p) {
    $ts = (Get-Date -Format "yyyyMMdd_HHmmss")
    $bakDir = Join-Path (Get-Location) "tools\_patch_backup"
    EnsureDir $bakDir
    $leaf = Split-Path -Leaf $p
    Copy-Item -LiteralPath $p -Destination (Join-Path $bakDir ($leaf + "." + $ts + ".bak")) -Force
  }
}

function ResolveExe([string]$name) {
  $cmd = Get-Command $name -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source) { return $cmd.Source }
  return $name
}

function RunNative([string]$cwd, [string]$exe, [string[]]$cmdArgs) {
  $pretty = ($cmdArgs -join " ")
  WL ("[RUN] " + $exe + " " + $pretty)
  Push-Location $cwd
  & $exe @cmdArgs
  $code = $LASTEXITCODE
  Pop-Location
  if ($code -ne 0) { throw ("[STOP] comando falhou (exit " + $code + "): " + $exe + " " + $pretty) }
}

function ResolveRepoHere() {
  $here = (Get-Location).Path
  if (TestP (Join-Path $here "package.json")) { return $here }
  throw ("[STOP] Rode na raiz do repo (onde tem package.json). Atual: " + $here)
}

function AddImportAfterLastImport([string]$raw, [string]$importLine) {
  if ($raw -like ("*" + $importLine + "*")) { return $raw }

  $lines = $raw -split "`r?`n"
  $lastImport = -1
  for ($i=0; $i -lt $lines.Length; $i++) {
    $t = $lines[$i].TrimStart()
    if ($t.StartsWith("import ")) { $lastImport = $i }
  }

  $out = New-Object System.Collections.Generic.List[string]
  for ($i=0; $i -lt $lines.Length; $i++) {
    [void]$out.Add($lines[$i])
    if ($i -eq $lastImport) { [void]$out.Add($importLine) }
  }

  if ($lastImport -lt 0) {
    $out2 = New-Object System.Collections.Generic.List[string]
    [void]$out2.Add($importLine)
    [void]$out2.Add("")
    foreach ($ln in $lines) { [void]$out2.Add($ln) }
    return ($out2 -join "`n")
  }

  return ($out -join "`n")
}

function EnsureReadingControlsUsage([string]$raw) {
  if ($raw -like "*<ReadingControls*") { return $raw }
  $i = $raw.IndexOf("<CadernoHeader")
  if ($i -lt 0) { return $raw }

  # tenta achar fim de <CadernoHeader ... />
  $j = $raw.IndexOf("/>", $i)
  # tenta achar fim de <CadernoHeader>...</CadernoHeader>
  $k = $raw.IndexOf("</CadernoHeader>", $i)

  $end = -1
  if ($k -ge 0 -and ($j -lt 0 -or $k -lt $j)) {
    $end = $k + "</CadernoHeader>".Length
  } elseif ($j -ge 0) {
    $end = $j + 2
  }

  if ($end -lt 0) { return $raw }

  $insert = "`n      <ReadingControls />"
  return $raw.Insert($end, $insert)
}

# -------------------------
# DIAG
# -------------------------
$repo = ResolveRepoHere
$npmExe = ResolveExe "npm.cmd"

$componentsDir = Join-Path $repo "src\components"
$pagesScope = Join-Path $repo "src\app\c\[slug]"
$readingPath = Join-Path $componentsDir "ReadingControls.tsx"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] ReadingControls: " + $readingPath)

if (-not (TestP $readingPath)) { throw ("[STOP] Não achei: " + $readingPath) }

# -------------------------
# PATCH 1 — fix no-unescaped-entities
# -------------------------
BackupFile $readingPath
$rc = Get-Content -LiteralPath $readingPath -Raw

$rc2 = $rc.Replace('"Pular para o conteúdo"', '&quot;Pular para o conteúdo&quot;')
if ($rc2 -eq $rc) {
  # fallback (caso tenha variação)
  $rc2 = [regex]::Replace($rc, '\"Pular para o conteúdo\"', '&quot;Pular para o conteúdo&quot;')
}

if ($rc2 -ne $rc) {
  WriteUtf8NoBom $readingPath $rc2
  WL "[OK] patched: ReadingControls.tsx (quotes escaped)"
} else {
  WL "[OK] ReadingControls.tsx já estava ok (nada a trocar)"
}

# -------------------------
# PATCH 2 — garantir uso do <ReadingControls />
# -------------------------
if (-not (TestP $pagesScope)) { throw ("[STOP] Não achei scope: " + $pagesScope) }

$pages = @(Get-ChildItem -LiteralPath $pagesScope -Recurse -File -Filter "page.tsx" -ErrorAction SilentlyContinue)
WL ("[DIAG] pages: " + $pages.Count)

$patched = 0
foreach ($p in $pages) {
  $raw = Get-Content -LiteralPath $p.FullName -Raw
  $new = $raw

  # garante import
  $new = AddImportAfterLastImport $new 'import ReadingControls from "@/components/ReadingControls";'

  # garante uso
  $new = EnsureReadingControlsUsage $new

  if ($new -ne $raw) {
    BackupFile $p.FullName
    WriteUtf8NoBom $p.FullName $new
    $patched++
    WL ("[OK] patched: " + $p.FullName)
  }
}

WL ("[OK] pages patched: " + $patched)

# -------------------------
# REPORT
# -------------------------
$repDir = Join-Path $repo "reports"
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repDir "cv-engine-3a-hotfix-lint-v0_7b.md"
$report = @(
("# CV-Engine-3A — Hotfix Lint v0.7b — " + $now),
"",
"## Correcoes",
"- ReadingControls.tsx: aspas em texto trocadas por &quot;...&quot; (react/no-unescaped-entities).",
"- Todas pages em /c/[slug] agora garantem import + uso de <ReadingControls /> apos <CadernoHeader />.",
"",
"## Verify",
"- npm run lint",
"- npm run build"
) -join "`n"
WriteUtf8NoBom $reportPath $report
WL ("[OK] Report: " + $reportPath)

# -------------------------
# VERIFY
# -------------------------
WL "[VERIFY] npm run lint..."
RunNative $repo $npmExe @("run","lint")

if (-not $SkipBuild) {
  WL "[VERIFY] npm run build..."
  RunNative $repo $npmExe @("run","build")
} else {
  WL "[VERIFY] build pulado (-SkipBuild)."
}

WL ""
WL "[OK] Hotfix v0.7b aplicado."