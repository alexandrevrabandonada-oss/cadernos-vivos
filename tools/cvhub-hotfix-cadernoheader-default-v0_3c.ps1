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

function ReadText([string]$p) {
  if (-not (TestP $p)) { return "" }
  return [System.IO.File]::ReadAllText($p)
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

# -------------------------
# DIAG
# -------------------------
$repo = ResolveRepoHere
$npmExe = ResolveExe "npm.cmd"
$hdrPath = Join-Path $repo "src\components\CadernoHeader.tsx"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] File: " + $hdrPath)

if (-not (TestP $hdrPath)) {
  throw ("[STOP] Não achei: " + $hdrPath)
}

# -------------------------
# PATCH
# -------------------------
$raw = ReadText $hdrPath
if (-not $raw) { throw "[STOP] CadernoHeader.tsx vazio?" }

if ($raw -match "export\s+default") {
  WL "[OK] Já tem export default. Nada a fazer."
} else {
  BackupFile $hdrPath

  $hasCadernoHeaderSymbol =
    ($raw -match "\bfunction\s+CadernoHeader\b") -or
    ($raw -match "\bconst\s+CadernoHeader\b") -or
    ($raw -match "\bCadernoHeader\s*=") -or
    ($raw -match "\bexport\s+function\s+CadernoHeader\b") -or
    ($raw -match "\bexport\s+const\s+CadernoHeader\b")

  if ($hasCadernoHeaderSymbol) {
    # adiciona default export no final (sem quebrar exports existentes)
    $patched = $raw.TrimEnd() + "`n`nexport default CadernoHeader;`n"
    WriteUtf8NoBom $hdrPath $patched
    WL "[OK] Adicionado: export default CadernoHeader;"
  } else {
    # fallback: cria um default mínimo usando NavPills (que o erro sugeriu que existe)
    # Mantém o NavPills existente: a gente só APPENDA um default que usa NavPills.
    $hasNavPills = ($raw -match "\bNavPills\b")
    if (-not $hasNavPills) {
      throw "[STOP] Não encontrei símbolo CadernoHeader nem NavPills. Cola o conteúdo do CadernoHeader.tsx aqui."
    }

    $append = @(
      "",
      "type CadernoHeaderProps = { slug: string; title: string; subtitle?: string };",
      "",
      "function DefaultCadernoHeader({ slug, title, subtitle }: CadernoHeaderProps) {",
      "  return (",
      '    <header className="space-y-3">',
      "      <div className=\"card p-5\">",
      "        <div className=\"text-2xl font-semibold\">{title}</div>",
      "        {subtitle ? <div className=\"muted mt-1\">{subtitle}</div> : null}",
      "      </div>",
      "      {/* @ts-ignore: NavPills existe neste módulo */}",
      "      <NavPills slug={slug} />",
      "    </header>",
      "  );",
      "}",
      "",
      "export default DefaultCadernoHeader;",
      ""
    ) -join "`n"

    $patched = $raw.TrimEnd() + "`n" + $append
    WriteUtf8NoBom $hdrPath $patched
    WL "[OK] Fallback: export default DefaultCadernoHeader (usa NavPills)."
  }
}

# -------------------------
# REPORT
# -------------------------
$repDir = Join-Path $repo "reports"
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repDir "cv-3c-hotfix-cadernoheader-default.md"

$report = @(
  ("# CV-3c — Hotfix CadernoHeader default export — " + $now),
  "",
  "## Problema",
  "- Build falhava: import default de CadernoHeader, mas o módulo não exportava default.",
  "",
  "## Correção",
  "- Adicionado export default (preferindo export default CadernoHeader;).",
  "- Se não existir símbolo CadernoHeader, adiciona fallback default usando NavPills.",
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
WL "[OK] Hotfix aplicado. Re-testa /c/poluicao-vr/mapa"