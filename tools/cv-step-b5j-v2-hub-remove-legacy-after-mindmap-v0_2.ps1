$ErrorActionPreference = "Stop"

function _NowTag { Get-Date -Format "yyyyMMdd-HHmmss" }

# Bootstrap + fallbacks
$boot = Join-Path $PSScriptRoot "_bootstrap.ps1"
if (Test-Path -LiteralPath $boot) { . $boot }

if (-not (Get-Command EnsureDir -ErrorAction SilentlyContinue)) {
  function EnsureDir([string]$p) { if ($p -and -not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
}
if (-not (Get-Command WriteUtf8NoBom -ErrorAction SilentlyContinue)) {
  function WriteUtf8NoBom([string]$p, [string]$t) {
    EnsureDir (Split-Path -Parent $p)
    [IO.File]::WriteAllText($p, $t, [Text.UTF8Encoding]::new($false))
  }
}
if (-not (Get-Command BackupFile -ErrorAction SilentlyContinue)) {
  function BackupFile([string]$p) {
    if (-not (Test-Path -LiteralPath $p)) { return $null }
    $bkDir = Join-Path $PSScriptRoot "_patch_backup"
    EnsureDir $bkDir
    $ts = Get-Date -Format "yyyyMMdd-HHmmss"
    $leaf = Split-Path -Leaf $p
    $dst = Join-Path $bkDir ($ts + "-" + $leaf + ".bak")
    Copy-Item -LiteralPath $p -Destination $dst -Force
    return $dst
  }
}

function Get-Tokens([string]$raw) {
  # tags minúsculas só (div/section/main/article etc)
  $pat = '<(\/?)([a-z][a-z0-9-]*)\b[^>]*?(\/?)>'
  $ms = [regex]::Matches($raw, $pat)
  $toks = @()
  foreach ($m in $ms) {
    $name = $m.Groups[2].Value
    $isClose = ($m.Groups[1].Value -eq "/")
    $isSelf = ($m.Groups[3].Value -eq "/")
    $toks += [pscustomobject]@{
      Name = $name
      IsClose = $isClose
      IsSelf = $isSelf
      Start = $m.Index
      End = ($m.Index + $m.Length)
      Text = $m.Value
    }
  }
  return ,$toks
}

function Find-MatchingClose([object[]]$toks, [int]$startTokIndex) {
  $name = $toks[$startTokIndex].Name
  $depth = 0
  for ($i=$startTokIndex; $i -lt $toks.Count; $i++) {
    $t = $toks[$i]
    if ($t.Name -ne $name) { continue }
    if ($t.IsSelf) { continue }
    if (-not $t.IsClose) { $depth++ } else { $depth-- }
    if ($depth -eq 0) { return $i }
  }
  return -1
}

function Find-BestContainerSpan([string]$raw, [object[]]$toks, [int]$hitPos, [string]$needle, [string[]]$containerTags, [string[]]$forbid) {
  $best = $null

  # coletar todos os tokens de abertura candidatos antes do hit
  for ($i=0; $i -lt $toks.Count; $i++) {
    $t = $toks[$i]
    if ($t.Start -gt $hitPos) { break }
    if ($t.IsClose -or $t.IsSelf) { continue }
    if ($containerTags -notcontains $t.Name) { continue }

    $closeIdx = Find-MatchingClose $toks $i
    if ($closeIdx -lt 0) { continue }

    $openPos = $t.Start
    $closePos = $toks[$closeIdx].End

    if ($openPos -gt $hitPos -or $closePos -lt $hitPos) { continue }

    $spanLen = ($closePos - $openPos)
    if ($spanLen -le 0) { continue }

    $block = $raw.Substring($openPos, $spanLen)

    if ($block.IndexOf($needle, [StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }

    $bad = $false
    foreach ($f in $forbid) {
      if ($block.IndexOf($f, [StringComparison]::Ordinal) -ge 0) { $bad = $true; break }
    }
    if ($bad) { continue }

    if (-not $best -or $spanLen -lt $best.Len) {
      $best = [pscustomobject]@{ Open=$openPos; Close=$closePos; Len=$spanLen; Tag=$t.Name }
    }
  }

  return $best
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$stamp = _NowTag
Write-Host ("== cv-step-b5j-v2-hub-remove-legacy-after-mindmap-v0_2 == " + $stamp)
Write-Host ("[DIAG] Repo: " + $repoRoot)

$hubRel = "src/app/c/[slug]/v2/page.tsx"
$hubAbs = Join-Path $repoRoot $hubRel
if (-not (Test-Path -LiteralPath $hubAbs)) { throw ("[STOP] não achei: " + $hubAbs) }

$bk = BackupFile $hubAbs
if ($bk) { Write-Host ("[BK]    tools/_patch_backup/" + (Split-Path -Leaf $bk)) }

$raw = Get-Content -LiteralPath $hubAbs -Raw

# achar o uso REAL do mindmap (não import)
$mindPos = -1
$mindPos = $raw.IndexOf("CV2_MINDMAP_HUB", [StringComparison]::Ordinal)
if ($mindPos -lt 0) { $mindPos = $raw.IndexOf("<Cv2MindmapHubClient", [StringComparison]::Ordinal) }
if ($mindPos -lt 0) { $mindPos = 0 }
Write-Host ("[DIAG] Mindmap marker pos: " + $mindPos)

# needles do legado (evitar 'Núcleo do universo' pq existe no novo)
$needles = @(
  "Explore o universo por portas",
  "6 portas essenciais",
  "Mapa primeiro, depois",
  "Mapa primeiro, depois provas"
)

$hitPos = -1
$hitNeedle = $null
foreach ($n in $needles) {
  $p = $raw.IndexOf($n, $mindPos, [StringComparison]::OrdinalIgnoreCase)
  if ($p -ge 0) { $hitPos = $p; $hitNeedle = $n; break }
}

if ($hitPos -lt 0) {
  Write-Host "[SKIP] Não achei needle do bloco legado após o mindmap. Nada a remover."
} else {
  Write-Host ("[DIAG] Hit needle: '" + $hitNeedle + "' @ pos " + $hitPos)

  $toks = Get-Tokens $raw

  $containerTags = @("div","section","main","article")
  $forbid = @("Cv2MindmapHubClient","Cv2CoreNodes","Cv2MapRail","CV2_CORE_NODES","CV2_MINDMAP_HUB","Cv2MindmapHub")

  $best = Find-BestContainerSpan -raw $raw -toks $toks -hitPos $hitPos -needle $hitNeedle -containerTags $containerTags -forbid $forbid

  if (-not $best) {
    # fallback: tentar remover só a SECTION/DIV mais próxima mesmo que o container seja 'main'
    throw "[STOP] Achei o needle do legado, mas não consegui isolar um container <div/section/main/article> seguro (sem pegar Core/Mindmap)."
  }

  Write-Host ("[PATCH] Removendo bloco legado <" + $best.Tag + "> span [" + $best.Open + ".." + $best.Close + ") len=" + $best.Len)

  $before = $raw.Substring(0, $best.Open)
  $after  = $raw.Substring($best.Close)

  $marker = "`n      {/* CV2_LEGACY_BLOCK_REMOVED " + $stamp + " needle=" + $hitNeedle + " */}`n"
  $newRaw = $before + $marker + $after

  WriteUtf8NoBom $hubAbs $newRaw
  Write-Host ("[OK] legado removido do Hub V2: " + $hubRel)
}

# VERIFY
$verify = Join-Path $repoRoot "tools/cv-verify.ps1"
if (Test-Path -LiteralPath $verify) {
  Write-Host ("[RUN] " + $verify)
  & (Get-Command pwsh.exe -ErrorAction Stop).Path -NoProfile -ExecutionPolicy Bypass -File $verify
  if ($LASTEXITCODE -ne 0) { throw ("[STOP] cv-verify falhou (exit=" + $LASTEXITCODE + ")") }
} else {
  $npm = (Get-Command npm.cmd -ErrorAction Stop).Path
  Write-Host "[RUN] npm run lint"
  $lintOut = (& $npm run lint 2>&1 | Out-String)
  if ($LASTEXITCODE -ne 0) { Write-Host $lintOut; throw "[STOP] lint falhou" }

  Write-Host "[RUN] npm run build"
  $buildOut = (& $npm run build 2>&1 | Out-String)
  if ($LASTEXITCODE -ne 0) { Write-Host $buildOut; throw "[STOP] build falhou" }
}

# REPORT
$repDir = Join-Path $repoRoot "reports"
EnsureDir $repDir
$rep = Join-Path $repDir ($stamp + "-cv-step-b5j-v2-hub-remove-legacy-after-mindmap-v0_2.md")
$body = @(
  ("# CV B5J v0_2 — V2 Hub: remover bloco legado pós-mindmap — " + $stamp),
  "",
  ("Repo: " + $repoRoot),
  "",
  "## PATCH",
  ("- " + $hubRel + " (remove bloco que contém needles do legado, após mindmap)"),
  "",
  "## VERIFY",
  "- OK (se terminou sem STOP)"
) -join "`n"
WriteUtf8NoBom $rep $body
Write-Host ("[REPORT] reports\" + (Split-Path -Leaf $rep))
Write-Host "[OK] B5J v0_2 concluído."