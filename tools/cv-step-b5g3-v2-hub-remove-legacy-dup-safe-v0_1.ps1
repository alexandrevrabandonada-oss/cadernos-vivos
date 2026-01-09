# cv-step-b5g3-v2-hub-remove-legacy-dup-safe-v0_1
$ErrorActionPreference = "Stop"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Write-Host ("== cv-step-b5g3-v2-hub-remove-legacy-dup-safe-v0_1 == " + $stamp)

$repoRoot = (Resolve-Path ".").Path

# ------------------------------------------------------------
# bootstrap (prefer)
# ------------------------------------------------------------
$boot = Join-Path $repoRoot "tools\_bootstrap.ps1"
if (Test-Path -LiteralPath $boot) {
  . $boot
} else {
  function EnsureDir([string]$p) { [IO.Directory]::CreateDirectory($p) | Out-Null }
  function WriteUtf8NoBom([string]$p, [string]$content) {
    $enc = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($p, $content, $enc)
  }
  function BackupFile([string]$p) {
    $bkDir = Join-Path $repoRoot "tools\_patch_backup"
    EnsureDir $bkDir
    $leaf = Split-Path -Leaf $p
    $dest = Join-Path $bkDir ($stamp + "-" + $leaf + ".bak")
    Copy-Item -LiteralPath $p -Destination $dest -Force
    return $dest
  }
}

Write-Host ("[DIAG] Repo: " + $repoRoot)

# ------------------------------------------------------------
# locate Hub V2 page.tsx (handle [slug] literal paths)
# ------------------------------------------------------------
$hub = Join-Path $repoRoot "src\app\c\[slug]\v2\page.tsx"
if (-not (Test-Path -LiteralPath $hub)) {
  $rootC = Join-Path $repoRoot "src\app\c"
  if (-not (Test-Path -LiteralPath $rootC)) { throw ("[STOP] não achei: " + $rootC) }

  $pages = Get-ChildItem -LiteralPath $rootC -Recurse -File -Filter "page.tsx"
  $pages = @($pages)

  $exact = $pages | Where-Object { $_.FullName -match "\\src\\app\\c\\\[slug\\]\\v2\\page\.tsx$" } | Select-Object -First 1
  if ($exact) {
    $hub = $exact.FullName
  } else {
    # fallback: qualquer ...\c\*\v2\page.tsx (pega o primeiro)
    $fallback = $pages | Where-Object { $_.FullName -match "\\src\\app\\c\\.+\\v2\\page\.tsx$" } | Select-Object -First 1
    if (-not $fallback) { throw "[STOP] nao consegui localizar o Hub V2 (page.tsx) em src/app/c/**/v2/page.tsx" }
    $hub = $fallback.FullName
  }
}

Write-Host ("[DIAG] Hub V2: " + $hub)
$bk = BackupFile $hub
Write-Host ("[BK]  tools/_patch_backup/" + (Split-Path -Leaf $bk))

# ------------------------------------------------------------
# patch: remove legacy duplicated block after mindmap
# ------------------------------------------------------------
$raw = Get-Content -LiteralPath $hub -Raw
if (-not $raw) { throw "[STOP] hub vazio (Get-Content -Raw retornou null)" }

$mindIdx = $raw.IndexOf("<Cv2MindmapHubClient", [System.StringComparison]::Ordinal)
if ($mindIdx -lt 0) {
  throw "[STOP] não encontrei <Cv2MindmapHubClient .../> no Hub (mindmap ainda não injetado?)"
}

# end of mindmap tag
$mindEnd = $raw.IndexOf("/>", $mindIdx, [System.StringComparison]::Ordinal)
if ($mindEnd -lt 0) { $mindEnd = $raw.IndexOf(">", $mindIdx, [System.StringComparison]::Ordinal) }
if ($mindEnd -lt 0) { throw "[STOP] não consegui achar o fim do tag do mindmap" }
$searchStart = [Math]::Min($raw.Length, $mindEnd + 2)

# find legacy text AFTER mindmap
$legacyText = "Explore o universo por portas"
$legIdx = $raw.IndexOf($legacyText, $searchStart, [System.StringComparison]::OrdinalIgnoreCase)
if ($legIdx -lt 0) {
  # fallback: procura outros marcadores típicos do legado
  $legIdx = $raw.IndexOf("Mapa primeiro", $searchStart, [System.StringComparison]::OrdinalIgnoreCase)
}
if ($legIdx -lt 0) {
  Write-Host "[SKIP] não achei texto do legado depois do mindmap — talvez já esteja limpo."
} else {
  # compute end limit: before closing of return
  $endReturn = $raw.LastIndexOf(");", [System.StringComparison]::Ordinal)
  if ($endReturn -lt 0) { $endReturn = $raw.Length }

  $mainClose = $raw.LastIndexOf("</main>", $endReturn, [System.StringComparison]::OrdinalIgnoreCase)
  if ($mainClose -lt 0) {
    $mainClose = $raw.LastIndexOf("</div>", $endReturn, [System.StringComparison]::OrdinalIgnoreCase)
  }
  if ($mainClose -lt 0) { $mainClose = $endReturn }

  if ($mainClose -le $legIdx) {
    throw "[STOP] achei legado, mas não achei </main> (ou </div>) depois dele — não vou cortar no escuro."
  }

  # start removal: first <section|div> after mindmap (and before mainClose)
  $segment = $raw.Substring($searchStart, $mainClose - $searchStart)
  $m = [regex]::Match($segment, "(?m)^[ \t]*<(section|div)\b")
  if (-not $m.Success) {
    # fallback: start at line where legacy text begins
    $lineStart = $raw.LastIndexOf("`n", $legIdx)
    if ($lineStart -lt 0) { $lineStart = 0 } else { $lineStart = $lineStart + 1 }
    $startIdx = $lineStart
  } else {
    $startIdx = $searchStart + $m.Index
  }

  if ($startIdx -ge $mainClose) { throw "[STOP] startIdx >= mainClose (cálculo de corte inválido)" }

  $before = $raw.Substring(0, $startIdx)
  $after  = $raw.Substring($mainClose)

  $marker = "`n{/* CV2_LEGACY_DUP_REMOVED */}`n"
  $raw2 = $before + $marker + $after

  WriteUtf8NoBom $hub $raw2
  Write-Host "[PATCH] Hub V2: removeu bloco legado duplicado após Mindmap (safe cut até </main>/<\div>)."
}

# ------------------------------------------------------------
# verify
# ------------------------------------------------------------
$verify = Join-Path $repoRoot "tools\cv-verify.ps1"
if (Test-Path -LiteralPath $verify) {
  Write-Host ("[RUN] " + $verify)
  & $verify
  if ($LASTEXITCODE -ne 0) { throw ("[STOP] cv-verify falhou (exit=" + $LASTEXITCODE + ")") }
} else {
  Write-Host "[WARN] tools/cv-verify.ps1 não encontrado — rode lint/build manual."
}

Write-Host "[OK] b5g3 concluído."