# cv-hotfix-b7i2-verify-npmcmd-and-portals-diag-v0_2
# DIAG: presença Cv2PortalsCurated nas pages V2
# VERIFY: npm run lint/build usando npm.cmd (nao npm.ps1 cmd)
$ErrorActionPreference = "Stop"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$repoRoot = (Resolve-Path ".").Path
$nl = [Environment]::NewLine

function EnsureDir([string]$abs) { if (-not (Test-Path -LiteralPath $abs)) { [IO.Directory]::CreateDirectory($abs) | Out-Null } }
function ReadText([string]$abs) { if (-not (Test-Path -LiteralPath $abs)) { return $null }; return [IO.File]::ReadAllText($abs) }
function WriteText([string]$abs, [string]$text) {
  $enc = New-Object System.Text.UTF8Encoding($false)
  EnsureDir (Split-Path -Parent $abs)
  [IO.File]::WriteAllText($abs, $text, $enc)
}

function FindNpmCmd() {
  foreach ($name in @('npm.cmd','npm.exe')) {
    try {
      $p = (Get-Command $name -ErrorAction Stop).Path
      if ($p) { return $p }
    } catch {}
  }
  try {
    $p = (Get-Command npm -ErrorAction Stop).Path
    if ($p) {
      $lp = $p.ToLowerInvariant()
      if ($lp.EndsWith('\npm.ps1')) {
        $dir = Split-Path -Parent $p
        $cand = Join-Path $dir 'npm.cmd'
        if (Test-Path -LiteralPath $cand) { return $cand }
        $cand2 = Join-Path $dir 'npm.exe'
        if (Test-Path -LiteralPath $cand2) { return $cand2 }
      }
      return $p
    }
  } catch {}
  return $null
}

function RunNpm([string[]]$argv) {
  $npmCmd = FindNpmCmd
  if (-not $npmCmd) { throw 'npm nao encontrado no PATH' }
  Write-Host ('[RUN] ' + $npmCmd + ' ' + ($argv -join ' '))
  & $npmCmd @argv
  if ($LASTEXITCODE -ne 0) { throw ('npm failed: ' + ($argv -join ' ')) }
}

EnsureDir (Join-Path $repoRoot 'reports')
$rep = Join-Path $repoRoot ('reports\' + $stamp + '-cv-hotfix-b7i2-verify-npmcmd-and-portals-diag-v0_2.md')
$r = New-Object System.Collections.Generic.List[string]
$r.Add('# Hotfix B7I2 v0_2 — verify npm.cmd + diag portais — ' + $stamp) | Out-Null
$r.Add('') | Out-Null
$r.Add('Repo: ' + $repoRoot) | Out-Null
$r.Add('') | Out-Null

$r.Add('## DIAG — Git status') | Out-Null
$r.Add('') | Out-Null
try { $r.Add((git status | Out-String).TrimEnd()) | Out-Null } catch { $r.Add('ERR: git status') | Out-Null }
$r.Add('') | Out-Null

$npmFound = FindNpmCmd
$r.Add('## DIAG — npm executavel') | Out-Null
$r.Add('') | Out-Null
$r.Add('- npm: ' + ($(if($npmFound){$npmFound}else{'(nao encontrado)'}))) | Out-Null
$r.Add('') | Out-Null

# DIAG Portals
$portalsRel = 'src\components\v2\Cv2PortalsCurated.tsx'
$portalsAbs = Join-Path $repoRoot $portalsRel
$r.Add('## DIAG — Cv2PortalsCurated existe?') | Out-Null
$r.Add('') | Out-Null
$r.Add('- ' + $portalsRel + ' : ' + ($(if(Test-Path -LiteralPath $portalsAbs){'OK'}else{'MISSING'}))) | Out-Null
$r.Add('') | Out-Null

$v2Dir = Join-Path $repoRoot 'src\app\c\[slug]\v2'
$r.Add('## DIAG — Pages V2 e uso de portais') | Out-Null
$r.Add('') | Out-Null
if (-not (Test-Path -LiteralPath $v2Dir)) {
  $r.Add('[ERR] missing: src/app/c/[slug]/v2') | Out-Null
} else {
  $pages = Get-ChildItem -LiteralPath $v2Dir -Recurse -File -Filter 'page.tsx'
  foreach ($p in $pages) {
    $raw = ReadText $p.FullName
    if ($null -eq $raw) { continue }
    $rel = $p.FullName.Substring($repoRoot.Length).TrimStart('\')
    $hasCur = ($raw.IndexOf('Cv2PortalsCurated', [StringComparison]::OrdinalIgnoreCase) -ge 0)
    $hasLegacy = (($raw.IndexOf('V2Portals', [StringComparison]::OrdinalIgnoreCase) -ge 0) -or ($raw.IndexOf('PortaisV2', [StringComparison]::OrdinalIgnoreCase) -ge 0))
    $mark = $(if($hasCur){'CURATED'}elseif($hasLegacy){'LEGACY'}else{'NONE'})
    $r.Add('- ' + $mark + ' : ' + $rel) | Out-Null
  }
}
$r.Add('') | Out-Null

# VERIFY
$r.Add('## VERIFY') | Out-Null
$r.Add('') | Out-Null
$failed = $false
try { RunNpm @('run','lint'); $r.Add('- npm run lint: OK') | Out-Null } catch { $failed = $true; $r.Add('- npm run lint: FAIL') | Out-Null; $r.Add('  ' + $_.Exception.Message) | Out-Null }
try { RunNpm @('run','build'); $r.Add('- npm run build: OK') | Out-Null } catch { $failed = $true; $r.Add('- npm run build: FAIL') | Out-Null; $r.Add('  ' + $_.Exception.Message) | Out-Null }
$r.Add('') | Out-Null

$r.Add('## Proximo tijolo sugerido') | Out-Null
$r.Add('') | Out-Null
$r.Add('- Se houver paginas LEGACY/NONE: eu gero o B7I3 que troca tudo para Cv2PortalsCurated (sem quebrar filtros/pager).') | Out-Null
$r.Add('- Se tudo CURATED: proximo e ajustar microcopy/ordem do DoorGuide+Portais e fazer commit limpo.') | Out-Null
$r.Add('') | Out-Null

WriteText $rep ([string]::Join($nl, $r.ToArray()) + $nl)
Write-Host ('[REPORT] ' + $rep)
if ($failed) { throw 'B7I2 v0_2: verify failed (see report).' }
Write-Host '[OK] B7I2 v0_2 finalizado.'