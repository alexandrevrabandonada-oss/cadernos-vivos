# cv-step-b7d-mapfirst-nucleus-top-v0_1
$ErrorActionPreference = "Stop"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$repoRoot = (Resolve-Path ".").Path

function EnsureDir([string]$abs) { if (-not (Test-Path -LiteralPath $abs)) { [IO.Directory]::CreateDirectory($abs) | Out-Null } }
function ReadText([string]$abs) { if (-not (Test-Path -LiteralPath $abs)) { return $null }; return [IO.File]::ReadAllText($abs) }
function WriteText([string]$abs, [string]$text) { $enc = New-Object System.Text.UTF8Encoding($false); EnsureDir (Split-Path -Parent $abs); [IO.File]::WriteAllText($abs, $text, $enc) }
function BackupFile([string]$rel) {
  $abs = Join-Path $repoRoot $rel
  if (-not (Test-Path -LiteralPath $abs)) { return }
  $bkDir = Join-Path $repoRoot "tools\_patch_backup"
  EnsureDir $bkDir
  $dst = Join-Path $bkDir ($stamp + "-" + (Split-Path -Leaf $abs))
  Copy-Item -LiteralPath $abs -Destination $dst -Force
}
function TryRun([string]$label, [scriptblock]$sb) {
  try { $out = & $sb 2>&1 | Out-String; return @("## " + $label, "", $out.TrimEnd(), "") }
  catch { return @("## " + $label, "", ("[ERR] " + $_.Exception.Message), "") }
}
function AddLines([System.Collections.Generic.List[string]]$list, [object]$block) { if ($null -eq $block) { return }; foreach ($x in @($block)) { $list.Add([string]$x) | Out-Null } }

EnsureDir (Join-Path $repoRoot "reports")
EnsureDir (Join-Path $repoRoot "tools\_patch_backup")

$rep = Join-Path $repoRoot ("reports\" + $stamp + "-cv-step-b7d-mapfirst-nucleus-top.md")
$r = New-Object System.Collections.Generic.List[string]
$r.Add("# Tijolo B7D — Map-first + núcleo no topo do mapa — " + $stamp) | Out-Null
$r.Add("") | Out-Null
$r.Add("Repo: " + $repoRoot) | Out-Null
$r.Add("") | Out-Null
AddLines $r (TryRun "Git status (pre)" { git status })

# -------------------------
# PATCH A) remover .eslintignore (Eslint v9 avisa)
# -------------------------
$eiAbs = Join-Path $repoRoot ".eslintignore"
if (Test-Path -LiteralPath $eiAbs) {
  Remove-Item -LiteralPath $eiAbs -Force
  $r.Add("## Patch A") | Out-Null
  $r.Add("- removido: .eslintignore (warning do eslint v9)") | Out-Null
  $r.Add("") | Out-Null
} else {
  $r.Add("## Patch A") | Out-Null
  $r.Add("- .eslintignore não existe (ok)") | Out-Null
  $r.Add("") | Out-Null
}

# -------------------------
# PATCH B) .gitignore: ignorar tools/_patch_backup/
# -------------------------
$giRel = ".gitignore"
$giAbs = Join-Path $repoRoot $giRel
$gi = ReadText $giAbs
if ($null -eq $gi) { throw "Missing .gitignore" }
BackupFile $giRel

if ($gi -notmatch 'tools/_patch_backup') {
  $gi = ($gi.TrimEnd() + "`n`n# local patch backups`ntools/_patch_backup/`n")
  WriteText $giAbs $gi
  $r.Add("## Patch B") | Out-Null
  $r.Add("- .gitignore: adiciona tools/_patch_backup/") | Out-Null
  $r.Add("") | Out-Null
} else {
  $r.Add("## Patch B") | Out-Null
  $r.Add("- .gitignore: já contém tools/_patch_backup (ok)") | Out-Null
  $r.Add("") | Out-Null
}

# -------------------------
# PATCH C) normalize.ts: fallback coreNodes padrão (5 portas)
# -------------------------
$normRel = "src\lib\v2\normalize.ts"
$normAbs = Join-Path $repoRoot $normRel
$normRaw = ReadText $normAbs
if ($null -eq $normRaw) { throw ("Missing file: " + $normRel) }
BackupFile $normRel

# tenta substituir "const coreNodes = normalizeCoreNodesV2(extractCoreNodesRaw(o))" por fallback
$did = $false
$normRaw2 = $normRaw

$normRaw2b = [Regex]::Replace(
  $normRaw2,
  'const\s+coreNodes\s*=\s*normalizeCoreNodesV2\(\s*extractCoreNodesRaw\(o\)\s*\)\s*;',
  'const coreNodes = normalizeCoreNodesV2(extractCoreNodesRaw(o)) ?? ["mapa","linha","provas","trilhas","debate"];',
  1
)
if ($normRaw2b -ne $normRaw2) { $normRaw2 = $normRaw2b; $did = $true }

if (-not $did) {
  # fallback: depois da criação do meta, garante default se vier undefined
  if ($normRaw2 -notmatch 'meta\.coreNodes\s*=\s*meta\.coreNodes\s*\?\?') {
    $normRaw2 = [Regex]::Replace(
      $normRaw2,
      '(meta\.coreNodes\s*=\s*normalizeCoreNodesV2\(extractCoreNodesRaw\(o\)\);\s*)',
      ('$1' + "`n" + 'meta.coreNodes = meta.coreNodes ?? ["mapa","linha","provas","trilhas","debate"];'),
      1
    )
    $did = $true
  }
}

if ($did) {
  WriteText $normAbs $normRaw2
  $r.Add("## Patch C") | Out-Null
  $r.Add("- normalize.ts: fallback coreNodes padrão (mapa→linha→provas→trilhas→debate)") | Out-Null
  $r.Add("") | Out-Null
} else {
  $r.Add("## Patch C") | Out-Null
  $r.Add("- normalize.ts: não consegui aplicar fallback (pattern não encontrado) — sem mudanças") | Out-Null
  $r.Add("") | Out-Null
}

# -------------------------
# PATCH D) mapa/page.tsx: núcleo no topo + remove duplicata antes do V2Portals
# -------------------------
function PickExpr([string]$raw) {
  $hasCaderno = ($raw -match '(?m)\b(const|let|var)\s+caderno\b')
  $hasData    = ($raw -match '(?m)\b(const|let|var)\s+data\b')
  $hasMetaVar = ($raw -match '(?m)\b(const|let|var)\s+meta\b') -or ($raw -match '(?m)\bconst\s*{\s*meta\b')
  if ($hasCaderno) { return "caderno.meta.coreNodes" }
  if ($hasData)    { return "data.meta.coreNodes" }
  if ($hasMetaVar) { return "meta.coreNodes" }
  $m = [Regex]::Match($raw, '(?m)\b(const|let|var)\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*await\s+loadCadernoV2\s*\(')
  if ($m.Success) { return ($m.Groups[2].Value + ".meta.coreNodes") }
  return "undefined"
}

$mapRel = "src\app\c\[slug]\v2\mapa\page.tsx"
$mapAbs = Join-Path $repoRoot $mapRel
$mapRaw = ReadText $mapAbs
if ($null -ne $mapRaw) {
  BackupFile $mapRel

  # remove a linha Cv2CoreNodes que esteja imediatamente antes do V2Portals (evita duplicar)
  $mapRaw2 = [Regex]::Replace(
    $mapRaw,
    '(?m)^\s*<Cv2CoreNodes\b[^>]*\/>\s*\r?\n(?=\s*<V2Portals\b)',
    ''
  )

  $expr = PickExpr $mapRaw2
  $top = '<Cv2CoreNodes slug={slug} title={"Núcleo do mapa"} coreNodes={' + $expr + '} />'

  # injeta acima do Cv2MapRail (melhor ponto “map-first”)
  if ($mapRaw2 -match '<Cv2MapRail\b' -and $mapRaw2 -notmatch 'title=\{"Núcleo do mapa"\}') {
    $mapRaw2 = [Regex]::Replace(
      $mapRaw2,
      '(\s*)(<Cv2MapRail\b)',
      ('$1' + $top + "`n" + '$1$2'),
      1
    )
  } elseif ($mapRaw2 -match '<main\b' -and $mapRaw2 -notmatch 'title=\{"Núcleo do mapa"\}') {
    # fallback: injeta logo após <main ...>
    $mapRaw2 = [Regex]::Replace(
      $mapRaw2,
      '(<main\b[^>]*>\s*)',
      ('$1' + "`n  " + $top + "`n"),
      1
    )
  }

  WriteText $mapAbs ($mapRaw2 + "`n")
  $r.Add("## Patch D") | Out-Null
  $r.Add("- mapa/page.tsx: núcleo sobe pro topo (perto do Rail) + remove duplicata antes do V2Portals") | Out-Null
  $r.Add("") | Out-Null
} else {
  $r.Add("## Patch D") | Out-Null
  $r.Add("- mapa/page.tsx não encontrado (warn)") | Out-Null
  $r.Add("") | Out-Null
}

# -------------------------
# VERIFY
# -------------------------
AddLines $r (TryRun "npm run lint" {
  $npm = (Get-Command npm.cmd -ErrorAction Stop).Path
  & $npm run lint
})
AddLines $r (TryRun "npm run build" {
  $npm = (Get-Command npm.cmd -ErrorAction Stop).Path
  & $npm run build
})
AddLines $r (TryRun "Git status (post)" { git status })

WriteText $rep (($r -join "`n") + "`n")
Write-Host ("[REPORT] " + $rep)
Write-Host "[OK] B7D finalizado."