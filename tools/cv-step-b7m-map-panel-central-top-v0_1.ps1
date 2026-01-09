# cv-step-b7m-map-panel-central-top-v0_1
# DIAG -> PATCH -> VERIFY -> REPORT
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
function BackupFile([string]$rel) {
  $abs = Join-Path $repoRoot $rel
  if (-not (Test-Path -LiteralPath $abs)) { return }
  $bkDir = Join-Path $repoRoot 'tools\_patch_backup'
  EnsureDir $bkDir
  $dst = Join-Path $bkDir ($stamp + '-' + (Split-Path -Leaf $abs) + '.bak')
  Copy-Item -LiteralPath $abs -Destination $dst -Force
}

function FindNpmCmd() {
  foreach ($name in @('npm.cmd','npm.exe')) {
    try { $p = (Get-Command $name -ErrorAction Stop).Path; if ($p) { return $p } } catch {}
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

function IndexOfIgnoreCase([string]$hay, [string]$needle) {
  return $hay.IndexOf($needle, [StringComparison]::OrdinalIgnoreCase)
}
function InsertBeforeToken([string]$raw, [string]$token, [string]$insert) {
  $i = IndexOfIgnoreCase $raw $token
  if ($i -lt 0) { return @{ ok=$false; raw=$raw; where='token_not_found' } }
  $raw2 = $raw.Substring(0,$i) + $insert + $nl + $raw.Substring($i)
  return @{ ok=$true; raw=$raw2; where=('before:' + $token) }
}
function EnsureImportLink([string]$raw) {
  if (($raw.IndexOf("from 'next/link'", [StringComparison]::OrdinalIgnoreCase) -ge 0) -or
      ($raw.IndexOf('from "next/link"', [StringComparison]::OrdinalIgnoreCase) -ge 0)) {
    return @{ raw=$raw; changed=$false; note='link_import_exists' }
  }
  $imp = $raw.IndexOf('import ', [StringComparison]::Ordinal)
  if ($imp -lt 0) {
    # sem imports? coloca no topo
    $ins = 'import Link from "next/link";' + $nl
    return @{ raw=($ins + $raw); changed=$true; note='link_import_added_top' }
  }
  $eol = $raw.IndexOf("`n", $imp)
  if ($eol -lt 0) {
    $ins = $nl + 'import Link from "next/link";' + $nl
    return @{ raw=($raw + $ins); changed=$true; note='link_import_added_eof' }
  }
  $ins = $nl + 'import Link from "next/link";'
  $raw2 = $raw.Substring(0,$eol) + $ins + $raw.Substring($eol)
  return @{ raw=$raw2; changed=$true; note='link_import_added_after_first_import' }
}

EnsureDir (Join-Path $repoRoot 'reports')
EnsureDir (Join-Path $repoRoot 'tools\_patch_backup')

$rep = Join-Path $repoRoot ('reports\' + $stamp + '-cv-step-b7m-map-panel-central-top.md')
$r = New-Object System.Collections.Generic.List[string]
$r.Add('# Tijolo B7M — Mapa Painel Central (Top Panel) — ' + $stamp) | Out-Null
$r.Add('') | Out-Null
$r.Add('Repo: ' + $repoRoot) | Out-Null
$r.Add('') | Out-Null

# DIAG
$r.Add('## DIAG') | Out-Null
$r.Add('') | Out-Null
try { $r.Add((git status | Out-String).TrimEnd()) | Out-Null } catch { $r.Add('ERR: git status') | Out-Null }
$r.Add('') | Out-Null

$mapRel = 'src\app\c\[slug]\v2\mapa\page.tsx'
$mapAbs = Join-Path $repoRoot $mapRel
if (-not (Test-Path -LiteralPath $mapAbs)) { throw ('Missing: ' + $mapRel) }

$cssRel = 'src\app\globals.css'
$cssAbs = Join-Path $repoRoot $cssRel
if (-not (Test-Path -LiteralPath $cssAbs)) { throw ('Missing: ' + $cssRel) }

$raw = ReadText $mapAbs
if ($null -eq $raw) { throw ('Empty: ' + $mapRel) }

$r.Add('- target: ' + $mapRel) | Out-Null
$r.Add('- token check: Cv2MapRail=' + ($(if(IndexOfIgnoreCase $raw '<Cv2MapRail' -ge 0){'YES'}else{'NO'}))) | Out-Null
$r.Add('- token check: Cv2DoorGuide=' + ($(if(IndexOfIgnoreCase $raw 'Cv2DoorGuide' -ge 0){'YES'}else{'NO'}))) | Out-Null
$r.Add('- token check: Cv2PortalsCurated=' + ($(if(IndexOfIgnoreCase $raw 'Cv2PortalsCurated' -ge 0){'YES'}else{'NO'}))) | Out-Null
$r.Add('') | Out-Null

# PATCH A: map page top panel
$r.Add('## PATCH A — inserir Top Panel no /mapa') | Out-Null
$r.Add('') | Out-Null

if (IndexOfIgnoreCase $raw 'data-cv2-map-panel-top="1"' -ge 0) {
  $r.Add('- skip: marker already present') | Out-Null
} else {
  BackupFile $mapRel

  # garantir import Link
  $impRes = EnsureImportLink $raw
  $raw = $impRes.raw
  $r.Add('- import Link: ' + $impRes.note) | Out-Null

  $panelLines = @(
    '',
    '{/* CV2 Map Panel Top */}',
    '<section className="cv2-mapPanelTop" data-cv2-map-panel-top="1">',
    '  <div className="cv2-mapPanelTopRow">',
    '    <div className="cv2-mapPanelTopTitle">',
    '      <div className="cv2-kicker">PAINEL CENTRAL</div>',
    '      <h2 className="cv2-h2">Comece pelo mapa</h2>',
    '      <p className="cv2-muted">Nucleo, trilhos e portas. O mapa e o painel do universo.</p>',
    '    </div>',
    '    <div className="cv2-mapPanelTopActions" role="navigation" aria-label="Atalhos do universo">',
    '      <Link className="cv2-pill" href={"/c/" + slug + "/v2"}>Hub</Link>',
    '      <Link className="cv2-pill" href={"/c/" + slug + "/v2/linha"}>Linha</Link>',
    '      <Link className="cv2-pill" href={"/c/" + slug + "/v2/linha-do-tempo"}>Tempo</Link>',
    '      <Link className="cv2-pill" href={"/c/" + slug + "/v2/provas"}>Provas</Link>',
    '      <Link className="cv2-pill" href={"/c/" + slug + "/v2/trilhas"}>Trilhas</Link>',
    '      <Link className="cv2-pill" href={"/c/" + slug + "/v2/debate"}>Debate</Link>',
    '    </div>',
    '  </div>',
    '</section>',
    ''
  )
  $insert = ($panelLines -join $nl)

  $ins = InsertBeforeToken $raw '<Cv2MapRail' $insert
  if (-not $ins.ok) { throw ('Could not insert panel (reason: ' + $ins.where + ')') }
  $raw = $ins.raw
  WriteText $mapAbs ($raw.TrimEnd() + $nl)
  $r.Add('- inserted: Top Panel ' + $ins.where) | Out-Null
}
$r.Add('') | Out-Null

# PATCH B: CSS for panel
$r.Add('## PATCH B — CSS (Concreto Zen)') | Out-Null
$r.Add('') | Out-Null

$cssRaw = ReadText $cssAbs
if ($null -eq $cssRaw) { throw ('Empty: ' + $cssRel) }

if ($cssRaw.IndexOf('CV2 — Map Panel Top', [StringComparison]::OrdinalIgnoreCase) -ge 0) {
  $r.Add('- skip: globals.css already has Map Panel Top block') | Out-Null
} else {
  BackupFile $cssRel
  $cssBlock = @(
    '',
    '/* ============================ */',
    '/* CV2 — Map Panel Top (panel central) */',
    '/* ============================ */',
    '.cv2-mapPanelTop{',
    '  margin: 12px 0 14px 0;',
    '  padding: 12px 12px;',
    '  border-radius: 16px;',
    '  border: 1px solid rgba(255,255,255,.10);',
    '  background: rgba(255,255,255,.04);',
    '  backdrop-filter: blur(10px);',
    '}',
    '.cv2-mapPanelTopRow{',
    '  display:flex;',
    '  align-items:flex-start;',
    '  justify-content:space-between;',
    '  gap: 12px;',
    '  flex-wrap: wrap;',
    '}',
    '.cv2-mapPanelTopTitle{',
    '  min-width: 260px;',
    '  flex: 1 1 340px;',
    '}',
    '.cv2-mapPanelTopActions{',
    '  display:flex;',
    '  gap: 8px;',
    '  flex-wrap: wrap;',
    '  align-items:center;',
    '  justify-content:flex-end;',
    '}',
    '.cv2-pill{',
    '  display:inline-flex;',
    '  align-items:center;',
    '  gap:6px;',
    '  padding: 8px 10px;',
    '  border-radius: 999px;',
    '  border: 1px solid rgba(255,255,255,.12);',
    '  background: rgba(0,0,0,.18);',
    '  text-decoration:none;',
    '  font-size: 12px;',
    '  line-height: 1;',
    '}',
    '.cv2-pill:hover{',
    '  background: rgba(255,255,255,.06);',
    '}',
    ''
  ) -join $nl

  WriteText $cssAbs ($cssRaw.TrimEnd() + $cssBlock + $nl)
  $r.Add('- appended CSS block to globals.css') | Out-Null
}
$r.Add('') | Out-Null

# VERIFY
$r.Add('## VERIFY') | Out-Null
$r.Add('') | Out-Null

$failed = $false
try { RunNpm @('run','lint'); $r.Add('- npm run lint: OK') | Out-Null } catch { $failed = $true; $r.Add('- npm run lint: FAIL') | Out-Null; $r.Add('  ' + $_.Exception.Message) | Out-Null }
try { RunNpm @('run','build'); $r.Add('- npm run build: OK') | Out-Null } catch { $failed = $true; $r.Add('- npm run build: FAIL') | Out-Null; $r.Add('  ' + $_.Exception.Message) | Out-Null }

$r.Add('') | Out-Null
$r.Add('## Git status (post)') | Out-Null
$r.Add('') | Out-Null
try { $r.Add((git status | Out-String).TrimEnd()) | Out-Null } catch { $r.Add('ERR: git status') | Out-Null }
$r.Add('') | Out-Null

WriteText $rep ([string]::Join($nl, $r.ToArray()) + $nl)
Write-Host ('[REPORT] ' + $rep)

if ($failed) { throw 'B7M: verify failed (see report).' }
Write-Host '[OK] B7M finalizado.'