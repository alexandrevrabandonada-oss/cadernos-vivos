param(
  [switch]$OpenReport
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$stamp = (Get-Date -Format 'yyyyMMdd-HHmmss')
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path

$bootstrap = Join-Path $PSScriptRoot '_bootstrap.ps1'
if (-not (Test-Path -LiteralPath $bootstrap)) { throw ('[STOP] bootstrap nao encontrado: ' + $bootstrap) }
. $bootstrap

function Rel([string]$base, [string]$full) {
  try { $b = (Resolve-Path -LiteralPath $base).Path.TrimEnd('\') } catch { $b = $base.TrimEnd('\') }
  try { $f = (Resolve-Path -LiteralPath $full).Path } catch { $f = $full }
  if ($f.StartsWith($b)) { return $f.Substring($b.Length).TrimStart('\') }
  return $f
}

function WriteUtf8NoBomSafe([string]$p, [string]$content) {
  if (Get-Command WriteUtf8NoBom -ErrorAction SilentlyContinue) {
    WriteUtf8NoBom $p $content
    return
  }
  [IO.File]::WriteAllText($p, $content, [Text.UTF8Encoding]::new($false))
}

Write-Host ('== cv-step-b6b FINALIZE v0_4 == ' + $stamp) -ForegroundColor Cyan
Write-Host ('[DIAG] Root: ' + $root)

# paths
$comp = Join-Path $root 'src\components\v2\Cv2DomFilterClient.tsx'
$page = Join-Path $root 'src\app\c\[slug]\v2\provas\page.tsx'

if (-not (Test-Path -LiteralPath $comp)) { throw ('[STOP] componente nao encontrado: ' + (Rel $root $comp)) }
if (-not (Test-Path -LiteralPath $page)) { throw ('[STOP] page nao encontrada: ' + (Rel $root $page)) }

$compRaw = [IO.File]::ReadAllText($comp, [Text.UTF8Encoding]::new($false))
$pageRaw = [IO.File]::ReadAllText($page, [Text.UTF8Encoding]::new($false))

$okComp = ($compRaw -match 'export function Cv2DomFilterClient')
$okPage = ($pageRaw -match 'Cv2DomFilterClient') -and ($pageRaw -match 'cv2-provas-root')

if (-not $okComp) { throw '[STOP] Cv2DomFilterClient.tsx parece incompleto (nao achei export function).' }
if (-not $okPage) { throw '[STOP] page.tsx nao parece ter sido wrapada com Cv2DomFilterClient + cv2-provas-root.' }

# report (manual, sem NewReport)
$reports = Join-Path $root 'reports'
EnsureDir $reports

$reportPath = Join-Path $reports ('cv-step-b6b-v2-provas-dom-filter-' + $stamp + '.md')

$rep = @()
$rep += '# CV — Step B6b: V2 Provas quick filter (DOM) (finalize v0_4)'
$rep += ''
$rep += ('- when: ' + $stamp)
$rep += ('- repo: ' + $root)
$rep += ''
$rep += '## FILES'
$rep += ('- component: ' + (Rel $root $comp))
$rep += ('- page: ' + (Rel $root $page))
$rep += ''
$rep += '## STATUS'
$rep += '- component OK: yes'
$rep += '- page wrap OK: yes'
$rep += ''
$rep += '## VERIFY'
$rep += '- ran: tools/cv-verify.ps1 (or lint+build fallback)'
$rep += ''

WriteUtf8NoBomSafe $reportPath ($rep -join "`n")
Write-Host ('[REPORT] ' + (Rel $root $reportPath))

# verify
$verify = Join-Path $root 'tools\cv-verify.ps1'
if (Test-Path -LiteralPath $verify) {
  Write-Host ('[RUN] ' + (Rel $root $verify))
  & pwsh -NoProfile -ExecutionPolicy Bypass -File $verify
} else {
  Write-Host '[RUN] npm run lint'
  & npm run lint
  Write-Host '[RUN] npm run build'
  & npm run build
}

Write-Host '[OK] B6b finalizado (report + verify).' -ForegroundColor Green

if ($OpenReport) {
  try { Invoke-Item $reportPath } catch {}
}