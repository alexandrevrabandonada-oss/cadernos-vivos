param(
  [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function WL([string]$s) { Write-Host $s }

function EnsureDir([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

function WriteUtf8NoBom([string]$p, [string]$content) {
  $parent = Split-Path -Parent $p
  if ($parent) { EnsureDir $parent }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($p, $content, $enc)
}

function BackupFile([string]$p) {
  if (Test-Path -LiteralPath $p) {
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

function FindRepoRoot() {
  $here = (Get-Location).Path
  $p = $here
  for ($i=0; $i -lt 10; $i++) {
    if (Test-Path -LiteralPath (Join-Path $p "package.json")) { return $p }
    $parent = Split-Path -Parent $p
    if (-not $parent -or $parent -eq $p) { break }
    $p = $parent
  }
  throw ("[STOP] Rode na raiz do repo (onde tem package.json). Atual: " + $here)
}

function NewReportLocal([string]$repo, [string]$name, [string[]]$lines) {
  $rep = Join-Path $repo "reports"
  EnsureDir $rep
  $p = Join-Path $rep $name
  WriteUtf8NoBom $p ($lines -join "`n")
  return $p
}

# -------------------------
# DIAG
# -------------------------
$repo = FindRepoRoot
$npmExe = ResolveExe "npm.cmd"

$navPath = Join-Path $repo "src\components\NavPills.tsx"
$boot = Join-Path $repo "tools\_bootstrap.ps1"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] NavPills: " + $navPath)

if (-not (Test-Path -LiteralPath $navPath)) {
  throw ("[STOP] Não achei NavPills.tsx em: " + $navPath)
}

# tenta puxar NewReport do bootstrap (se existir), mas não depende
if (Test-Path -LiteralPath $boot) {
  try { . $boot } catch { }
}

# -------------------------
# PATCH: reescrever NavPills estável (evita vírgula faltando / JSX quebrado)
# -------------------------
BackupFile $navPath

$lines = @(
'"use client";',
'',
'import React from "react";',
'import Link from "next/link";',
'import { useParams, usePathname } from "next/navigation";',
'',
'type Props = { slug?: string };',
'',
'function asSlug(v: unknown): string {',
'  if (!v) return "";',
'  if (Array.isArray(v)) return v.length ? String(v[0]) : "";',
'  return String(v);',
'}',
'',
'export default function NavPills({ slug }: Props) {',
'  const params = useParams() as Record<string, unknown>;',
'  const pathname = usePathname();',
'  const s = (slug && String(slug)) ? String(slug) : asSlug(params["slug"]);',
'',
'  const items = React.useMemo(() => {',
'    if (!s) return [];',
'    return [',
'      { key: "home", label: "Caderno", href: "/c/" + s },',
'      { key: "aulas", label: "Aulas", href: "/c/" + s + "/a/1" },',
'      { key: "trilha", label: "Trilha", href: "/c/" + s + "/trilha" },',
'      { key: "pratica", label: "Prática", href: "/c/" + s + "/pratica" },',
'      { key: "quiz", label: "Quiz", href: "/c/" + s + "/quiz" },',
'      { key: "acervo", label: "Acervo", href: "/c/" + s + "/acervo" },',
'      { key: "debate", label: "Debate", href: "/c/" + s + "/debate" },',
'      { key: "mapa", label: "Mapa", href: "/c/" + s + "/mapa" },',
'      { key: "registro", label: "Registro", href: "/c/" + s + "/registro" },',
'      { key: "status", label: "Status", href: "/c/" + s + "/status" },',
'    ];',
'  }, [s]);',
'',
'  if (!items.length) return null;',
'',
'  return (',
'    <nav aria-label="Seções do caderno" className="my-3">', 
'      <div className="flex flex-wrap gap-2">', 
'        {items.map((it) => {',
'          const active = !!pathname && (pathname === it.href || pathname.startsWith(it.href + "/"));',
'          const cls = active',
'            ? "px-3 py-1 rounded-full border text-sm font-semibold"',
'            : "px-3 py-1 rounded-full border text-sm";',
'          return (',
'            <Link',
'              key={it.key}',
'              href={it.href}',
'              aria-current={active ? "page" : undefined}',
'              className={cls}',
'            >',
'              {it.label}',
'            </Link>',
'          );',
'        })}',
'      </div>',
'    </nav>',
'  );',
'}',
''
) -join "`n"

WriteUtf8NoBom $navPath $lines
WL "[OK] wrote: NavPills.tsx (rewrite estável)"

# -------------------------
# REPORT
# -------------------------
$repLines = @(
("# Hotfix — NavPills rewrite v0_17e — " + (Get-Date -Format "yyyy-MM-dd HH:mm")),
"",
"## O que quebrou",
"- Lint acusou parsing error em src/components/NavPills.tsx (virgula/TSX quebrado).",
"",
"## O que fizemos",
"- Reescrevemos NavPills.tsx inteiro num formato estável:",
"  - slug opcional (prop) + fallback via useParams()",
"  - itens definidos com vírgulas garantidas",
"  - inclui link Status (/status)",
"",
"## Verificação",
"- npm run lint",
"- npm run build (se não usar -SkipBuild)"
)

$repPath = $null
$cmd = Get-Command NewReport -ErrorAction SilentlyContinue
if ($cmd) {
  $repPath = NewReport "cv-hotfix-navpills-rewrite-v0_17e.md" $repLines
} else {
  $repPath = NewReportLocal $repo "cv-hotfix-navpills-rewrite-v0_17e.md" $repLines
}
WL ("[OK] Report: " + $repPath)

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
WL "[OK] Hotfix aplicado: NavPills lint OK."