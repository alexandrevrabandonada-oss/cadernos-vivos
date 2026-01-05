# CV — Hotfix Next 16.1 — params/searchParams são Promise em rotas dinâmicas — v0_32c
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

# acha repo + bootstrap mesmo se alguém tentar rodar fora do /tools
$cwd = (Get-Location).Path
$bootstrap = Join-Path $cwd "tools\_bootstrap.ps1"
if (Test-Path -LiteralPath $bootstrap) {
  . $bootstrap
} else {
  $bootstrap2 = Join-Path $cwd "_bootstrap.ps1"
  if (Test-Path -LiteralPath $bootstrap2) {
    . $bootstrap2
  } else {
    throw "[STOP] Não achei tools/_bootstrap.ps1. Rode a partir da raiz do repo."
  }
}

# repo root (pai da pasta tools)
$toolsDir = Split-Path -Parent $bootstrap
$repo = (Resolve-Path (Join-Path $toolsDir "..")).Path
Write-Host ("[DIAG] Repo: " + $repo)

$root = Join-Path $repo 'src\app\c\[slug]'
if (-not (Test-Path -LiteralPath $root)) { throw ("[STOP] não achei pasta: " + $root) }

# pega page.tsx e layout.tsx (ambos podem usar params)
$targets = @()
$targets += Get-ChildItem -LiteralPath $root -Recurse -File -Filter 'page.tsx'
$targets += Get-ChildItem -LiteralPath $root -Recurse -File -Filter 'layout.tsx'

Write-Host ("[DIAG] arquivos alvo: " + $targets.Count)

$changedFiles = New-Object System.Collections.Generic.List[string]
$skippedFiles = New-Object System.Collections.Generic.List[string]

foreach ($f in $targets) {
  $raw = Get-Content -LiteralPath $f.FullName -Raw

  # só mexe em arquivos async (server component async)
  $isAsync = $raw.Contains("async function") -or $raw.Contains("export default async function")
  if (-not $isAsync) {
    $skippedFiles.Add($f.FullName) | Out-Null
    continue
  }

  $lines = $raw -split "`r?`n"
  $out = New-Object System.Collections.Generic.List[string]
  $changed = $false

  foreach ($ln in $lines) {
    $n = $ln

    # props.params.slug -> (await props.params).slug
    if ($n.Contains("props.params.") -and (-not $n.Contains("(await props.params)."))) {
      $n = $n -replace 'props\.params\.', '(await props.params).'
      $changed = $true
    }

    # const { slug } = props.params; -> await props.params
    if ($n.Contains("= props.params;") -and (-not $n.Contains("await props.params"))) {
      $n = $n.Replace("= props.params;", "= await props.params;")
      $changed = $true
    }

    # props.searchParams.q -> (await props.searchParams).q
    if ($n.Contains("props.searchParams.") -and (-not $n.Contains("(await props.searchParams)."))) {
      $n = $n -replace 'props\.searchParams\.', '(await props.searchParams).'
      $changed = $true
    }

    # const { q } = props.searchParams; -> await props.searchParams
    if ($n.Contains("= props.searchParams;") -and (-not $n.Contains("await props.searchParams"))) {
      $n = $n.Replace("= props.searchParams;", "= await props.searchParams;")
      $changed = $true
    }

    # params.slug -> (await params).slug  (quando existe variável params)
    if ($n.Contains("params.") -and (-not $n.Contains("(await params).")) -and (-not $n.Contains("searchParams"))) {
      $n = $n -replace 'params\.', '(await params).'
      $changed = $true
    }

    # const { slug } = params; -> await params
    if ($n.Contains("= params;") -and (-not $n.Contains("await params"))) {
      $n = $n.Replace("= params;", "= await params;")
      $changed = $true
    }

    # searchParams.q -> (await searchParams).q
    if ($n.Contains("searchParams.") -and (-not $n.Contains("(await searchParams).")) -and (-not $n.Contains("props.searchParams"))) {
      $n = $n -replace 'searchParams\.', '(await searchParams).'
      $changed = $true
    }

    # const { q } = searchParams; -> await searchParams
    if ($n.Contains("= searchParams;") -and (-not $n.Contains("await searchParams")) -and (-not $n.Contains("props.searchParams"))) {
      $n = $n.Replace("= searchParams;", "= await searchParams;")
      $changed = $true
    }

    $out.Add($n) | Out-Null
  }

  if ($changed) {
    $bk = BackupFile $f.FullName
    WriteUtf8NoBom $f.FullName ($out -join "`n")
    $changedFiles.Add($f.FullName) | Out-Null
    Write-Host ("[OK] patched: " + $f.FullName)
    if ($bk) { Write-Host ("[BK] " + $bk) }
  }
}

# VERIFY
RunPs1 (Join-Path $repo "tools\cv-verify.ps1")

# REPORT (sem backticks para não quebrar parser)
$report = @()
$report += "# CV — Hotfix v0_32c — Next 16.1 async params/searchParams"
$report += ""
$report += "## Causa"
$report += "- Next 16.1+ trata params/searchParams como Promise em rotas dinâmicas no dev."
$report += ""
$report += "## Fix"
$report += "- Em pages/layout async: props.params.* e params.* agora usam await."
$report += "- Em pages/layout async: props.searchParams.* e searchParams.* agora usam await."
$report += ""
$report += "## Arquivos alterados"
if ($changedFiles.Count -eq 0) { $report += "- (nenhum — ja estavam no padrao)" } else { foreach ($p in $changedFiles) { $report += ("- " + $p) } }
$report += ""
$report += "## Arquivos pulados (nao-async)"
if ($skippedFiles.Count -eq 0) { $report += "- (nenhum)" } else { foreach ($p in $skippedFiles) { $report += ("- " + $p) } }
$report += ""
$report += "## Verify"
$report += "- tools/cv-verify.ps1 (guard + lint + build)"
$report += ""

WriteReport "cv-hotfix-next16-async-params-v0_32c.md" ($report -join "`n") | Out-Null
Write-Host "[OK] v0_32c aplicado e verificado."