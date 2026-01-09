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

function Get-DeltaForTag([string]$line, [string]$tag) {
  $open = [regex]::Matches($line, "<" + $tag + "\b").Count
  $self = [regex]::Matches($line, "<" + $tag + "\b[^>]*\/>").Count
  $close = [regex]::Matches($line, "</" + $tag + ">").Count
  return (($open - $self) - $close)
}

function FindBestBalancedBlock([string[]]$lines, [int]$hitIndex, [string]$needle, [string[]]$tags, [string[]]$forbid, [string[]]$prefer) {
  $best = $null

  for ($seek=$hitIndex; $seek -ge 0; $seek--) {
    foreach ($tag in $tags) {
      $ln = $lines[$seek]

      if ($ln -notmatch "^\s*<" + $tag + "\b") { continue }
      if ($ln -match "^\s*</") { continue }
      if ($ln -match "<" + $tag + "\b[^>]*\/>\s*$") { continue }

      $depth = 0
      $end = -1
      for ($j=$seek; $j -lt $lines.Count; $j++) {
        $depth += (Get-DeltaForTag $lines[$j] $tag)
        if ($depth -eq 0 -and $j -gt $seek) { $end = $j; break }
      }
      if ($end -le $seek) { continue }

      $block = ($lines[$seek..$end] -join "`n")
      if ($block.IndexOf($needle, [StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }

      $bad = $false
      foreach ($f in $forbid) {
        if ($block.IndexOf($f, [StringComparison]::Ordinal) -ge 0) { $bad = $true; break }
      }
      if ($bad) { continue }

      $score = ($end - $seek)

      # bônus se tiver palavras “características” do legado
      $bonus = 0
      foreach ($p in $prefer) {
        if ($block.IndexOf($p, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $bonus += 50 }
      }

      $cand = [pscustomobject]@{ Start=$seek; End=$end; Tag=$tag; Score=($score - $bonus) }
      if (-not $best -or $cand.Score -lt $best.Score) { $best = $cand }
    }
  }

  return $best
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$stamp = _NowTag
Write-Host ("== cv-step-b5j-v2-hub-remove-legacy-after-mindmap-v0_1 == " + $stamp)
Write-Host ("[DIAG] Repo: " + $repoRoot)

$hubRel = "src/app/c/[slug]/v2/page.tsx"
$hubAbs = Join-Path $repoRoot $hubRel
if (-not (Test-Path -LiteralPath $hubAbs)) { throw ("[STOP] não achei: " + $hubAbs) }

$bk = BackupFile $hubAbs
if ($bk) { Write-Host ("[BK]    tools/_patch_backup/" + (Split-Path -Leaf $bk)) }

$lines = Get-Content -LiteralPath $hubAbs

# achar o ponto do mindmap (a partir daqui é onde o legado tá duplicando)
$mindIdx = -1
for ($i=0; $i -lt $lines.Count; $i++) {
  if ($lines[$i].IndexOf("Cv2MindmapHubClient", [StringComparison]::Ordinal) -ge 0 -or
      $lines[$i].IndexOf("CV2_MINDMAP_HUB", [StringComparison]::Ordinal) -ge 0) {
    $mindIdx = $i
    break
  }
}
if ($mindIdx -lt 0) { $mindIdx = 0 }
Write-Host ("[DIAG] Mindmap marker @ line " + ($mindIdx+1))

# procurar needles do legado APÓS o mindmap
$needles = @(
  "Núcleo do universo",
  "6 portas essenciais",
  "Explore o universo por portas",
  "Mapa primeiro"
)

$hit = -1
$hitNeedle = $null
for ($i=$mindIdx; $i -lt $lines.Count; $i++) {
  foreach ($n in $needles) {
    if ($lines[$i].IndexOf($n, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
      $hit = $i
      $hitNeedle = $n
      break
    }
  }
  if ($hit -ge 0) { break }
}

if ($hit -lt 0) {
  Write-Host "[SKIP] Não encontrei bloco legado após o mindmap. Nada a fazer."
} else {
  Write-Host ("[DIAG] Hit legado: '" + $hitNeedle + "' @ line " + ($hit+1))

  $forbid = @("Cv2MindmapHubClient","Cv2CoreNodes","Cv2MapRail","Cv2MindmapHub","CV2_CORE_NODES","CV2_MINDMAP_HUB")
  $prefer = @("SEU-SLUG","6 portas essenciais","Comece aqui","Mapa primeiro","Explore o universo por portas")

  $best = FindBestBalancedBlock -lines $lines -hitIndex $hit -needle $hitNeedle -tags @("section","div") -forbid $forbid -prefer $prefer

  if (-not $best) {
    throw "[STOP] Achei o legado, mas não consegui isolar um bloco <section>/<div> seguro pra remover."
  }

  Write-Host ("[PATCH] Removendo bloco legado <" + $best.Tag + "> linhas " + ($best.Start+1) + " .. " + ($best.End+1))

  $head = @()
  if ($best.Start -gt 0) { $head = $lines[0..($best.Start-1)] }
  $tail = @()
  if ($best.End -lt ($lines.Count-1)) { $tail = $lines[($best.End+1)..($lines.Count-1)] }

  $marker = ("      {/* CV2_LEGACY_AFTER_MINDMAP_REMOVED " + $stamp + " */}")

  $newLines = @()
  if ($head.Count -gt 0) { $newLines += $head }
  $newLines += $marker
  if ($tail.Count -gt 0) { $newLines += $tail }

  WriteUtf8NoBom $hubAbs ($newLines -join "`n")
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
$rep = Join-Path $repDir ($stamp + "-cv-step-b5j-v2-hub-remove-legacy-after-mindmap.md")
$body = @(
  ("# CV B5J — V2 Hub: remover bloco legado pós-mindmap — " + $stamp),
  "",
  ("Repo: " + $repoRoot),
  "",
  "## PATCH",
  ("- " + $hubRel + " (remove duplicação 'Núcleo do universo' após mindmap)"),
  "",
  "## VERIFY",
  "- OK (se terminou sem STOP)"
) -join "`n"
WriteUtf8NoBom $rep $body
Write-Host ("[REPORT] reports\" + (Split-Path -Leaf $rep))
Write-Host "[OK] B5J concluído."