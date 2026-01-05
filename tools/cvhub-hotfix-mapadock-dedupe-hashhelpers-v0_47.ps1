$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Write-Host ("[DIAG] Repo: " + $repo)

. (Join-Path $PSScriptRoot "_bootstrap.ps1")

$file = Join-Path $repo "src\components\v2\MapaDockV2.tsx"
if (-not (Test-Path -LiteralPath $file)) { throw ("[STOP] nao achei: " + $file) }
Write-Host ("[DIAG] File: " + $file)

function CountChar($s, [char]$ch) {
  $n = 0
  foreach ($c in $s.ToCharArray()) { if ($c -eq $ch) { $n++ } }
  return $n
}

function FindFuncBlocks($lines, $funcName) {
  $hits = New-Object System.Collections.Generic.List[object]
  for ($i=0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match ("^\s*function\s+" + [regex]::Escape($funcName) + "\s*\(")) {
      # achar inicio do bloco (primeira chave "{")
      $j = $i
      $seenOpen = $false
      $depth = 0
      $end = $i

      for (; $j -lt $lines.Count; $j++) {
        $ln = $lines[$j]
        $open = CountChar $ln '{'
        $close = CountChar $ln '}'

        if ($open -gt 0) { $seenOpen = $true }
        if ($seenOpen) { $depth += ($open - $close) }

        if ($seenOpen -and $depth -le 0) { $end = $j; break }
      }

      $hits.Add([pscustomobject]@{ Start=$i; End=$end }) | Out-Null
      $i = $end
    }
  }
  return $hits
}

$raw = Get-Content -LiteralPath $file -Raw
$lines = New-Object System.Collections.Generic.List[string]
foreach ($ln in ($raw -split "`r?`n")) { $lines.Add($ln) | Out-Null }

$targets = @("readHashId","setHashId","useHashId")
$toRemove = New-Object System.Collections.Generic.List[object]

foreach ($fn in $targets) {
  $blocks = FindFuncBlocks $lines $fn
  if ($blocks.Count -gt 1) {
    Write-Host ("[DIAG] " + $fn + ": " + $blocks.Count + " defs (vai manter 1, remover " + ($blocks.Count-1) + ")")
    for ($k=1; $k -lt $blocks.Count; $k++) { $toRemove.Add([pscustomobject]@{ Fn=$fn; Start=$blocks[$k].Start; End=$blocks[$k].End }) | Out-Null }
  } else {
    Write-Host ("[OK] " + $fn + ": " + $blocks.Count + " def")
  }
}

if ($toRemove.Count -eq 0) {
  Write-Host "[OK] Nada para deduplicar."
} else {
  # remover de baixo pra cima pra nao baguncar indices
  $sorted = $toRemove | Sort-Object Start -Descending
  $bk = BackupFile $file

  foreach ($r in $sorted) {
    Write-Host ("[FIX] removendo dup: " + $r.Fn + " linhas " + $r.Start + ".." + $r.End)
    $count = ($r.End - $r.Start + 1)
    $lines.RemoveRange($r.Start, $count)
  }

  WriteUtf8NoBom $file ($lines -join "`n")
  Write-Host ("[OK] patched: " + $file)
  if ($bk) { Write-Host ("[BK] " + $bk) }
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = @()
$rep += "# CV — Hotfix v0_47 — Dedupe hash helpers no MapaDockV2"
$rep += ""
$rep += "## Causa"
$rep += "- Funcoes readHashId/setHashId/useHashId ficaram definidas mais de uma vez no MapaDockV2.tsx, quebrando o build."
$rep += ""
$rep += "## Fix"
$rep += "- Remove duplicatas e mantem apenas a primeira definicao de cada helper."
$rep += ""
$rep += "## Arquivo"
$rep += "- src/components/v2/MapaDockV2.tsx"
$rep += ""
$rep += "## Verify"
$rep += "- tools/cv-verify.ps1 (guard + lint + build)"
$rep += ""

$rp = WriteReport "cv-hotfix-mapadock-dedupe-hashhelpers-v0_47.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Hotfix v0_47 aplicado e verificado."