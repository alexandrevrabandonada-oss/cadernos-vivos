param(
  [switch]$Verify
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function WL([string]$s) { Write-Host $s }
function EnsureDir([string]$p) { if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function WriteUtf8NoBom([string]$p, [string]$content) {
  $parent = Split-Path -Parent $p
  if ($parent) { EnsureDir $parent }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($p, $content, $enc)
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
  if (Test-Path -LiteralPath (Join-Path $here "package.json")) { return $here }
  throw ("[STOP] Rode na raiz do repo (onde tem package.json). Atual: " + $here)
}
function NewReport([string]$name, [string]$content) {
  $repo = (Get-Location).Path
  $repDir = Join-Path $repo "reports"
  EnsureDir $repDir
  $p = Join-Path $repDir $name
  WriteUtf8NoBom $p $content
  return $p
}
function CountOf($x) {
  if ($null -eq $x) { return 0 }
  return (@($x) | Measure-Object).Count
}

function Rel([string]$root, [string]$p) {
  $r = $root.TrimEnd('\')
  if ($p.StartsWith($r)) { return $p.Substring($r.Length).TrimStart('\') }
  return $p
}

# -------------------------
# DIAG
# -------------------------
$repo = ResolveRepoHere
$npmExe = ResolveExe "npm.cmd"
$nodeExe = ResolveExe "node.exe"

$appDir = Join-Path $repo "src\app"
$componentsDir = Join-Path $repo "src\components"
$libDir = Join-Path $repo "src\lib"
$contentDir = Join-Path $repo "content\cadernos"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] app: " + $appDir)
WL ("[DIAG] components: " + $componentsDir)
WL ("[DIAG] lib: " + $libDir)
WL ("[DIAG] content: " + $contentDir)

$nodeV = ""
$npmV = ""
try { $nodeV = (& $nodeExe -v) } catch { $nodeV = "" }
try { $npmV = (& $npmExe -v) } catch { $npmV = "" }

# -------------------------
# Inventário de rotas
# -------------------------
$routeFiles = @()
if (Test-Path -LiteralPath $appDir) {
  $routeFiles = @(
    Get-ChildItem -LiteralPath $appDir -Recurse -File -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -in @("page.tsx","page.ts","layout.tsx","layout.ts","route.ts","route.tsx","loading.tsx","error.tsx","not-found.tsx") } |
      Sort-Object FullName
  )
}

$pageFiles = @($routeFiles | Where-Object { $_.Name -like "page.*" })
$layoutFiles = @($routeFiles | Where-Object { $_.Name -like "layout.*" })
$routeHandlers = @($routeFiles | Where-Object { $_.Name -like "route.*" })

function RouteFromFile([string]$fullPath) {
  $rel = Rel $repo $fullPath
  $p = $rel.Replace("src\app","").Replace("\","/")
  $p = $p -replace "/page\.(ts|tsx)$",""
  $p = $p -replace "/layout\.(ts|tsx)$",""
  $p = $p -replace "/route\.(ts|tsx)$",""
  if ([string]::IsNullOrWhiteSpace($p)) { $p = "/" }
  return $p
}

$routesList = @()
foreach ($f in $pageFiles) {
  $routesList += ("- " + (RouteFromFile $f.FullName) + "  (" + (Rel $repo $f.FullName) + ")")
}

# -------------------------
# Componentes e libs
# -------------------------
$compFiles = @()
if (Test-Path -LiteralPath $componentsDir) {
  $compFiles = @(
    Get-ChildItem -LiteralPath $componentsDir -Recurse -File -ErrorAction SilentlyContinue |
      Where-Object { $_.Extension -in @(".ts",".tsx") } |
      Sort-Object FullName
  )
}

$libFiles = @()
if (Test-Path -LiteralPath $libDir) {
  $libFiles = @(
    Get-ChildItem -LiteralPath $libDir -Recurse -File -ErrorAction SilentlyContinue |
      Where-Object { $_.Extension -in @(".ts",".tsx") } |
      Sort-Object FullName
  )
}

# -------------------------
# Cadernos (content)
# -------------------------
$cadernos = @()
if (Test-Path -LiteralPath $contentDir) {
  $cadernos = @(
    Get-ChildItem -LiteralPath $contentDir -Directory -ErrorAction SilentlyContinue | Sort-Object Name
  )
}

function HasFile([string]$dir, [string]$name) {
  return (Test-Path -LiteralPath (Join-Path $dir $name))
}

$cadernoRows = @()
foreach ($c in $cadernos) {
  $dir = $c.FullName
  $slug = $c.Name

  $meta = HasFile $dir "meta.json"
  $pan = HasFile $dir "panorama.md"
  $refs = HasFile $dir "referencias.md"
  $mapa = HasFile $dir "mapa.json"
  $acervo = HasFile $dir "acervo.json"
  $debate = HasFile $dir "debate.json"
  $registro = HasFile $dir "registro.json"

  $aulasDir = Join-Path $dir "aulas"
  $aulasCount = 0
  if (Test-Path -LiteralPath $aulasDir) {
    $aulasCount = (Get-ChildItem -LiteralPath $aulasDir -File -Filter "*.md" -ErrorAction SilentlyContinue | Measure-Object).Count
  }

  $ok = @($meta,$pan,$refs,$mapa,$acervo,$debate,$registro) -notcontains $false

  $cadernoRows += ("| " + $slug + " | " + ($ok ? "OK" : "FALTAS") + " | " +
    ($meta ? "✅" : "❌") + " | " +
    ($pan ? "✅" : "❌") + " | " +
    ($refs ? "✅" : "❌") + " | " +
    ($mapa ? "✅" : "❌") + " | " +
    ($acervo ? "✅" : "❌") + " | " +
    ($debate ? "✅" : "❌") + " | " +
    ($registro ? "✅" : "❌") + " | " +
    ($aulasCount.ToString()) + " |")
}

# -------------------------
# Checagem V2
# -------------------------
$v2Candidates = @(
  (Join-Path $repo "src\app\c\[slug]\v2"),
  (Join-Path $repo "src\app\caderno\[slug]\v2"),
  (Join-Path $repo "src\app\c\[slug]\v2\page.tsx"),
  (Join-Path $repo "src\app\caderno\[slug]\v2\page.tsx")
)
$v2Found = $false
foreach ($p in $v2Candidates) {
  if (Test-Path -LiteralPath $p) { $v2Found = $true; break }
}

# -------------------------
# REPORT
# -------------------------
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$lines = @()

$lines += ("# CV — Tijolo A (DIAG) — Inventário total — " + $now)
$lines += ""
$lines += "## Ambiente"
$lines += ("- Repo: " + $repo)
$lines += ("- Node: " + ($nodeV ? $nodeV : "(não detectado)"))
$lines += ("- npm: " + ($npmV ? $npmV : "(não detectado)"))
$lines += ""
$lines += "## Rotas (src/app)"
$lines += ("- Total de arquivos de rota: " + (CountOf $routeFiles))
$lines += ("- Pages: " + (CountOf $pageFiles) + " | Layouts: " + (CountOf $layoutFiles) + " | Route handlers: " + (CountOf $routeHandlers))
$lines += ""
$lines += "### Pages detectadas"
if ((CountOf $routesList) -gt 0) { $lines += $routesList } else { $lines += "- (nenhuma page encontrada)" }
$lines += ""
$lines += "## Componentes (src/components)"
$lines += ("- Total: " + (CountOf $compFiles))
$lines += ""
$lines += "## Libs (src/lib)"
$lines += ("- Total: " + (CountOf $libFiles))
$lines += ""
$lines += "## Cadernos (content/cadernos)"
$lines += ("- Total: " + (CountOf $cadernos))
$lines += ""
$lines += "| slug | status | meta.json | panorama.md | referencias.md | mapa.json | acervo.json | debate.json | registro.json | aulas.md |"
$lines += "|---|---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|---:|"
if ((CountOf $cadernoRows) -gt 0) { $lines += $cadernoRows } else { $lines += "| (nenhum) | - | - | - | - | - | - | - | - | - |" }
$lines += ""
$lines += "## V2 (Concreto Zen) — presença no código"
$lines += ("- Placeholder V2 encontrado? " + ($v2Found ? "SIM" : "NÃO (a criar no Tijolo C)"))
$lines += ""
$lines += "## Próximo"
$lines += "- Tijolo B: Data layer (types + normalize superset) sem mexer na UI."

$repPath = NewReport "cv-v2-tijolo-a-diag-inventario-v0_1b.md" ($lines -join "`n")
WL ("[OK] Report: " + $repPath)

if ($Verify) {
  WL "[VERIFY] npm run lint..."
  RunNative $repo $npmExe @("run","lint")
  WL "[VERIFY] npm run build..."
  RunNative $repo $npmExe @("run","build")
} else {
  WL "[VERIFY] pulado (use -Verify)."
}

WL "[OK] Tijolo A (DIAG) concluído."