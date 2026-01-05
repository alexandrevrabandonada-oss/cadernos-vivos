$ErrorActionPreference = "Stop"

# repo = pasta pai de /tools
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Write-Host ("[DIAG] Repo: " + $repo)

# tenta carregar bootstrap (se existir)
$bootstrap = Join-Path $PSScriptRoot "_bootstrap.ps1"
if (Test-Path -LiteralPath $bootstrap) {
  . $bootstrap
  Write-Host ("[DIAG] Bootstrap: " + $bootstrap)
} else {
  Write-Host "[WARN] tools/_bootstrap.ps1 não encontrado — usando fallbacks."
}

# -------- fallbacks (caso bootstrap não tenha carregado) --------
if (-not (Get-Command EnsureDir -ErrorAction SilentlyContinue)) {
  function EnsureDir([string]$p) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}
if (-not (Get-Command WriteUtf8NoBom -ErrorAction SilentlyContinue)) {
  function WriteUtf8NoBom([string]$p, [string]$t) {
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($p, $t, $enc)
  }
}
if (-not (Get-Command BackupFile -ErrorAction SilentlyContinue)) {
  function BackupFile([string]$p) {
    if (-not (Test-Path -LiteralPath $p)) { return $null }
    $bkDir = Join-Path $repo "tools\_patch_backup"
    EnsureDir $bkDir
    $ts = Get-Date -Format "yyyyMMdd-HHmmss"
    $leaf = Split-Path -Leaf $p
    $bk = Join-Path $bkDir ($ts + "-" + $leaf + ".bak")
    Copy-Item -LiteralPath $p -Destination $bk -Force
    return $bk
  }
}
if (-not (Get-Command RunPs1 -ErrorAction SilentlyContinue)) {
  function RunPs1([string]$p) {
    & $PSHOME\pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $p
    if ($LASTEXITCODE -ne 0) { throw ("[STOP] RunPs1 falhou (exit " + $LASTEXITCODE + "): " + $p) }
  }
}

$changed = New-Object System.Collections.Generic.List[string]
$skipped = New-Object System.Collections.Generic.List[string]

function PatchAsyncParamsFile([string]$filePath) {
  $raw = Get-Content -LiteralPath $filePath -Raw

  $isAsync =
    ($raw -match "export\s+default\s+async\s+function") -or
    ($raw -match "async\s+function\s+Page") -or
    ($raw -match "export\s+default\s+async\s+function\s+Page")

  if (-not $isAsync) { return $false }

  $lines = $raw -split "`r?`n"
  $out = New-Object System.Collections.Generic.List[string]
  $did = $false

  foreach ($ln in $lines) {
    $n = $ln

    # props.params.X -> (await props.params).X  (somente se não tiver await já)
    if ($n.Contains("props.params.") -and (-not $n.Contains("await props.params"))) {
      $n = $n.Replace("props.params.", "(await props.params).")
      $did = $true
    }

    # destructuring: = props.params; -> = await props.params;
    if ($n.Contains("= props.params;") -and (-not $n.Contains("await props.params"))) {
      $n = $n.Replace("= props.params;", "= await props.params;")
      $did = $true
    }

    # props.searchParams.X -> (await props.searchParams).X
    if ($n.Contains("props.searchParams.") -and (-not $n.Contains("await props.searchParams"))) {
      $n = $n.Replace("props.searchParams.", "(await props.searchParams).")
      $did = $true
    }

    # destructuring: = props.searchParams; -> = await props.searchParams;
    if ($n.Contains("= props.searchParams;") -and (-not $n.Contains("await props.searchParams"))) {
      $n = $n.Replace("= props.searchParams;", "= await props.searchParams;")
      $did = $true
    }

    # params.X -> (await params).X  (evita mexer em searchParams)
    if ($n.Contains("params.") -and (-not $n.Contains("(await params).")) -and (-not $n.Contains("searchParams"))) {
      $n = $n.Replace("params.", "(await params).")
      $did = $true
    }

    # destructuring: = params; -> = await params;
    if ($n.Contains("= params;") -and (-not $n.Contains("await params"))) {
      $n = $n.Replace("= params;", "= await params;")
      $did = $true
    }

    # searchParams.X -> (await searchParams).X
    if ($n.Contains("searchParams.") -and (-not $n.Contains("(await searchParams).")) -and (-not $n.Contains("props.searchParams"))) {
      $n = $n.Replace("searchParams.", "(await searchParams).")
      $did = $true
    }

    # destructuring: = searchParams; -> = await searchParams;
    if ($n.Contains("= searchParams;") -and (-not $n.Contains("await searchParams")) -and (-not $n.Contains("props.searchParams"))) {
      $n = $n.Replace("= searchParams;", "= await searchParams;")
      $did = $true
    }

    $out.Add($n) | Out-Null
  }

  if ($did) {
    $bk = BackupFile $filePath
    WriteUtf8NoBom $filePath ($out -join "`n")
    Write-Host ("[OK] patched async params: " + $filePath)
    if ($bk) { Write-Host ("[BK] " + $bk) }
    return $true
  }

  return $false
}

# -----------------------
# A) Next 16.1: async params/searchParams em /c/[slug] (page.tsx + layout.tsx)
# -----------------------
$root = Join-Path $repo "src\app\c\[slug]"
if (Test-Path -LiteralPath $root) {
  $targets = Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object { $_.Name -in @("page.tsx","layout.tsx") }
  Write-Host ("[DIAG] targets: " + $targets.Count)

  foreach ($f in $targets) {
    $did = PatchAsyncParamsFile $f.FullName
    if ($did) { $changed.Add($f.FullName) | Out-Null }
    else { $skipped.Add($f.FullName) | Out-Null }
  }
} else {
  Write-Host ("[WARN] não achei: " + $root)
}

# -----------------------
# B) V2Nav: remove param i não usado + melhora key (evita warning em dev)
# -----------------------
$navPath = Join-Path $repo "src\components\v2\V2Nav.tsx"
if (Test-Path -LiteralPath $navPath) {
  $raw = Get-Content -LiteralPath $navPath -Raw
  $out = $raw
  $did = $false

  # .map((it, i) =>  -> .map((it) =>
  if ($out -match "\.map\(\(\s*it\s*,\s*i\s*\)\s*=>") {
    $out = [regex]::Replace($out, "\.map\(\(\s*it\s*,\s*i\s*\)\s*=>", ".map((it) =>")
    $did = $true
  }

  # key={it.key} -> key={it.key + ":" + it.href}  (reduz chance de key duplicada)
  if ($out -match "key=\{it\.key\}") {
    $out = $out.Replace("key={it.key}", "key={it.key + " + '":"' + " + it.href}")
    $did = $true
  }

  if ($did -and ($out -ne $raw)) {
    $bk = BackupFile $navPath
    WriteUtf8NoBom $navPath $out
    Write-Host ("[OK] patched: " + $navPath)
    if ($bk) { Write-Host ("[BK] " + $bk) }
    $changed.Add($navPath) | Out-Null
  } else {
    Write-Host "[OK] V2Nav: nada pra mudar (ou já está ok)."
  }
} else {
  Write-Host ("[WARN] V2Nav não encontrado: " + $navPath)
}

# -----------------------
# C) MapaCanvasV2: troca window.location.hash = id (lint) por history.replaceState + evento
# -----------------------
$canvasPath = Join-Path $repo "src\components\v2\MapaCanvasV2.tsx"
if (Test-Path -LiteralPath $canvasPath) {
  $raw = Get-Content -LiteralPath $canvasPath -Raw
  $out = $raw

  if ($out.Contains("window.location.hash = id;")) {
    $rep = @(
      'window.history.replaceState(null, "", "#" + id);',
      '      window.dispatchEvent(new Event("hashchange"));'
    ) -join "`n"
    $out = $out.Replace("window.location.hash = id;", $rep)

    $bk = BackupFile $canvasPath
    WriteUtf8NoBom $canvasPath $out
    Write-Host ("[OK] patched: " + $canvasPath + " (hash -> history.replaceState)")
    if ($bk) { Write-Host ("[BK] " + $bk) }
    $changed.Add($canvasPath) | Out-Null
  } else {
    Write-Host "[OK] MapaCanvasV2: não achei window.location.hash = id (talvez já corrigido)."
  }
} else {
  Write-Host ("[WARN] MapaCanvasV2 não encontrado: " + $canvasPath)
}

# -----------------------
# D) MapaDockV2: deixa mapa opcional + MapaV2 passa mapa (se estiver faltando)
# -----------------------
$dockPath = Join-Path $repo "src\components\v2\MapaDockV2.tsx"
if (Test-Path -LiteralPath $dockPath) {
  $raw = Get-Content -LiteralPath $dockPath -Raw
  $out = $raw
  $did = $false

  if ($out -match "mapa:\s*unknown") {
    $out = [regex]::Replace($out, "mapa:\s*unknown", "mapa?: unknown")
    $did = $true
  }

  if ($did -and ($out -ne $raw)) {
    $bk = BackupFile $dockPath
    WriteUtf8NoBom $dockPath $out
    Write-Host ("[OK] patched: " + $dockPath + " (mapa opcional)")
    if ($bk) { Write-Host ("[BK] " + $bk) }
    $changed.Add($dockPath) | Out-Null
  } else {
    Write-Host "[OK] MapaDockV2: nada pra mudar (ou já está opcional)."
  }
} else {
  Write-Host ("[WARN] MapaDockV2 não encontrado: " + $dockPath)
}

$mapaV2Path = Join-Path $repo "src\components\v2\MapaV2.tsx"
if (Test-Path -LiteralPath $mapaV2Path) {
  $raw = Get-Content -LiteralPath $mapaV2Path -Raw
  $out = $raw

  # Só tenta passar mapa se encontrar o uso "MapaDockV2 slug={slug}" e existir "const mapa" no arquivo
  if ($out.Contains("<MapaDockV2 slug={slug}") -and ($out -match "const\s+mapa\s*=") -and ($out -notmatch "MapaDockV2\s+slug=\{slug\}\s+mapa=\{mapa\}")) {
    $out = $out.Replace("<MapaDockV2 slug={slug} />", "<MapaDockV2 slug={slug} mapa={mapa} />")
    $out = $out.Replace("<MapaDockV2 slug={slug}/>", "<MapaDockV2 slug={slug} mapa={mapa} />")

    if ($out -ne $raw) {
      $bk = BackupFile $mapaV2Path
      WriteUtf8NoBom $mapaV2Path $out
      Write-Host ("[OK] patched: " + $mapaV2Path + " (passa mapa no dock)")
      if ($bk) { Write-Host ("[BK] " + $bk) }
      $changed.Add($mapaV2Path) | Out-Null
    } else {
      Write-Host "[OK] MapaV2: nada pra mudar."
    }
  } else {
    Write-Host "[OK] MapaV2: já passa mapa, ou não encontrei const mapa, ou padrão diferente."
  }
} else {
  Write-Host ("[WARN] MapaV2 não encontrado: " + $mapaV2Path)
}

# -----------------------
# VERIFY
# -----------------------
$verify = Join-Path $repo "tools\cv-verify.ps1"
if (Test-Path -LiteralPath $verify) {
  Write-Host ("[RUN] " + $verify)
  RunPs1 $verify
} else {
  Write-Host ("[WARN] verify não encontrado: " + $verify)
}

# -----------------------
# REPORT
# -----------------------
$reportsDir = Join-Path $repo "reports"
EnsureDir $reportsDir
$reportPath = Join-Path $reportsDir "cv-hotfix-pack-next16-nav-mapa-v0_36.md"

$report = @()
$report += "# CV — Hotfix Pack v0_36"
$report += ""
$report += "## O que entrou"
$report += "- Next 16.1: em pages/layout async dentro de src/app/c/[slug], troca acessos diretos a params/searchParams por await."
$report += "- V2Nav: remove callback param i não usado e reforça key para reduzir warning em dev."
$report += "- MapaCanvasV2: troca window.location.hash = id por history.replaceState + evento hashchange (evita lint)."
$report += "- MapaDockV2: mapa opcional; MapaV2 tenta passar mapa para o dock se estiver faltando."
$report += ""
$report += "## Arquivos alterados"
if ($changed.Count -eq 0) { $report += "- (nenhum)" } else { foreach ($p in $changed) { $report += ("- " + $p) } }
$report += ""
$report += "## Arquivos inspecionados e pulados (não-async ou sem padrão)"
$report += ("- " + $skipped.Count + " arquivo(s)")
$report += ""
$report += "## Verify"
$report += "- tools/cv-verify.ps1 (guard + lint + build)"
$report += ""

WriteUtf8NoBom $reportPath ($report -join "`n")
Write-Host ("[OK] Report: " + $reportPath)
Write-Host "[OK] Hotfix pack v0_36 aplicado."