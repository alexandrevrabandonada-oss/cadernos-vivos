# CV — Hotfix — Next 16.1 async params/searchParams em rotas V2 — v0_35
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

$repo = Get-Location
$bootstrap = Join-Path $repo "tools\_bootstrap.ps1"
if (Test-Path -LiteralPath $bootstrap) { . $bootstrap } else { throw "[STOP] tools/_bootstrap.ps1 não encontrado." }

Write-Host ("[DIAG] Repo: " + $repo)

$root = Join-Path $repo "src\app\c\[slug]\v2"
if (-not (Test-Path -LiteralPath $root)) { throw ("[STOP] não achei pasta: " + $root) }

$targets = Get-ChildItem -LiteralPath $root -Recurse -File -Filter "page.tsx"
Write-Host ("[DIAG] pages V2: " + $targets.Count)

$changedFiles = New-Object System.Collections.Generic.List[string]
$skippedFiles = New-Object System.Collections.Generic.List[string]

foreach ($f in $targets) {
  $raw = Get-Content -LiteralPath $f.FullName -Raw

  # só aplica em pages async (server component async) — onde dá pra await sem dor
  $isAsync = $raw.Contains("export default async function") -or $raw.Contains("export default async function Page") -or $raw.Contains("async function Page")
  if (-not $isAsync) {
    $skippedFiles.Add($f.FullName) | Out-Null
    continue
  }

  $lines = $raw -split "`r?`n"
  $out = New-Object System.Collections.Generic.List[string]
  $changed = $false

  foreach ($ln in $lines) {
    $n = $ln

    # props.params.X -> (await props.params).X
    if ($n.Contains("props.params.") -and (-not $n.Contains("(await props.params)."))) {
      $n = $n.Replace("props.params.", "(await props.params).")
      $changed = $true
    }

    # const { ... } = props.params; -> await props.params
    if ($n.Contains("= props.params;") -and (-not $n.Contains("await props.params"))) {
      $n = $n.Replace("= props.params;", "= await props.params;")
      $changed = $true
    }

    # props.searchParams.X -> (await props.searchParams).X
    if ($n.Contains("props.searchParams.") -and (-not $n.Contains("(await props.searchParams)."))) {
      $n = $n.Replace("props.searchParams.", "(await props.searchParams).")
      $changed = $true
    }

    # const { ... } = props.searchParams; -> await props.searchParams
    if ($n.Contains("= props.searchParams;") -and (-not $n.Contains("await props.searchParams"))) {
      $n = $n.Replace("= props.searchParams;", "= await props.searchParams;")
      $changed = $true
    }

    # params.X -> (await params).X (evita mexer em props.params que já tratamos)
    if ($n.Contains("params.") -and (-not $n.Contains("(await params).")) -and (-not $n.Contains("props.params")) -and (-not $n.Contains("searchParams"))) {
      $n = $n.Replace("params.", "(await params).")
      $changed = $true
    }

    # const { ... } = params; -> await params
    if ($n.Contains("= params;") -and (-not $n.Contains("await params")) -and (-not $n.Contains("props.params"))) {
      $n = $n.Replace("= params;", "= await params;")
      $changed = $true
    }

    # searchParams.X -> (await searchParams).X
    if ($n.Contains("searchParams.") -and (-not $n.Contains("(await searchParams).")) -and (-not $n.Contains("props.searchParams"))) {
      $n = $n.Replace("searchParams.", "(await searchParams).")
      $changed = $true
    }

    # const { ... } = searchParams; -> await searchParams
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

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Hotfix v0_35 — Next 16.1 async params/searchParams (V2)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Causa") | Out-Null
$rep.Add("- Em Next.js 16.1+ no dev, params/searchParams podem ser Promises; acessar .slug direto estoura erro.") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Fix") | Out-Null
$rep.Add("- Em pages async: props.params.* / params.* -> (await ...).*") | Out-Null
$rep.Add("- Também cobre searchParams pelo mesmo motivo.") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
if ($changedFiles.Count -eq 0) {
  $rep.Add("- (nenhum — já estavam no padrão)") | Out-Null
} else {
  foreach ($p in $changedFiles) { $rep.Add("- " + $p) | Out-Null }
}
$rep.Add("") | Out-Null
$rep.Add("## Arquivos pulados (não-async)") | Out-Null
if ($skippedFiles.Count -eq 0) {
  $rep.Add("- (nenhum)") | Out-Null
} else {
  foreach ($p in $skippedFiles) { $rep.Add("- " + $p) | Out-Null }
}
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null
$rep.Add("") | Out-Null

WriteReport "cv-hotfix-next16-async-params-v0_35.md" ($rep -join "`n") | Out-Null
Write-Host "[OK] v0_35 aplicado e verificado."