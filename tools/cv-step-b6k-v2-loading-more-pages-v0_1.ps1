param()
$ErrorActionPreference = "Stop"

$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot
$bk = $null

# ---- bootstrap (prefer) ----
$bootstrap = Join-Path $PSScriptRoot "_bootstrap.ps1"
if (Test-Path -LiteralPath $bootstrap) { . $bootstrap }

# ---- fallbacks (if bootstrap missing) ----
if (-not (Get-Command EnsureDir -ErrorAction SilentlyContinue)) {
  function EnsureDir([string]$p) { if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
}
if (-not (Get-Command WriteUtf8NoBom -ErrorAction SilentlyContinue)) {
  function WriteUtf8NoBom([string]$p, [string]$content) {
    $e = [Text.UTF8Encoding]::new($false)
    EnsureDir (Split-Path -Parent $p)
    [IO.File]::WriteAllText($p, $content, $e)
  }
}
if (-not (Get-Command Backup-File -ErrorAction SilentlyContinue)) {
  function Backup-File([string]$p) {
    $bkDir = Join-Path $repoRoot "tools\_patch_backup"
    EnsureDir $bkDir
    $leaf = ($p.Substring($repoRoot.Length)).TrimStart('"') -replace '[\\/:]', "_"
    $bk = Join-Path $bkDir ("{0}-{1}.bak" -f $ts, $leaf)
    Copy-Item -LiteralPath $p -Destination $bk -Force
    return $bk
  }
}

Write-Host ("== cv-step-b6k-v2-loading-more-pages-v0_1 == " + $ts)
Write-Host ("[DIAG] Repo: " + $repoRoot)

$targets = @(
  "src\app\c\[slug]\v2\debate\loading.tsx",
  "src\app\c\[slug]\v2\linha\loading.tsx",
  "src\app\c\[slug]\v2\linha-do-tempo\loading.tsx",
  "src\app\c\[slug]\v2\mapa\loading.tsx"
)

foreach ($t in $targets) {
  $p = Join-Path $repoRoot $t
  if (Test-Path -LiteralPath $p) { Write-Host ("[DIAG] exists: " + $t) } else { Write-Host ("[DIAG] missing: " + $t) }
}

# 1) Ensure skeleton CSS (scoped to .cv-v2) exists in globals.css
$globalsRel = "src\app\globals.css"
$globals = Join-Path $repoRoot $globalsRel
if (Test-Path -LiteralPath $globals) {
  $raw = Get-Content -Raw -LiteralPath $globals
  if ($raw -notmatch "CV2 Skeleton") {
    $bk = Backup-File $globals
    $append = @(
      "",
      "/* CV2 Skeleton (scoped) */",
      ".cv-v2 .cv2-skelCard {",
      "  border: 1px solid var(--cv2-border);",
      "  background: linear-gradient(180deg, rgba(255,255,255,0.04), rgba(0,0,0,0.08));",
      "  border-radius: 14px;",
      "  padding: 14px 14px 12px;",
      "  box-shadow: 0 10px 28px rgba(0,0,0,0.45);",
      "}",
      ".cv-v2 .cv2-skelLine {",
      "  height: 10px;",
      "  border-radius: 999px;",
      "  background: rgba(255,255,255,0.08);",
      "  overflow: hidden;",
      "  position: relative;",
      "}",
      ".cv-v2 .cv2-skelLine::after {",
      "  content: """";",
      "  position: absolute;",
      "  inset: 0;",
      "  transform: translateX(-60%);",
      "  background: linear-gradient(90deg, transparent, rgba(255,255,255,0.10), transparent);",
      "  animation: cv2-shimmer 1.2s ease-in-out infinite;",
      "}",
      "@keyframes cv2-shimmer {",
      "  0% { transform: translateX(-60%); }",
      "  100% { transform: translateX(60%); }",
      "}",
      "@media (prefers-reduced-motion: reduce) {",
      "  .cv-v2 .cv2-skelLine::after { animation: none; }",
      "}"
    ) -join "`n"
    $out = $raw + $append
    WriteUtf8NoBom $globals $out
    Write-Host "[PATCH] src\app\globals.css (append CV2 Skeleton)"
    if ($null -ne $bk -and $bk -ne "") { Write-Host ("[BK]    tools\_patch_backup\" + (Split-Path -Leaf $bk)) }
  } else {
    Write-Host "SKIP: globals.css já tem CV2 Skeleton"
  }
} else {
  Write-Host "[WARN] não achei globals.css em src\app\globals.css"
}

# 2) Ensure Cv2Skeleton.tsx exists and exports SkelScreen/SkelCard
$skelRel = "src\components\v2\Cv2Skeleton.tsx"
$skel = Join-Path $repoRoot $skelRel
$needRewrite = $false
if (Test-Path -LiteralPath $skel) {
  $sr = Get-Content -Raw -LiteralPath $skel
  if (($sr -notmatch "export\\s+function\\s+SkelScreen") -or ($sr -notmatch "export\\s+function\\s+SkelCard")) { $needRewrite = $true }
} else { $needRewrite = $true }

if ($needRewrite) {
    if ($null -ne $bk -and $bk -ne "") { Write-Host ("[BK]    tools\_patch_backup\" + (Split-Path -Leaf $bk)) }
  $skelCode = @(
    "import React from ""react"";",
    "",
    "export type SkelMode = ""hub"" | ""list"";",
    "",
    "export function SkelCard(props: { lines?: number; className?: string }) {",
    "  const lines = Math.max(1, Math.min(6, props.lines ?? 3));",
    "  return (",
    "    <div className={""cv2-skelCard "" + (props.className ?? """")}>",
    "      <div className=""cv2-skelLine"" style={{ width: ""42%"" }} />",
    "      <div style={{ height: 10 }} />",
    "      {Array.from({ length: lines }).map((_, i) => (",
    "        <div key={i} style={{ marginTop: i === 0 ? 0 : 8 }}>",
    "          <div className=""cv2-skelLine"" style={{ width: i === lines - 1 ? ""58%"" : ""92%"" }} />",
    "        </div>",
    "      ))}",
    "    </div>",
    "  );",
    "}",
    "",
    "export function SkelScreen(props: { count?: number; mode?: SkelMode }) {",
    "  const count = Math.max(1, Math.min(12, props.count ?? (props.mode === ""hub"" ? 6 : 8)));",
    "  return (",
    "    <div style={{ display: ""grid"", gap: 12, padding: 12 }}>",
    "      {Array.from({ length: count }).map((_, i) => (",
    "        <SkelCard key={i} lines={props.mode === ""hub"" ? 2 : 4} />",
    "      ))}",
    "    </div>",
    "  );",
    "}"
  ) -join "`n"
  WriteUtf8NoBom $skel $skelCode
  Write-Host ("[PATCH] " + $skelRel)
} else {
  Write-Host "SKIP: Cv2Skeleton.tsx OK"
}

# 3) Create/overwrite missing loadings (always canonical, with backup if exists)
function WriteLoading([string]$rel, [string]$mode, [int]$count) {
  $p = Join-Path $repoRoot $rel
  if (Test-Path -LiteralPath $p) {
    $bk = Backup-File $p
    if ($null -ne $bk -and $bk -ne "") { Write-Host ("[BK]    tools\_patch_backup\" + (Split-Path -Leaf $bk)) }
  }
  $code = @(
    "import { SkelScreen } from ""@/components/v2/Cv2Skeleton"";",
    "",
    "export default function Loading() {",
    ("  return <SkelScreen mode=""" + $mode + """ count={" + $count + "} />;"),
    "}"
  ) -join "`n"
  WriteUtf8NoBom $p $code
  Write-Host ("[PATCH] " + $rel)
}

WriteLoading "src\app\c\[slug]\v2\debate\loading.tsx" "list" 8
WriteLoading "src\app\c\[slug]\v2\linha\loading.tsx" "list" 10
WriteLoading "src\app\c\[slug]\v2\linha-do-tempo\loading.tsx" "list" 8
WriteLoading "src\app\c\[slug]\v2\mapa\loading.tsx" "hub" 4

# 4) VERIFY
$verify = Join-Path $repoRoot "tools\cv-verify.ps1"
$verifyOut = ""
$exitCode = 0
try {
  if (Test-Path -LiteralPath $verify) {
    Write-Host "[RUN] tools\cv-verify.ps1"
    $verifyOut = (& pwsh -NoProfile -ExecutionPolicy Bypass -File $verify 2>&1 | Out-String)
  } else {
    Write-Host "[RUN] npm run lint"
    $verifyOut += (& npm run lint 2>&1 | Out-String)
    Write-Host "[RUN] npm run build"
    $verifyOut += (& npm run build 2>&1 | Out-String)
  }
} catch {
  $exitCode = 1
  $verifyOut += "`n[ERROR] " + $_.Exception.Message + "`n"
}

# 5) REPORT
$repDir = Join-Path $repoRoot "reports"
EnsureDir $repDir
$rep = Join-Path $repDir ("cv-step-b6k-v2-loading-more-pages-v0_1-" + $ts + ".md")
$body = @(
  "# CV — Step B6k: V2 loading.tsx (more pages) + skeleton css",
  "",
  ("- when: " + $ts),
  ("- repo: " + $repoRoot),
  "",
  "## ACTIONS",
  "- globals.css: ensure CV2 Skeleton block exists (scoped to .cv-v2).",
  "- Ensure src/components/v2/Cv2Skeleton.tsx exports SkelScreen/SkelCard.",
  "- Added canonical loading.tsx for: debate, linha, linha-do-tempo, mapa.",
  "",
  "## VERIFY",
  ("- exit: " + $exitCode),
  "",
  "--- VERIFY OUTPUT START ---",
  $verifyOut.TrimEnd(),
  "--- VERIFY OUTPUT END ---",
  ""
) -join "`n"
WriteUtf8NoBom $rep $body
Write-Host ('REPORT: ' + $rep)

if ($exitCode -ne 0) {
  throw ('STOP: verify falhou (veja o report). ExitCode=' + $exitCode)
}
Write-Host '[OK] B6k concluído (loading states + skeleton css).'