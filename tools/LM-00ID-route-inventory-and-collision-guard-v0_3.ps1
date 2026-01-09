param(
  [switch]$Json,
  [switch]$NoFailOnCollision
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function NowStamp() { return (Get-Date).ToString("yyyyMMdd-HHmmss") }

# --- bootstrap (se existir) ---
$root = (Resolve-Path ".").Path
$bootstrap = Join-Path $root "tools\_bootstrap.ps1"
if (Test-Path $bootstrap) { . $bootstrap }

# Fallbacks caso _bootstrap não exista
if (-not (Get-Command EnsureDir -ErrorAction SilentlyContinue)) {
  function EnsureDir([string]$p) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}
if (-not (Get-Command WriteUtf8NoBom -ErrorAction SilentlyContinue)) {
  function WriteUtf8NoBom([string]$path, [string]$content) {
    $full = Join-Path (Resolve-Path ".").Path $path
    EnsureDir (Split-Path -Parent $full)
    $enc = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($full, $content, $enc)
  }
}

Write-Host ("== LM-00ID ROUTE INVENTORY + COLLISION GUARD v0_3 == " + (Get-Date).ToString("yyyyMMdd-HHmmss"))
Write-Host ("Root: " + $root)

$stamp = NowStamp
$repRel  = "reports\LM-00ID-route-inventory-$stamp.md"
$jsonRel = "reports\LM-00ID-route-inventory-$stamp.json"

$appDir = Join-Path $root "app"
if (-not (Test-Path $appDir)) { throw ("Missing app/ directory: " + $appDir) }

function IsGroupSeg([string]$seg) {
  return ($seg.StartsWith("(") -and $seg.EndsWith(")"))
}
function IsParallelSlot([string]$seg) {
  return ($seg.StartsWith("@"))
}
function NormalizeUrl([string]$relDir, [string]$isApi) {
  # relDir: path relativo dentro de app\ (sem o filename)
  if ([string]::IsNullOrWhiteSpace($relDir)) { return ($isApi ? "/api" : "/") }

  $parts = $relDir -split '[\\/]' | Where-Object { $_ -and $_.Trim() -ne "" }
  $out = New-Object System.Collections.Generic.List[string]

  foreach ($p in $parts) {
    if (IsGroupSeg $p) { continue }
    if (IsParallelSlot $p) { continue }
    # ignore private folders _foo
    if ($p.StartsWith("_")) { continue }

    # Next dynamic segments: [id] -> :id ; [...slug] -> :slug* ; [[...slug]] -> :slug?
    $seg = $p
    if ($seg -match '^\[\[\.\.\.(.+)\]\]$') { $seg = ":" + $Matches[1] + "?" }
    elseif ($seg -match '^\[\.\.\.(.+)\]$') { $seg = ":" + $Matches[1] + "*" }
    elseif ($seg -match '^\[(.+)\]$') { $seg = ":" + $Matches[1] }

    $out.Add($seg) | Out-Null
  }

  $path = "/" + ($out -join "/")
  if ($isApi -and -not $path.StartsWith("/api")) {
    # quando relDir já vem como "api\..." a montagem já dá /api/...
    # mas se relDir for vazio (route no app/api/route.ts), garantimos /api
    $path = "/api" + ($path -replace '^/', '/')
  }
  return $path -replace "//+", "/"
}

$items = New-Object System.Collections.Generic.List[object]

# pages
Get-ChildItem -Path $appDir -Recurse -File -Force |
  Where-Object { $_.Name -match '^page\.(ts|tsx|js|jsx)$' } |
  ForEach-Object {
    $rel = $_.FullName.Substring($appDir.Length).TrimStart('\','/')
    $dir = Split-Path $rel -Parent
    if ($dir -eq ".") { $dir = "" }
    $url = NormalizeUrl $dir $false
    $items.Add([pscustomobject]@{
      kind = "page"
      url  = $url
      file = ("app\" + $rel.Replace('/','\'))
    }) | Out-Null
  }

# route handlers
Get-ChildItem -Path $appDir -Recurse -File -Force |
  Where-Object { $_.Name -match '^route\.(ts|js)$' } |
  ForEach-Object {
    $rel = $_.FullName.Substring($appDir.Length).TrimStart('\','/')
    $dir = Split-Path $rel -Parent
    if ($dir -eq ".") { $dir = "" }
    $isApi = $dir -match '^(api[\\/]|api$)'
    $url = if ($isApi) {
      # remove o prefixo "api\" pra url ficar /api/...
      $dir2 = ($dir -replace '^(api[\\/]|api$)', '').TrimStart('\','/')
      if ($dir2 -eq ".") { $dir2 = "" }
      "/api" + (NormalizeUrl $dir2 $false).TrimStart("/")
    } else {
      NormalizeUrl $dir $false
    }
    $url = $url -replace "//+", "/"
    $items.Add([pscustomobject]@{
      kind = ($isApi ? "api" : "route")
      url  = $url
      file = ("app\" + $rel.Replace('/','\'))
    }) | Out-Null
  }

# collisions (mesma URL em >1 item)
$groups = $items | Group-Object url | Where-Object { $_.Count -gt 1 }
$collisions = @()
foreach ($g in $groups) {
  $collisions += [pscustomobject]@{
    url = $g.Name
    count = $g.Count
    files = ($g.Group | ForEach-Object { $_.file })
    kinds = ($g.Group | ForEach-Object { $_.kind })
  }
}

# report md
$md = New-Object System.Collections.Generic.List[string]
$md.Add("# LM-00ID Route Inventory") | Out-Null
$md.Add("") | Out-Null
$md.Add("- Timestamp: " + $stamp) | Out-Null
$md.Add("- Total: " + $items.Count) | Out-Null
$md.Add("- Pages: " + (@($items | Where-Object { $_.kind -eq "page" }).Count)) | Out-Null
$md.Add("- APIs  : " + (@($items | Where-Object { $_.kind -eq "api" }).Count)) | Out-Null
$md.Add("- Routes: " + (@($items | Where-Object { $_.kind -eq "route" }).Count)) | Out-Null
$md.Add("") | Out-Null

if ($collisions.Count -gt 0) {
  $md.Add("## Collisions (same URL)") | Out-Null
  foreach ($c in $collisions) {
    $md.Add("") | Out-Null
    $md.Add("- URL: **" + $c.url + "** (" + $c.count + ")") | Out-Null
    for ($i=0; $i -lt $c.files.Count; $i++) {
      $md.Add("  - [" + $c.kinds[$i] + "] " + $c.files[$i]) | Out-Null
    }
  }
  $md.Add("") | Out-Null
} else {
  $md.Add("## Collisions") | Out-Null
  $md.Add("") | Out-Null
  $md.Add("None ✅") | Out-Null
  $md.Add("") | Out-Null
}

$md.Add("## Routes (sorted)") | Out-Null
$md.Add("") | Out-Null
foreach ($it in ($items | Sort-Object url, kind, file)) {
  $md.Add("- [" + $it.kind + "] " + $it.url + " — " + $it.file) | Out-Null
}

WriteUtf8NoBom $repRel ($md -join "`n")
Write-Host ("[REPORT] " + (Join-Path $root $repRel))

# json (opcional) — System.Text.Json (evita ConvertTo-Json)
if ($Json) {
  $obj = [pscustomobject]@{
    timestamp = $stamp
    root = $root
    total = $items.Count
    items = $items
    collisions = $collisions
  }
  $opts = New-Object System.Text.Json.JsonSerializerOptions
  $opts.WriteIndented = $true
  $json = [System.Text.Json.JsonSerializer]::Serialize($obj, $opts)
  WriteUtf8NoBom $jsonRel $json
  Write-Host ("[JSON] " + (Join-Path $root $jsonRel))
}

if (($collisions.Count -gt 0) -and (-not $NoFailOnCollision)) {
  throw ("Route collision detected (" + $collisions.Count + "). See report: " + $repRel)
}

Write-Host "DONE."