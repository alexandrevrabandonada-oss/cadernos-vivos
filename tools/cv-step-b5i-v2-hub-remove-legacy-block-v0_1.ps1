$ErrorActionPreference = "Stop"

function _NowTag { Get-Date -Format "yyyyMMdd-HHmmss" }

# Bootstrap (se existir) + fallbacks
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

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$stamp = _NowTag
Write-Host ("== cv-step-b5i-v2-hub-remove-legacy-block-v0_1 == " + $stamp)
Write-Host ("[DIAG] Repo: " + $repoRoot)

$hubRel = "src/app/c/[slug]/v2/page.tsx"
$hubAbs = Join-Path $repoRoot $hubRel
if (-not (Test-Path -LiteralPath $hubAbs)) { throw ("[STOP] não achei: " + $hubAbs) }

$bk = BackupFile $hubAbs
if ($bk) { Write-Host ("[BK]    tools/_patch_backup/" + (Split-Path -Leaf $bk)) }

$lines = Get-Content -LiteralPath $hubAbs

# âncoras de segurança (pra não remover container grande demais)
$guardStrings = @(
  "Cv2MindmapHubClient",
  "CV2_MINDMAP_HUB",
  "Cv2CoreNodes",
  "Cv2MapRail"
)

# onde começar a procurar (preferir depois do mindmap)
$startSearch = 0
for ($i=0; $i -lt $lines.Count; $i++) {
  if ($lines[$i].IndexOf("Cv2MindmapHubClient", [StringComparison]::Ordinal) -ge 0 -or
      $lines[$i].IndexOf("CV2_MINDMAP_HUB", [StringComparison]::Ordinal) -ge 0) {
    $startSearch = $i
    break
  }
}

$needle = "Explore o universo por portas."
$hits = New-Object System.Collections.Generic.List[int]
for ($i=$startSearch; $i -lt $lines.Count; $i++) {
  if ($lines[$i].IndexOf($needle, [StringComparison]::Ordinal) -ge 0) { $hits.Add($i) }
}

if ($hits.Count -eq 0) {
  Write-Host "[SKIP] Não achei o texto legado ('Explore o universo por portas.'). Nada a remover."
} else {
  Write-Host ("[DIAG] Hits do legado: " + $hits.Count)

  # remove de baixo pra cima
  for ($h = $hits.Count-1; $h -ge 0; $h--) {
    $idx = $hits[$h]
    $removed = $false

    # tenta achar um bloco pequeno que contenha o needle (preferindo <section> e depois <div>)
    $tags = @("section","div")

    for ($seek=$idx; $seek -ge 0; $seek--) {
      foreach ($tag in $tags) {
        $ln = $lines[$seek]
        if ($ln -match "^\s*<" + $tag + "\b" -and $ln -notmatch "^\s*</") {

          # ignora self-closing
          if ($ln -match "<" + $tag + "\b[^>]*\/>\s*$") { continue }

          $depth = 0
          $end = -1
          for ($j=$seek; $j -lt $lines.Count; $j++) {
            $depth += (Get-DeltaForTag $lines[$j] $tag)
            if ($depth -eq 0 -and $j -gt $seek) { $end = $j; break }
          }
          if ($end -le $seek) { continue }

          $block = ($lines[$seek..$end] -join "`n")

          if ($block.IndexOf($needle, [StringComparison]::Ordinal) -lt 0) { continue }

          # se o bloco contém guardas (mindmap/core/rail), é grande demais -> tenta subir mais pra achar menor
          $tooBig = $false
          foreach ($g in $guardStrings) {
            if ($block.IndexOf($g, [StringComparison]::Ordinal) -ge 0) { $tooBig = $true; break }
          }
          if ($tooBig) { continue }

          Write-Host ("[PATCH] Removendo bloco legado <" + $tag + "> linhas " + ($seek+1) + " .. " + ($end+1))

          $head = @()
          if ($seek -gt 0) { $head = $lines[0..($seek-1)] }
          $tail = @()
          if ($end -lt ($lines.Count-1)) { $tail = $lines[($end+1)..($lines.Count-1)] }

          $marker = ("      {/* CV2_LEGACY_BLOCK_REMOVIDO " + $stamp + " */}")
          $lines = @()
          if ($head.Count -gt 0) { $lines += $head }
          $lines += $marker
          if ($tail.Count -gt 0) { $lines += $tail }

          $removed = $true
          break
        }
      }
      if ($removed) { break }
    }

    if (-not $removed) {
      throw "[STOP] Achei o needle do legado mas não consegui remover um bloco balanceado pequeno."
    }
  }

  WriteUtf8NoBom $hubAbs ($lines -join "`n")
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
$rep = Join-Path $repDir ($stamp + "-cv-step-b5i-v2-hub-remove-legacy-block.md")

$body = @(
  ("# CV B5I — V2 Hub: remover bloco legado duplicado — " + $stamp),
  "",
  ("Repo: " + $repoRoot),
  "",
  "## PATCH",
  ("- " + $hubRel + " (remove bloco com '" + $needle + "')"),
  "",
  "## VERIFY",
  "- cv-verify/lint/build: OK (se este script terminou sem STOP)"
) -join "`n"

WriteUtf8NoBom $rep $body
Write-Host ("[REPORT] reports\" + (Split-Path -Leaf $rep))
Write-Host "[OK] B5I concluído."