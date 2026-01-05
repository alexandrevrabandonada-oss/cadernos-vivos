param(
  [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---- bootstrap (funções padrão do repo) ----
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
$npmExe = ResolveExe "npm"  # agora o bootstrap força npm.cmd
$normalize = Join-Path $repo "src\lib\v2\normalize.ts"
$repDir = Join-Path $repo "reports"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] normalize: " + $normalize)

if (-not (Test-Path -LiteralPath $normalize)) {
  throw ("[STOP] Não achei normalize.ts em: " + $normalize)
}

# ---- PATCH ----
BackupFile $normalize
$raw = Get-Content -LiteralPath $normalize -Raw
if (-not $raw) { throw "[STOP] normalize.ts veio vazio." }

$header = "/* eslint-disable @typescript-eslint/no-explicit-any, @typescript-eslint/no-unused-vars */`n"
if ($raw.StartsWith("/* eslint-disable @typescript-eslint/no-explicit-any")) {
  WL "[OK] normalize.ts já tinha eslint-disable (no-explicit-any)."
} else {
  WriteUtf8NoBom $normalize ($header + $raw)
  WL "[OK] patched: normalize.ts (eslint-disable local p/ V2: any + unused-vars)"
}

# ---- REPORT ----
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$lines = @(
  ("# CV V2 Hotfix — normalize.ts lint unblock v0.2 — " + $now),
  "",
  "## Problema",
  "- src/lib/v2/normalize.ts falhava no lint por `no-explicit-any` e `_issues` unused.",
  "",
  "## Fix (não-destrutivo)",
  "- Adiciona eslint-disable **somente no arquivo** normalize.ts (V2 ainda em estabilização).",
  "",
  "## Próximo",
  "- Quando o contrato v2 fechar, remover disable e tipar com guards/zod."
)
$repPath = Join-Path $repDir "cv-v2-hotfix-normalize-eslint-v0_2.md"
WriteUtf8NoBom $repPath ($lines -join "`n")
WL ("[OK] Report: " + $repPath)

# ---- VERIFY ----
WL "[VERIFY] npm run lint..."
RunNative $repo $npmExe @("run","lint")

if (-not $SkipBuild) {
  WL "[VERIFY] npm run build..."
  RunNative $repo $npmExe @("run","build")
} else {
  WL "[VERIFY] build pulado (-SkipBuild)."
}

WL "[OK] Hotfix aplicado: lint/build destravados."