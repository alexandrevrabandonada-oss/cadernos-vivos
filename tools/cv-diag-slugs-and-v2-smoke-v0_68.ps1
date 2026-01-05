param(
  [string]$BaseUrl = "http://localhost:3000",
  [int]$Max = 30
)

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Write-Host ("[DIAG] Repo: " + $repo)
. (Join-Path $PSScriptRoot "_bootstrap.ps1")

# sempre vira array, mesmo com 0 ou 1 item
$metas = @(
  Get-ChildItem -LiteralPath $repo -Recurse -File -Filter "meta.json" -ErrorAction SilentlyContinue |
    Where-Object {
      $_.FullName -notmatch "\\node_modules\\|\\\.next\\|\\tools\\_patch_backup\\|\\reports\\"
    }
)

if (@($metas).Count -eq 0) {
  Write-Host "[STOP] nao achei meta.json no repo (fora de node_modules/.next)."
  exit 1
}

$items = New-Object System.Collections.Generic.List[object]
foreach ($m in $metas) {
  try {
    $txt = Get-Content -LiteralPath $m.FullName -Raw
    if ([string]::IsNullOrWhiteSpace($txt)) { continue }
    $j = $txt | ConvertFrom-Json -ErrorAction Stop

    $title = $null
    try { $title = $j.title } catch {}
    if ([string]::IsNullOrWhiteSpace($title)) { continue }

    $slug = Split-Path -Leaf (Split-Path -Parent $m.FullName)
    $rel = $m.FullName.Substring($repo.Length).TrimStart("\")
    $items.Add([pscustomobject]@{ slug=$slug; title=$title; meta=$rel }) | Out-Null
  } catch {
    # ignora meta.json que nao é do caderno
  }
}

if ($items.Count -eq 0) {
  Write-Host "[STOP] achei meta.json, mas nenhum parece ser de caderno (sem campo title)."
  Write-Host "[HINT] se seus metas nao tem title, me manda 1 exemplo."
  exit 1
}

Write-Host ""
Write-Host ("[OK] slugs detectados (top " + $Max + "):")
$items | Select-Object -First $Max | Format-Table slug, title, meta -AutoSize

Write-Host ""
Write-Host ("[SMOKE] testando V2 para os primeiros " + [Math]::Min(10, $items.Count) + " slugs em " + $BaseUrl)

function Hit([string]$url) {
  try {
    $r = Invoke-WebRequest -Uri $url -Method GET -SkipHttpErrorCheck -TimeoutSec 8
    return $r.StatusCode
  } catch {
    return -1
  }
}

$take = [Math]::Min(10, $items.Count)
for ($i=0; $i -lt $take; $i++) {
  $slug = $items[$i].slug
  $u1 = ($BaseUrl.TrimEnd("/") + "/c/" + $slug)
  $u2 = ($BaseUrl.TrimEnd("/") + "/c/" + $slug + "/v2")
  $u3 = ($BaseUrl.TrimEnd("/") + "/c/" + $slug + "/v2/provas")
  $s1 = Hit $u1
  $s2 = Hit $u2
  $s3 = Hit $u3
  Write-Host ("- " + $slug + " :: V1=" + $s1 + " V2=" + $s2 + " V2/provas=" + $s3)
}

Write-Host ""
Write-Host "[NEXT] abre com um slug real:"
Write-Host ("  " + $BaseUrl.TrimEnd("/") + "/c/<slug>/v2")