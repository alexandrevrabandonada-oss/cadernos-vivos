# CV — Hotfix — Next 16.1 async params/searchParams + MapaV2 passa mapa pro Dock — v0_42
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

function FindRepoRoot([string]$start) {
  $cur = Resolve-Path $start
  while ($true) {
    if (Test-Path -LiteralPath (Join-Path $cur "package.json")) { return $cur.Path }
    $parent = Split-Path -Parent $cur.Path
    if (-not $parent -or $parent -eq $cur.Path) { break }
    $cur = Resolve-Path $parent
  }
  throw "[STOP] nao achei package.json (repo root). Rode a partir do repo."
}

$repo = FindRepoRoot (Get-Location).Path
$toolsDir = Join-Path $repo "tools"
. (Join-Path $toolsDir "_bootstrap.ps1")

Write-Host ("[DIAG] Repo: " + $repo)

function PatchFile([string]$p, [scriptblock]$fn) {
  if (-not (Test-Path -LiteralPath $p)) { Write-Host ("[SKIP] missing: " + $p); return $false }
  $raw = Get-Content -LiteralPath $p -Raw
  if (-not $raw) { throw ("[STOP] arquivo vazio/ilegivel: " + $p) }
  $next = & $fn $raw
  if ($null -eq $next) { Write-Host ("[SKIP] no-op: " + $p); return $false }
  if ($next -eq $raw) { Write-Host ("[OK] no change: " + $p); return $false }
  $bk = BackupFile $p
  WriteUtf8NoBom $p $next
  Write-Host ("[OK] patched: " + $p)
  if ($bk) { Write-Host ("[BK] " + $bk) }
  return $true
}

# ------------------------------------------------------------
# 1) Next 16.1+ — params/searchParams viram Promise (em rotas dinamicas)
#    Regra: em pages/layouts ASYNC, trocar acessos diretos por await.
# ------------------------------------------------------------
$appRoot = Join-Path $repo "src\app\c\[slug]"
if (-not (Test-Path -LiteralPath $appRoot)) { throw ("[STOP] nao achei: " + $appRoot) }

$targets = Get-ChildItem -LiteralPath $appRoot -Recurse -File |
  Where-Object { $_.Name -in @("page.tsx","layout.tsx") }

Write-Host ("[DIAG] targets: " + $targets.Count)

$changed = New-Object System.Collections.Generic.List[string]
$skipped = New-Object System.Collections.Generic.List[string]

foreach ($f in $targets) {
  $raw = Get-Content -LiteralPath $f.FullName -Raw
  if (-not $raw) { continue }

  # so mexe em componentes async (para nao forcar React.use em componentes sync)
  $isAsync = ($raw -match 'export\s+default\s+async\s+function') -or ($raw -match 'async\s+function\s+Page') -or ($raw -match 'export\s+default\s+async\s+function\s+Page')
  if (-not $isAsync) {
    $skipped.Add($f.FullName) | Out-Null
    continue
  }

  $did = $false
  $lines = $raw -split "`r?`n"
  $out = New-Object System.Collections.Generic.List[string]

  foreach ($ln in $lines) {
    $n = $ln

    # props.params.<x> -> (await props.params).<x>
    if ($n -match '\bprops\.params\.' -and ($n -notmatch '\(await\s+props\.params\)\.')) {
      $n = [regex]::Replace($n, '\bprops\.params\.', '(await props.params).')
      $did = $true
    }
    # destructuring: = props.params;
    if ($n -match '=\s*props\.params;' -and ($n -notmatch 'await\s+props\.params')) {
      $n = [regex]::Replace($n, '=\s*props\.params;', '= await props.params;')
      $did = $true
    }

    # props.searchParams.<x> -> (await props.searchParams).<x>
    if ($n -match '\bprops\.searchParams\.' -and ($n -notmatch '\(await\s+props\.searchParams\)\.')) {
      $n = [regex]::Replace($n, '\bprops\.searchParams\.', '(await props.searchParams).')
      $did = $true
    }
    # destructuring: = props.searchParams;
    if ($n -match '=\s*props\.searchParams;' -and ($n -notmatch 'await\s+props\.searchParams')) {
      $n = [regex]::Replace($n, '=\s*props\.searchParams;', '= await props.searchParams;')
      $did = $true
    }

    # params.<x> -> (await params).<x> (somente se houver a palavra params. na linha)
    if ($n -match '\bparams\.' -and ($n -notmatch '\(await\s+params\)\.')) {
      $n = [regex]::Replace($n, '\bparams\.', '(await params).')
      $did = $true
    }
    # destructuring: = params;
    if ($n -match '=\s*params;' -and ($n -notmatch 'await\s+params')) {
      $n = [regex]::Replace($n, '=\s*params;', '= await params;')
      $did = $true
    }

    # searchParams.<x> -> (await searchParams).<x>
    if ($n -match '\bsearchParams\.' -and ($n -notmatch '\(await\s+searchParams\)\.')) {
      $n = [regex]::Replace($n, '\bsearchParams\.', '(await searchParams).')
      $did = $true
    }
    # destructuring: = searchParams;
    if ($n -match '=\s*searchParams;' -and ($n -notmatch 'await\s+searchParams')) {
      $n = [regex]::Replace($n, '=\s*searchParams;', '= await searchParams;')
      $did = $true
    }

    $out.Add($n) | Out-Null
  }

  if ($did) {
    $bk = BackupFile $f.FullName
    WriteUtf8NoBom $f.FullName ($out -join "`n")
    $changed.Add($f.FullName) | Out-Null
    Write-Host ("[OK] patched: " + $f.FullName)
    if ($bk) { Write-Host ("[BK] " + $bk) }
  } else {
    Write-Host ("[OK] no change: " + $f.FullName)
  }
}

# ------------------------------------------------------------
# 2) Fix build: MapaV2 precisa passar mapa para MapaDockV2
# ------------------------------------------------------------
$mapaV2 = Join-Path $repo "src\components\v2\MapaV2.tsx"
PatchFile $mapaV2 {
  param($raw)
  $o = $raw

  # troca <MapaDockV2 slug={slug} /> por <MapaDockV2 slug={slug} mapa={mapa} />
  if ($o -match '<MapaDockV2\s+slug=\{slug\}\s*/>') {
    $o = [regex]::Replace($o, '<MapaDockV2\s+slug=\{slug\}\s*/>', '<MapaDockV2 slug={slug} mapa={mapa} />')
  }

  return $o
} | Out-Null

# ------------------------------------------------------------
# VERIFY
# ------------------------------------------------------------
RunPs1 (Join-Path $repo "tools\cv-verify.ps1")

# ------------------------------------------------------------
# REPORT (sem backticks para nao cair no parser)
# ------------------------------------------------------------
$rep = @()
$rep += '# CV — Hotfix v0_42 — Next 16.1 async params/searchParams + MapaV2 props'
$rep += ''
$rep += '## Causa'
$rep += '- Next 16.1+ em rotas dinamicas entrega params/searchParams como Promise; acesso direto em Server Components async quebra em dev.'
$rep += '- MapaV2 chamava MapaDockV2 sem o prop mapa (build TypeScript falhava).'
$rep += ''
$rep += '## Fix'
$rep += '- Em pages/layouts async de src/app/c/[slug]: props.params.x e params.x agora usam await.'
$rep += '- MapaV2: MapaDockV2 recebe mapa={mapa}.'
$rep += ''
$rep += '## Arquivos alterados (auto)'
if ($changed.Count -eq 0) { $rep += '- (nenhum page/layout precisou mudar)' } else { foreach ($p in $changed) { $rep += ('- ' + $p) } }
$rep += ''
$rep += '## Arquivos pulados (nao-async)'
if ($skipped.Count -eq 0) { $rep += '- (nenhum)' } else { foreach ($p in $skipped) { $rep += ('- ' + $p) } }
$rep += ''
$rep += '## Verify'
$rep += '- tools/cv-verify.ps1 (guard + lint + build)'
$rep += ''

WriteReport "cv-hotfix-next16-asyncparams-mapa-props-v0_42.md" ($rep -join "`n") | Out-Null
Write-Host "[OK] v0_42 aplicado e verificado."