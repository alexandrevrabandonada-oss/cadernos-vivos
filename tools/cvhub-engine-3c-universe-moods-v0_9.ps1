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

function ReplaceOrThrow([string]$raw, [string]$needle, [string]$replace) {
  if ($raw -notlike ("*" + $needle + "*")) { throw ("[STOP] Trecho não encontrado: " + $needle) }
  return $raw.Replace($needle, $replace)
}

# -------------------------
# DIAG
# -------------------------
$repo = ResolveRepoHere
$npmExe = ResolveExe "npm.cmd"

$componentsDir = Join-Path $repo "src\components"
$layoutPath = Join-Path $repo "src\app\c\[slug]\layout.tsx"
$globalsPath = Join-Path $repo "src\app\globals.css"
$universePath = Join-Path $componentsDir "UniverseShell.tsx"
$repDir = Join-Path $repo "reports"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] layout: " + $layoutPath)
WL ("[DIAG] globals: " + $globalsPath)

if (-not (TestP $layoutPath)) { throw ("[STOP] Não achei layout do caderno: " + $layoutPath) }
if (-not (TestP $globalsPath)) { throw ("[STOP] Não achei globals.css: " + $globalsPath) }

EnsureDir $componentsDir

# -------------------------
# PATCH 1 — UniverseShell (client)
# -------------------------
BackupFile $universePath

$universeLines = @(
'"use client";',
'',
'import type { ReactNode } from "react";',
'import { useMemo } from "react";',
'import { usePathname } from "next/navigation";',
'',
'type Props = { children: ReactNode };',
'',
'function modeFromPath(pathname: string): string {',
'  // Exemplos:',
'  // /c/slug -> home',
'  // /c/slug/a/2 -> aula',
'  // /c/slug/mapa -> mapa',
'  if (!pathname) return "home";',
'  if (pathname.indexOf("/a/") >= 0) return "aula";',
'  if (pathname.endsWith("/mapa")) return "mapa";',
'  if (pathname.endsWith("/debate")) return "debate";',
'  if (pathname.endsWith("/quiz")) return "quiz";',
'  if (pathname.endsWith("/pratica")) return "pratica";',
'  if (pathname.endsWith("/registro")) return "registro";',
'  if (pathname.endsWith("/acervo")) return "acervo";',
'  if (pathname.endsWith("/trilha")) return "trilha";',
'  return "home";',
'}',
'',
'export default function UniverseShell({ children }: Props) {',
'  const pathname = usePathname() || "";',
'  const mode = useMemo(() => modeFromPath(pathname), [pathname]);',
'  const cls = "cv-universe cv-u cv-u--" + mode;',
'  return <div className={cls}>{children}</div>;',
'}'
) -join "`n"

WriteUtf8NoBom $universePath $universeLines
WL ("[OK] wrote: " + $universePath)

# -------------------------
# PATCH 2 — layout.tsx usa UniverseShell
# -------------------------
BackupFile $layoutPath
$layoutRaw = Get-Content -LiteralPath $layoutPath -Raw

# remove wrapper antigo se existir e troca por UniverseShell
if ($layoutRaw -like "*className=`"cv-universe`"*") {
  $layoutRaw = $layoutRaw.Replace('<div className="cv-universe">{children}</div>', '<UniverseShell>{children}</UniverseShell>')
}

# garantir import
if ($layoutRaw -notlike "*UniverseShell*") {
  $lines = $layoutRaw -split "`r?`n"
  $out = New-Object System.Collections.Generic.List[string]

  foreach ($ln in $lines) {
    $out.Add($ln)
    if ($ln -eq 'import type { ReactNode } from "react";') {
      $out.Add('import UniverseShell from "@/components/UniverseShell";')
    }
  }
  $layoutRaw = ($out.ToArray() -join "`n")
}

# garantir que retorna UniverseShell (fallback)
if ($layoutRaw -notlike "*<UniverseShell>*") {
  $layoutRaw = ReplaceOrThrow $layoutRaw "return <div className=`"cv-universe`">{children}</div>;" "return <UniverseShell>{children}</UniverseShell>;"
}

WriteUtf8NoBom $layoutPath $layoutRaw
WL ("[OK] patched: " + $layoutPath)

# -------------------------
# PATCH 3 — CSS moods (append com marker)
# -------------------------
BackupFile $globalsPath
$css = Get-Content -LiteralPath $globalsPath -Raw

if ($css -like "*/* cv-universe-moods */*") {
  WL "[OK] globals.css já contém moods (marker encontrado)."
} else {
  $moods = @(
    "",
    "/* cv-universe-moods */",
    ".cv-u--home {",
    "  background-image:",
    "    radial-gradient(900px 520px at 20% 12%, rgba(255,255,255,0.07), transparent 60%),",
    "    radial-gradient(720px 420px at 80% 22%, rgba(255,255,255,0.05), transparent 65%),",
    "    linear-gradient(180deg, rgba(0,0,0,0.00), rgba(0,0,0,0.55));",
    "}",
    ".cv-u--aula {",
    "  background-image:",
    "    radial-gradient(920px 520px at 18% 15%, rgba(255,255,255,0.08), transparent 62%),",
    "    radial-gradient(680px 420px at 85% 25%, rgba(255,255,255,0.04), transparent 65%),",
    "    linear-gradient(180deg, rgba(0,0,0,0.00), rgba(0,0,0,0.62));",
    "}",
    ".cv-u--debate {",
    "  background-image:",
    "    radial-gradient(900px 520px at 30% 10%, rgba(255,255,255,0.06), transparent 62%),",
    "    radial-gradient(680px 420px at 75% 30%, rgba(255,255,255,0.06), transparent 65%),",
    "    linear-gradient(180deg, rgba(0,0,0,0.00), rgba(0,0,0,0.66));",
    "}",
    ".cv-u--mapa {",
    "  background-image:",
    "    radial-gradient(900px 520px at 50% 12%, rgba(255,255,255,0.06), transparent 62%),",
    "    radial-gradient(700px 420px at 15% 28%, rgba(255,255,255,0.04), transparent 65%),",
    "    linear-gradient(180deg, rgba(0,0,0,0.00), rgba(0,0,0,0.64));",
    "}",
    ".cv-u--quiz {",
    "  background-image:",
    "    radial-gradient(860px 520px at 20% 12%, rgba(255,255,255,0.07), transparent 60%),",
    "    radial-gradient(740px 440px at 80% 28%, rgba(255,255,255,0.05), transparent 65%),",
    "    linear-gradient(180deg, rgba(0,0,0,0.00), rgba(0,0,0,0.70));",
    "}",
    ".cv-u--pratica {",
    "  background-image:",
    "    radial-gradient(880px 520px at 22% 18%, rgba(255,255,255,0.06), transparent 60%),",
    "    radial-gradient(720px 440px at 78% 26%, rgba(255,255,255,0.04), transparent 65%),",
    "    linear-gradient(180deg, rgba(0,0,0,0.00), rgba(0,0,0,0.68));",
    "}",
    ".cv-u--registro {",
    "  background-image:",
    "    radial-gradient(900px 520px at 25% 12%, rgba(255,255,255,0.05), transparent 62%),",
    "    radial-gradient(720px 440px at 80% 22%, rgba(255,255,255,0.05), transparent 65%),",
    "    linear-gradient(180deg, rgba(0,0,0,0.00), rgba(0,0,0,0.72));",
    "}",
    ".cv-u--acervo {",
    "  background-image:",
    "    radial-gradient(900px 520px at 18% 10%, rgba(255,255,255,0.05), transparent 62%),",
    "    radial-gradient(760px 460px at 85% 35%, rgba(255,255,255,0.04), transparent 65%),",
    "    linear-gradient(180deg, rgba(0,0,0,0.00), rgba(0,0,0,0.72));",
    "}",
    ".cv-u--trilha {",
    "  background-image:",
    "    radial-gradient(900px 520px at 30% 12%, rgba(255,255,255,0.06), transparent 62%),",
    "    radial-gradient(760px 460px at 70% 28%, rgba(255,255,255,0.04), transparent 65%),",
    "    linear-gradient(180deg, rgba(0,0,0,0.00), rgba(0,0,0,0.62));",
    "}"
  ) -join "`n"

  WriteUtf8NoBom $globalsPath ($css + $moods)
  WL "[OK] patched: globals.css (moods appended)"
}

# -------------------------
# REPORT
# -------------------------
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repDir "cv-engine-3c-universe-moods-v0_9.md"
$report = @(
  ("# CV Engine-3C — Universe Moods v0.9 — " + $now),
  "",
  "## O que mudou",
  "- Novo componente client: src/components/UniverseShell.tsx",
  "- Layout do caderno agora usa UniverseShell (aplica classes por rota automaticamente)",
  "- CSS moods adicionados em globals.css (marker: /* cv-universe-moods */)",
  "",
  "## Resultado",
  "- Cada página do caderno ganha um clima de fundo diferente:",
  "  home, aula, debate, mapa, quiz, pratica, registro, acervo, trilha",
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
WL "[OK] Engine-3C aplicado. Teste: /c/poluicao-vr, /c/poluicao-vr/a/1, /c/poluicao-vr/mapa, /c/poluicao-vr/debate"