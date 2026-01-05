# CV — V2 Hotfix — MapaDockV2: evitar setState direto em useEffect + montar Dock no page — v0_34
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

$repo = Get-Location
$bootstrap = Join-Path $repo "tools\_bootstrap.ps1"
if (-not (Test-Path -LiteralPath $bootstrap)) { throw "[STOP] tools/_bootstrap.ps1 não encontrado." }
. $bootstrap

Write-Host ("[DIAG] Repo: " + $repo)

$dockFile = Join-Path $repo "src\components\v2\MapaDockV2.tsx"
if (-not (Test-Path -LiteralPath $dockFile)) { throw ("[STOP] Não achei: " + $dockFile) }

$mapaPage = Join-Path $repo "src\app\c\[slug]\v2\mapa\page.tsx"
if (-not (Test-Path -LiteralPath $mapaPage)) { throw ("[STOP] Não achei: " + $mapaPage) }

$mapaComp = Join-Path $repo "src\components\v2\MapaV2.tsx"
# (opcional) pode existir ou não

# --- PATCH 1: MapaDockV2.tsx ---
$raw = Get-Content -LiteralPath $dockFile -Raw
$raw2 = $raw

# 1a) init do selectedId por initializer (guard no window)
$from1 = 'const [selectedId, setSelectedId] = useState<string>("");'
$to1   = 'const [selectedId, setSelectedId] = useState<string>(() => (typeof window !== "undefined" ? readHashId() : ""));'
if ($raw2.Contains($from1)) {
  $raw2 = $raw2.Replace($from1, $to1)
} else {
  # fallback: se estiver sem <string>
  $from1b = 'const [selectedId, setSelectedId] = useState("");'
  $to1b   = 'const [selectedId, setSelectedId] = useState(() => (typeof window !== "undefined" ? readHashId() : ""));'
  if ($raw2.Contains($from1b)) { $raw2 = $raw2.Replace($from1b, $to1b) }
}

# 1b) remove setState síncrono no corpo do effect
$raw2 = $raw2.Replace("    setSelectedId(readHashId());`n", "")
$raw2 = $raw2.Replace("    setSelectedId(readHashId());`r`n", "")

# 1c) deixa dock fixo no desktop (não depende do parent ser position:relative)
$fromWrap = ': { position: "absolute", right: 16, top: 16, width: 360, zIndex: 30 };'
$toWrap   = ': { position: "fixed", right: 16, top: 16, width: 360, zIndex: 30 };'
if ($raw2.Contains($fromWrap)) { $raw2 = $raw2.Replace($fromWrap, $toWrap) }

if ($raw2 -ne $raw) {
  $bk1 = BackupFile $dockFile
  WriteUtf8NoBom $dockFile $raw2
  Write-Host ("[OK] patched: " + $dockFile)
  if ($bk1) { Write-Host ("[BK] " + $bk1) }
} else {
  Write-Host ("[OK] no change: " + $dockFile)
}

# --- PATCH 2: montar Dock no src/app/.../v2/mapa/page.tsx ---
$rawP = Get-Content -LiteralPath $mapaPage -Raw
$lines = $rawP -split "\r?\n"
$out = New-Object System.Collections.Generic.List[string]
$changedPage = $false

$hasImport = $rawP.Contains("MapaDockV2")
$hasJSX    = $rawP.Contains("<MapaDockV2")

foreach ($ln in $lines) {
  # injeta import logo após import MapaV2 (se ainda não existir)
  $out.Add($ln)

  if (-not $hasImport -and $ln -match "import\s+MapaV2\s+from\s+") {
    $out.Add('import MapaDockV2 from "@/components/v2/MapaDockV2";')
    $changedPage = $true
    $hasImport = $true
  }
}

# injeta JSX depois do <MapaV2 .../> (se ainda não existir)
if (-not $hasJSX) {
  $out2 = New-Object System.Collections.Generic.List[string]
  $inMapa = $false
  foreach ($ln in $out) {
    $out2.Add($ln)
    if (-not $inMapa -and $ln.Contains("<MapaV2")) {
      $inMapa = $true
    }

    if ($inMapa -and $ln.Contains("/>")) {
      # indent: copia espaços do começo desta linha
      $indent = ""
      if ($ln -match "^(\s*)") { $indent = $Matches[1] }
      $out2.Add($indent + '<MapaDockV2 slug={slug} mapa={mapa} />')
      $changedPage = $true
      $inMapa = $false
    }
  }
  $out = $out2
}

if ($changedPage) {
  $bk2 = BackupFile $mapaPage
  WriteUtf8NoBom $mapaPage ($out -join "`n")
  Write-Host ("[OK] patched: " + $mapaPage)
  if ($bk2) { Write-Host ("[BK] " + $bk2) }
} else {
  Write-Host ("[OK] no change: " + $mapaPage)
}

# --- PATCH 3 (opcional): remover import MapaDockV2 sobrando em MapaV2.tsx ---
if (Test-Path -LiteralPath $mapaComp) {
  $rawM = Get-Content -LiteralPath $mapaComp -Raw
  if ($rawM.Contains("import MapaDockV2") -and (-not $rawM.Contains("<MapaDockV2"))) {
    $mlines = $rawM -split "\r?\n"
    $mout = New-Object System.Collections.Generic.List[string]
    $removed = $false
    foreach ($ln in $mlines) {
      if (-not $removed -and $ln -match "^\s*import\s+MapaDockV2\s+from\s+") {
        $removed = $true
        continue
      }
      $mout.Add($ln)
    }
    if ($removed) {
      $bk3 = BackupFile $mapaComp
      WriteUtf8NoBom $mapaComp ($mout -join "`n")
      Write-Host ("[OK] patched: " + $mapaComp + " (removeu import MapaDockV2 não usado)")
      if ($bk3) { Write-Host ("[BK] " + $bk3) }
    } else {
      Write-Host ("[OK] no change: " + $mapaComp)
    }
  } else {
    Write-Host ("[OK] no change: " + $mapaComp)
  }
} else {
  Write-Host ("[OK] skip: não achei " + $mapaComp)
}

# VERIFY
RunPs1 (Join-Path $repo "tools\cv-verify.ps1") @()

# REPORT
$report = @(
  "# CV — Hotfix v0_34 — Dock sem setState síncrono em useEffect",
  "",
  "## Causa",
  "- ESLint (react-hooks/set-state-in-effect) bloqueia setState chamado diretamente no corpo de um useEffect.",
  "",
  "## Fix",
  "- MapaDockV2: selectedId inicial agora vem de initializer (guard em window).",
  "- MapaDockV2: removeu setSelectedId(readHashId()) do corpo do effect; mantém hashchange + cv:nodeSelect.",
  "- MapaDockV2: dock no desktop virou position:fixed (não depende do layout pai).",
  "- v2/mapa/page.tsx: monta <MapaDockV2 .../> para garantir que o inspector aparece.",
  "- (opcional) MapaV2.tsx: remove import MapaDockV2 se estava sobrando.",
  "",
  "## Verify",
  "- tools/cv-verify.ps1 (Guard → Lint → Build)",
  ""
) -join "`n"

WriteReport "cv-v2-hotfix-dock-setstate-in-effect-v0_34.md" $report | Out-Null
Write-Host "[OK] v0_34 aplicado e verificado."