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

function FindBlockByTagAfter([string]$raw, [int]$afterPos, [string[]]$needles, [string]$tagName) {
  # acha needle depois do afterPos
  $hitPos = -1
  $hitNeedle = $null
  foreach ($n in $needles) {
    $p = $raw.IndexOf($n, $afterPos, [StringComparison]::OrdinalIgnoreCase)
    if ($p -ge 0) { $hitPos = $p; $hitNeedle = $n; break }
  }
  if ($hitPos -lt 0) { return $null }

  # backtrack para o último "<tag" entre afterPos e hitPos
  $openToken = "<" + $tagName
  $startPos = $raw.LastIndexOf($openToken, $hitPos, $hitPos - $afterPos, [StringComparison]::OrdinalIgnoreCase)
  if ($startPos -lt 0) { return $null }

  # match tags para fechar
  $pat = "(?s)<\/?" + [regex]::Escape($tagName) + "\b[^>]*?>"
  $ms = [regex]::Matches($raw.Substring($startPos), $pat)

  $depth = 0
  $endLocal = -1
  for ($i=0; $i -lt $ms.Count; $i++) {
    $t = $ms[$i].Value
    $isClose = $t.StartsWith("</")
    $isSelf = $t.EndsWith("/>")
    if ($isSelf) { continue }

    if (-not $isClose) { $depth++ } else { $depth-- }

    if ($depth -eq 0) {
      $endLocal = $ms[$i].Index + $ms[$i].Length
      break
    }
  }
  if ($endLocal -lt 0) { return $null }

  $endPos = $startPos + $endLocal
  return [pscustomobject]@{ Start=$startPos; End=$endPos; Needle=$hitNeedle; Tag=$tagName; Hit=$hitPos }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$stamp = _NowTag
Write-Host ("== cv-step-b5j-v2-hub-remove-legacy-after-mindmap-v0_4 == " + $stamp)
Write-Host ("[DIAG] Repo: " + $repoRoot)

$hubRel = "src/app/c/[slug]/v2/page.tsx"
$hubAbs = Join-Path $repoRoot $hubRel
if (-not (Test-Path -LiteralPath $hubAbs)) { throw ("[STOP] não achei: " + $hubAbs) }

$bk = BackupFile $hubAbs
if ($bk) { Write-Host ("[BK]    tools/_patch_backup/" + (Split-Path -Leaf $bk)) }

$raw = Get-Content -LiteralPath $hubAbs -Raw

# Mindmap marker
$mindPos = $raw.IndexOf("CV2_MINDMAP_HUB", [StringComparison]::Ordinal)
if ($mindPos -lt 0) { $mindPos = $raw.IndexOf("<Cv2MindmapHubClient", [StringComparison]::Ordinal) }
if ($mindPos -lt 0) { $mindPos = 0 }
Write-Host ("[DIAG] Mindmap pos: " + $mindPos)

# sinais do legado duplicado (o bloco de baixo)
$needles = @(
  "Explore o universo por portas",
  "Mapa primeiro, depois",
  "6 portas essenciais",
  "Núcleo do universo",
  "SEU-SLUG"
)

# tenta remover um <section> completo; se não achar, tenta <div>
$blk = FindBlockByTagAfter -raw $raw -afterPos $mindPos -needles $needles -tagName "section"
if (-not $blk) { $blk = FindBlockByTagAfter -raw $raw -afterPos $mindPos -needles $needles -tagName "div" }

if (-not $blk) {
  Write-Host "[SKIP] Não consegui isolar bloco legado por <section>/<div> após o mindmap."
} else {
  Write-Host ("[DIAG] Legacy needle: " + $blk.Needle + " @ " + $blk.Hit)
  Write-Host ("[PATCH] Removendo bloco <" + $blk.Tag + "> span [" + $blk.Start + ".." + $blk.End + ")")

  $before = $raw.Substring(0, $blk.Start)
  $after  = $raw.Substring($blk.End)
  $marker = "`n      {/* CV2_DUP_LEGACY_REMOVED " + $stamp + " needle=" + $blk.Needle + " */}`n"
  $newRaw = $before + $marker + $after

  WriteUtf8NoBom $hubAbs $newRaw
  Write-Host ("[OK] removido duplicado do Hub V2: " + $hubRel)
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
$rep = Join-Path $repDir ($stamp + "-cv-step-b5j-v2-hub-remove-legacy-after-mindmap-v0_4.md")
$body = @(
  ("# CV B5J v0_4 — Hub V2: remover legado duplicado após mindmap — " + $stamp),
  "",
  ("Repo: " + $repoRoot),
  "",
  "## PATCH",
  ("- " + $hubRel),
  "",
  "## VERIFY",
  "- OK (sem STOP)"
) -join "`n"
WriteUtf8NoBom $rep $body
Write-Host ("[REPORT] reports\" + (Split-Path -Leaf $rep))
Write-Host "[OK] B5J v0_4 concluído."