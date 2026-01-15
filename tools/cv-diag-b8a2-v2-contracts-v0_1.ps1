param([switch]$OpenReport)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function EnsureDir([string]$p){
  if(-not (Test-Path $p)){
    New-Item -ItemType Directory -Force -Path $p | Out-Null
  }
}
function WriteUtf8NoBom([string]$path,[string]$content){
  $enc = New-Object System.Text.UTF8Encoding($false)
  [IO.File]::WriteAllText($path, $content, $enc)
}
function AppendUtf8NoBom([string]$path,[string]$content){
  $enc = New-Object System.Text.UTF8Encoding($false)
  [IO.File]::AppendAllText($path, $content, $enc)
}
function NowStamp(){ (Get-Date).ToString("yyyyMMdd-HHmmss") }

$repoRoot   = (Resolve-Path ".").Path
$toolsDir   = Join-Path $repoRoot "tools"
$reportsDir = Join-Path $repoRoot "reports"
EnsureDir $toolsDir
EnsureDir $reportsDir

$stamp = NowStamp
$reportPath = Join-Path $reportsDir ("{0}-cv-diag-b8a2-v2-contracts.md" -f $stamp)

WriteUtf8NoBom $reportPath ("# CV DIAG B8A2 — Contratos & Replug V2`n`n- Data: **$stamp**`n- Repo: `$repoRoot`n`n")

function H2([string]$t){ AppendUtf8NoBom $reportPath ("## " + $t + "`n`n") }
function H3([string]$t){ AppendUtf8NoBom $reportPath ("### " + $t + "`n`n") }

function DumpHead([string]$file, [int]$n = 140){
  if(-not (Test-Path $file)){
    AppendUtf8NoBom $reportPath ("(arquivo não encontrado)`n`n")
    return
  }
  $raw = Get-Content -Encoding UTF8 -Path $file
  $take = $raw | Select-Object -First $n
  AppendUtf8NoBom $reportPath ("**" + $file + "**`n`n~~~tsx`n")
  foreach($l in $take){ AppendUtf8NoBom $reportPath (([string]$l).TrimEnd("`r") + "`n") }
  AppendUtf8NoBom $reportPath "~~~`n`n"
}

function Grep([string]$file, [string[]]$patterns){
  if(-not (Test-Path $file)){
    AppendUtf8NoBom $reportPath ("(arquivo não encontrado)`n`n")
    return
  }
  AppendUtf8NoBom $reportPath ("**" + $file + "**`n`n")
  foreach($p in $patterns){
    $hits = Select-String -Path $file -Pattern $p -SimpleMatch -ErrorAction SilentlyContinue
    if($null -eq $hits){
      AppendUtf8NoBom $reportPath ("- no match: " + $p + "`n")
    } else {
      foreach($h in $hits){
        $ln = $h.LineNumber
        $tx = ($h.Line.TrimEnd("`r"))
        AppendUtf8NoBom $reportPath ("- L" + $ln + ": " + $tx + "`n")
      }
    }
  }
  AppendUtf8NoBom $reportPath "`n"
}

H2 "Rotas V2 — lista e imports chaves"

$routesRoot = Join-Path $repoRoot "src\app\c\[slug]\v2"
if(Test-Path $routesRoot){
  $pages = Get-ChildItem -Path $routesRoot -Recurse -Filter "page.tsx" -File -ErrorAction SilentlyContinue
  AppendUtf8NoBom $reportPath ("Total page.tsx: **" + (@($pages).Count) + "**`n`n")
  foreach($p in $pages){
    H3 ($p.FullName.Substring($repoRoot.Length+1))
    Grep $p.FullName @(
      "export default async function Page",
      "type Cv2PageProps",
      "Cv2V2Nav",
      "Cv2DoorGuide",
      "Cv2PortalsCurated",
      "ShellV2",
      "Cv2UniverseRail",
      "Cv2EmptyState",
      "data-cv2="
    )
  }
} else {
  AppendUtf8NoBom $reportPath ("Rotas V2 não encontradas em: " + $routesRoot + "`n`n")
}

H2 "Contratos — Componentes V2 chave (props / tipos / exports)"

$compRoot = Join-Path $repoRoot "src\components\v2"
$targets = @(
  "ShellV2.tsx",
  "Cv2V2Nav.tsx",
  "Cv2DoorGuide.tsx",
  "Cv2PortalsCurated.tsx",
  "Cv2UniverseRail.tsx",
  "Cv2EmptyState.tsx",
  "Cv2CoreNodes.tsx",
  "Cv2CoreHighlights.tsx",
  "Cv2MapFirstCta.tsx",
  "Cv2MapRail.tsx",
  "Cv2HubKeyNavClient.tsx"
)

if(Test-Path $compRoot){
  foreach($t in $targets){
    $full = Join-Path $compRoot $t
    H3 ("components/v2/" + $t)
    Grep $full @(
      "export default function",
      "export default async function",
      "export function",
      "type Props",
      "interface Props",
      "export type",
      "type Cv2DoorId",
      "Props =",
      "props:",
      "slug:",
      "active",
      "current",
      "title"
    )
    DumpHead $full 120
  }
} else {
  AppendUtf8NoBom $reportPath ("Componentes V2 não encontrados em: " + $compRoot + "`n`n")
}

H2 "Sinais de Replug (heurística)"

AppendUtf8NoBom $reportPath @"
Critério que vamos usar no PATCH seguinte (B8P1):

- Todas as páginas V2 devem ter:
  1) Cv2V2Nav (active correto)
  2) Cv2DoorGuide (active correto)
  3) Um bloco de Portais (curated) com 3–6 "próximas portas" (map-first)
  4) Fallback Cv2EmptyState quando faltar conteúdo
  5) Um link/cta consistente de "Voltar ao Hub"

Este DIAG serve para confirmar os props exatos (para patchar sem quebrar).
"@ + "`n"

Write-Host ("[REPORT] " + $reportPath)
if($OpenReport){
  try { Start-Process $reportPath | Out-Null } catch {}
}