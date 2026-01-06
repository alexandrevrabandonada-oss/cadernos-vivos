param(
  [switch]$OpenReport
)

$ErrorActionPreference = 'Stop'

function FindRepoRoot([string]$start) {
  $cur = (Resolve-Path -LiteralPath $start).Path
  while ($true) {
    if (Test-Path -LiteralPath (Join-Path $cur 'package.json')) { return $cur }
    $parent = Split-Path -Parent $cur
    if ($parent -eq $cur -or [string]::IsNullOrWhiteSpace($parent)) { break }
    $cur = $parent
  }
  throw 'Não achei package.json. Rode na raiz do repo.'
}

function EnsureDir([string]$p) { if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function WriteUtf8NoBom([string]$p, [string]$content) { [IO.File]::WriteAllText($p, $content, [Text.UTF8Encoding]::new($false)) }

function Rel([string]$base, [string]$full) {
  try { $b = (Resolve-Path -LiteralPath $base).Path.TrimEnd('\') } catch { $b = $base.TrimEnd('\') }
  try { $f = (Resolve-Path -LiteralPath $full).Path } catch { $f = $full }
  if ($f.StartsWith($b)) { return $f.Substring($b.Length).TrimStart('\') }
  return $f
}

$root = FindRepoRoot (Get-Location).Path

$reportsDir = Join-Path $root 'reports'
EnsureDir $reportsDir

$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$reportPath = Join-Path $reportsDir ('cv-step-b4z-audit-v2-no-getcaderno-' + $ts + '.md')

# Escopo: tudo que estiver em /v2 (app) e components/v2, além de lib/v2 por segurança
$paths = @(
  (Join-Path $root 'src\app\c\[slug]\v2'),
  (Join-Path $root 'src\components\v2'),
  (Join-Path $root 'src\lib\v2')
) | Where-Object { Test-Path -LiteralPath $_ }

$hits = New-Object System.Collections.Generic.List[string]

foreach ($p in $paths) {
  $files = Get-ChildItem -LiteralPath $p -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
    $_.Extension -in @('.ts','.tsx','.js','.jsx')
  }

  foreach ($f in $files) {
    $text = [IO.File]::ReadAllText($f.FullName, [Text.UTF8Encoding]::new($false))
    if ($text -match '\bgetCaderno\b') {
      # pega linhas com match (sem regex louca)
      $lines = $text -split "`r?`n"
      for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -match '\bgetCaderno\b') {
          $hits.Add((Rel $root $f.FullName) + ':' + ($i + 1) + ' | ' + $lines[$i].Trim())
        }
      }
    }
  }
}

# roda verify do projeto só pra garantir (não custa)
$verify = Join-Path $root 'tools\cv-verify.ps1'
$verifyExit = 0
$verifyOut = ''
if (Test-Path -LiteralPath $verify) {
  $verifyOut = (& pwsh -NoProfile -ExecutionPolicy Bypass -File $verify 2>&1 | Out-String)
  $verifyExit = $LASTEXITCODE
} else {
  $verifyOut = 'tools/cv-verify.ps1 não encontrado (pulando)'
  $verifyExit = 0
}

# Report
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add('# CV — Step B4z: Audit V2 for leftover getCaderno')
$rep.Add('')
$rep.Add('- when: ' + $ts)
$rep.Add('- scanned:')
foreach ($p in $paths) { $rep.Add('  - ' + (Rel $root $p)) }
$rep.Add('')
$rep.Add('## RESULT')
if ($hits.Count -eq 0) {
  $rep.Add('- OK: nenhum getCaderno encontrado no escopo V2.')
} else {
  $rep.Add('- ATENCAO: ainda existem ocorrencias de getCaderno no escopo V2:')
  foreach ($h in $hits) { $rep.Add('  - ' + $h) }
}
$rep.Add('')
$rep.Add('## VERIFY')
$rep.Add('- exit: ' + $verifyExit)
$rep.Add('')
$rep.Add('--- VERIFY OUTPUT START ---')
foreach ($ln in ($verifyOut -split "`r?`n")) { $rep.Add($ln) }
$rep.Add('--- VERIFY OUTPUT END ---')
$rep.Add('')
$rep.Add('## COMMIT SUGERIDO')
$rep.Add('Mensagem:')
$rep.Add('  chore(cv): V2 pages use safe motor (loadCadernoV2 + metadata)')
$rep.Add('')
$rep.Add('Checklist rapido:')
$rep.Add('- abrir 1 caderno real em /c/SLUG e ver redirect quando meta.ui.default = v2')
$rep.Add('- navegar: /v2 -> debate -> linha -> linha-do-tempo -> mapa -> provas -> trilhas')
$rep.Add('- confirmar build ok (verify acima)')
$rep.Add('')
$rep.Add('Comandos:')
$rep.Add('  git status')
$rep.Add('  git add -A')
$rep.Add('  git commit -m "chore(cv): V2 pages use safe motor (loadCadernoV2 + metadata)"')

WriteUtf8NoBom $reportPath ($rep -join "`n")
Write-Host ('[OK] Report -> ' + $reportPath)
if ($OpenReport) { try { Start-Process $reportPath | Out-Null } catch {} }