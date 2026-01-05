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

function RemoveLinesContaining([string]$raw, [string]$needle) {
  $lines = $raw -split "`r?`n"
  $out = New-Object System.Collections.Generic.List[string]
  foreach ($ln in $lines) {
    if ($ln -notlike ("*" + $needle + "*")) { [void]$out.Add($ln) }
  }
  return ($out -join "`n")
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
    if ($i -eq $lastImport) {
      [void]$out.Add($importLine)
    }
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

function ReplaceLast([string]$raw, [string]$find, [string]$rep) {
  $idx = $raw.LastIndexOf($find)
  if ($idx -lt 0) { return $raw }
  return ($raw.Substring(0, $idx) + $rep + $raw.Substring($idx + $find.Length))
}

function FindCadernoVar([string]$raw) {
  $m = [regex]::Match($raw, 'const\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*await\s+getCaderno\s*\(')
  if ($m.Success) { return $m.Groups[1].Value }
  return "data"
}

# -------------------------
# DIAG
# -------------------------
$repo = ResolveRepoHere
$npmExe = ResolveExe "npm.cmd"

$componentsDir = Join-Path $repo "src\components"
$slugScope = Join-Path $repo "src\app\c\[slug]"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] Components: " + $componentsDir)
WL ("[DIAG] Scope: " + $slugScope)

if (-not (TestP $slugScope)) { throw ("[STOP] Não achei scope: " + $slugScope) }

# -------------------------
# PATCH 1 — CadernoShell
# -------------------------
EnsureDir $componentsDir
$shellPath = Join-Path $componentsDir "CadernoShell.tsx"
BackupFile $shellPath

$shellLines = @(
'import type { ReactNode, CSSProperties } from "react";',
'',
'import CadernoHeader from "@/components/CadernoHeader";',
'import NavPills from "@/components/NavPills";',
'',
'type AccentVars = { ["--accent"]?: string };',
'',
'export default function CadernoShell({',
'  title,',
'  subtitle,',
'  ethos,',
'  accent,',
'  style,',
'  children,',
'}: {',
'  title: string;',
'  subtitle?: string;',
'  ethos?: string;',
'  accent?: string;',
'  style?: CSSProperties;',
'  children: ReactNode;',
'}) {',
'  const finalStyle = {',
'    ...(style ?? {}),',
'    ...(accent ? ({ ["--accent"]: accent } as AccentVars) : {}),',
'  } as CSSProperties & AccentVars;',
'',
'  return (',
'    <main className="space-y-5" style={finalStyle}>',
'      <a',
'        href="#conteudo"',
'        className="sr-only focus:not-sr-only card px-3 py-2 inline-block"',
'      >',
'        Pular para o conteúdo',
'      </a>',
'',
'      <CadernoHeader title={title} subtitle={subtitle} ethos={ethos} />',
'      <NavPills />',
'',
'      <div id="conteudo">{children}</div>',
'    </main>',
'  );',
'}'
)

WriteUtf8NoBom $shellPath ($shellLines -join "`n")
WL ("[OK] wrote: " + $shellPath)

# -------------------------
# PATCH 2 — refatorar pages
# -------------------------
$pageFiles = @()
$pageFiles = @(Get-ChildItem -LiteralPath $slugScope -Recurse -File -Filter "page.tsx" -ErrorAction Stop)

WL ("[DIAG] pages encontradas: " + $pageFiles.Count)

$changed = New-Object System.Collections.Generic.List[string]
$skipped = New-Object System.Collections.Generic.List[string]

foreach ($f in $pageFiles) {
  $p = $f.FullName
  $raw = Get-Content -LiteralPath $p -Raw

  if ($raw -like '*from "@/components/CadernoShell"*') {
    [void]$skipped.Add($p)
    continue
  }

  $var = FindCadernoVar $raw

  # remove imports antigos pra não virar unused
  $raw = RemoveLinesContaining $raw 'from "@/components/CadernoHeader"'
  $raw = RemoveLinesContaining $raw "from '@/components/CadernoHeader'"
  $raw = RemoveLinesContaining $raw 'from "@/components/NavPills"'
  $raw = RemoveLinesContaining $raw "from '@/components/NavPills'"

  # adiciona import do Shell
  $raw = AddImportAfterLastImport $raw 'import CadernoShell from "@/components/CadernoShell";'

  # remove JSX duplicado (header/nav)
  $raw = [regex]::Replace($raw, '(?s)\s*<CadernoHeader\b[\s\S]*?\/>\s*', "`n", 1)
  $raw = [regex]::Replace($raw, '(?s)\s*<NavPills\b[\s\S]*?\/>\s*', "`n", 1)

  # troca <main ...> por <CadernoShell ...>
  if ($raw -like '*<main className="space-y-5" style={s}>*') {
    $open = '<CadernoShell title={' + $var + '.meta.title} subtitle={' + $var + '.meta.subtitle} ethos={' + $var + '.meta.ethos} style={s}>'
    $raw = $raw.Replace('<main className="space-y-5" style={s}>', $open)
  } elseif ($raw -like '*<main className="space-y-5">*') {
    $open = '<CadernoShell title={' + $var + '.meta.title} subtitle={' + $var + '.meta.subtitle} ethos={' + $var + '.meta.ethos}>'
    $raw = $raw.Replace('<main className="space-y-5">', $open)
  } else {
    # se não achou o padrão, não mexe (evita quebrar)
    [void]$skipped.Add($p)
    continue
  }

  # fecha no final
  $raw = ReplaceLast $raw "</main>" "</CadernoShell>"

  BackupFile $p
  WriteUtf8NoBom $p $raw
  [void]$changed.Add($p)
}

WL ("[OK] pages alteradas: " + $changed.Count)
WL ("[OK] pages puladas: " + $skipped.Count)

# -------------------------
# REPORT
# -------------------------
$repDir = Join-Path $repo "reports"
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repDir "cv-engine-1-shell-v0_5.md"

$reportLines = @(
("# CV-Engine-1 — CadernoShell — " + $now),
"",
"## O que foi feito",
"- Criado src/components/CadernoShell.tsx (Header + Nav + SkipLink + container de conteudo).",
"- Refatoradas pages em src/app/c/[slug]/**/page.tsx para usar CadernoShell.",
"- Removidos CadernoHeader/NavPills duplicados das pages (e imports) para evitar lint de unused.",
"",
"## Resultado esperado",
"- UI base consistente em todas as paginas do caderno.",
"- Menos risco de regressao ao evoluir interface/acessibilidade.",
"",
"## Proximo tijolo sugerido",
"- CV-Engine-2: schemas (Zod) para caderno.json / mapa.json / debate.json / acervo.json + mensagens amigaveis."
)

WriteUtf8NoBom $reportPath ($reportLines -join "`n")
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
WL "[OK] CV-Engine-1 concluido. Abra um caderno e veja se todas as abas estao com o mesmo casco."