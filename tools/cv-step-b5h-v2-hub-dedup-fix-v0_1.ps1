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
Write-Host ("== cv-step-b5h-v2-hub-dedup-fix-v0_1 == " + $stamp)
Write-Host ("[DIAG] Repo: " + $repoRoot)

$hubRel = "src/app/c/[slug]/v2/page.tsx"
$hubAbs = Join-Path $repoRoot $hubRel
if (-not (Test-Path -LiteralPath $hubAbs)) { throw ("[STOP] não achei: " + $hubAbs) }

$bkDir = Join-Path $repoRoot "tools/_patch_backup"
if (-not (Test-Path -LiteralPath $bkDir)) { throw ("[STOP] não achei backup dir: " + $bkDir) }

$latest = Get-ChildItem -LiteralPath $bkDir -File -Filter "*-page.tsx.bak" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $latest) { throw "[STOP] não achei nenhum backup *-page.tsx.bak em tools/_patch_backup" }

Write-Host ("[DIAG] Backup escolhido: tools/_patch_backup/" + $latest.Name)

# 1) RESTORE
$bkBefore = BackupFile $hubAbs
if ($bkBefore) { Write-Host ("[BK]    tools/_patch_backup/" + (Split-Path -Leaf $bkBefore)) }

Copy-Item -LiteralPath $latest.FullName -Destination $hubAbs -Force
Write-Host ("[RESTORE] " + $hubRel + " <= " + $latest.Name)

# 2) REMOVE bloco legado (balanceado)
$lines = Get-Content -LiteralPath $hubAbs
$needle = "Explore o universo por portas"
$idxLine = -1
for ($i=0; $i -lt $lines.Count; $i++) {
  if ($lines[$i].IndexOf($needle, [StringComparison]::Ordinal) -ge 0) { $idxLine = $i; break }
}

if ($idxLine -lt 0) {
  Write-Host "[SKIP] Não encontrei o needle no Hub. Nada a deduplicar aqui."
} else {
  Write-Host ("[DIAG] Needle encontrado na linha " + ($idxLine + 1))

  $removed = $false
  $tags = @("section","div")

  for ($seek=$idxLine; $seek -ge 0; $seek--) {
    foreach ($tag in $tags) {
      $ln = $lines[$seek]

      if ($ln -match "^\s*<" + $tag + "\b" -and $ln -notmatch "^\s*</" ) {
        # ignora self-closing
        if ($ln -match "<" + $tag + "\b[^>]*\/>\s*$") { continue }

        $depth = 0
        $end = -1

        for ($j=$seek; $j -lt $lines.Count; $j++) {
          $depth += (Get-DeltaForTag $lines[$j] $tag)
          if ($j -eq $seek -and $depth -le 0) {
            # abertura que não criou bloco (provável <div> ... </div> na mesma linha) -> pula
            $end = -1
            break
          }
          if ($depth -eq 0 -and $j -gt $seek) { $end = $j; break }
        }

        if ($end -gt $seek) {
          # garante que o bloco realmente contém o needle
          $blockText = ($lines[$seek..$end] -join "`n")
          if ($blockText.IndexOf($needle, [StringComparison]::Ordinal) -lt 0) { continue }

          Write-Host ("[DIAG] Removendo bloco <" + $tag + "> linhas " + ($seek+1) + " .. " + ($end+1))

          $head = @()
          if ($seek -gt 0) { $head = $lines[0..($seek-1)] }

          $tail = @()
          if ($end -lt ($lines.Count-1)) { $tail = $lines[($end+1)..($lines.Count-1)] }

          $marker = ("      {/* CV2_LEGACY_HUB_REMOVIDO " + $stamp + " */}")
          $lines = @()
          if ($head.Count -gt 0) { $lines += $head }
          $lines += $marker
          if ($tail.Count -gt 0) { $lines += $tail }

          $removed = $true
          break
        }
      }
    }
    if ($removed) { break }
  }

  if (-not $removed) {
    throw "[STOP] Achei o needle mas não consegui remover um bloco balanceado (<section>/<div>)."
  }

  WriteUtf8NoBom $hubAbs ($lines -join "`n")
  Write-Host ("[PATCH] " + $hubRel + " (dedup balanceado ok)")
}

# 3) VERIFY
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

# 4) REPORT
$repDir = Join-Path $repoRoot "reports"
EnsureDir $repDir
$rep = Join-Path $repDir ($stamp + "-cv-step-b5h-v2-hub-dedup-fix.md")

$body = @(
  ("# CV B5H — V2 Hub dedup FIX (restore + remove balanceado) — " + $stamp),
  "",
  ("Repo: " + $repoRoot),
  "",
  "## PATCH",
  ("- restore: tools/_patch_backup/" + $latest.Name + " -> " + $hubRel),
  ("- remove legacy: needle '" + $needle + "' (bloco balanceado section/div)"),
  "",
  "## VERIFY",
  "- cv-verify/lint/build: OK (se este script terminou sem STOP)"
) -join "`n"

WriteUtf8NoBom $rep $body
Write-Host ("[REPORT] reports\" + (Split-Path -Leaf $rep))
Write-Host "[OK] B5H concluído."