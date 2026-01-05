param(
  [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repo = (Get-Location).Path
$bootstrap = Join-Path $repo "tools\_bootstrap.ps1"
if (-not (Test-Path -LiteralPath $bootstrap)) { throw "[STOP] tools/_bootstrap.ps1 não encontrado." }
. $bootstrap

function ResolveRepoHere() {
  $here = (Get-Location).Path
  if (Test-Path -LiteralPath (Join-Path $here "package.json")) { return $here }
  throw ("[STOP] Rode na raiz do repo (onde tem package.json). Atual: " + $here)
}

$repo = ResolveRepoHere
$npmExe = ResolveExe "npm"
$normalize = Join-Path $repo "src\lib\v2\normalize.ts"
$repDir = Join-Path $repo "reports"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] normalize: " + $normalize)

if (-not (Test-Path -LiteralPath $normalize)) { throw ("[STOP] Não achei: " + $normalize) }

BackupFile $normalize
$lines = Get-Content -LiteralPath $normalize

$changed = 0
for ($i=0; $i -lt $lines.Count; $i++) {
  $line = $lines[$i]

  if ($line -match "^\s*subtitle\s*:\s*asStr\(" -and ($line -notmatch "\?\?")) {
    $lines[$i] = $line.Replace("),", ") ?? null,")
    $changed++
    continue
  }
  if ($line -match "^\s*mood\s*:\s*asStr\(" -and ($line -notmatch "\?\?")) {
    $lines[$i] = $line.Replace("),", ") ?? null,")
    $changed++
    continue
  }
  if ($line -match "^\s*accent\s*:\s*asStr\(" -and ($line -notmatch "\?\?")) {
    $lines[$i] = $line.Replace("),", ") ?? null,")
    $changed++
    continue
  }
  if ($line -match "^\s*ethos\s*:\s*asStr\(" -and ($line -notmatch "\?\?")) {
    $lines[$i] = $line.Replace("),", ") ?? null,")
    $changed++
    continue
  }
}

if ($changed -eq 0) {
  WL "[WARN] Não encontrei linhas subtitle/mood/accent/ethos no formato esperado. Nenhuma mudança aplicada."
} else {
  $content = ($lines -join "`n")
  WriteUtf8NoBom $normalize $content
  WL ("[OK] patched: normalize.ts (undefined -> null em " + $changed + " linha(s))")
}

# REPORT
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$rep = @(
  ("# CV V2 Hotfix — normalize no undefined v0.3b — " + $now),
  "",
  "## Problema",
  "- build falhava: MetaV2 não aceita undefined (JsonValue).",
  "",
  "## Fix",
  "- Converte subtitle/mood/accent/ethos de asStr(x) para asStr(x) ?? null.",
  "",
  "## Observação",
  "- Hotfix não altera V1; é só camada V2."
) -join "`n"

$repPath = Join-Path $repDir "cv-v2-hotfix-normalize-no-undefined-v0_3b.md"
WriteUtf8NoBom $repPath $rep
WL ("[OK] Report: " + $repPath)

# VERIFY
WL "[VERIFY] npm run lint..."
RunNative $repo $npmExe @("run","lint")

if (-not $SkipBuild) {
  WL "[VERIFY] npm run build..."
  RunNative $repo $npmExe @("run","build")
} else {
  WL "[VERIFY] build pulado (-SkipBuild)."
}

WL "[OK] Hotfix aplicado: build deve passar."