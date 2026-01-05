# CV — Guard V2 (anti-href regex + anti-import backslash)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/_bootstrap.ps1"

$repo = Get-Location
$src  = Join-Path $repo 'src'
if (-not (Test-Path -LiteralPath $src)) { throw ('[STOP] não achei src/: ' + $src) }

$files = Get-ChildItem -LiteralPath $src -Recurse -File -Include *.ts,*.tsx
$hits = @()

foreach ($f in $files) {
  $ls = Get-Content -LiteralPath $f.FullName
  $i = 0
  foreach ($ln in $ls) {
    $i++
    # 1) href regex/divisão em TSX: href={/c//v2...}
    if ($ln -like '*href={/c//*') {
      $hits += ('[href-regex] ' + $f.FullName + ':' + $i + ' — Use href={"/c/" + slug + "..."} (string), nunca regex.')
      continue
    }
    # 2) import com backslash no module specifier (ex: from "@/components/v2\V2Nav")
    $hasFrom = $ln.Contains('from "') -or $ln.Contains("from '")
    $hasAlias = $ln.Contains("@/")
    $hasBackslash = $ln.Contains("\")
    if ($hasFrom -and $hasAlias -and $hasBackslash) {
      $hits += ('[import-backslash] ' + $f.FullName + ':' + $i + ' — Use forward slash: "@/components/v2/V2Nav".')
      continue
    }
  }
}

if ($hits.Count -gt 0) {
  Write-Host '[STOP] Guard V2 falhou. Ocorrências:'
  foreach ($h in $hits) { Write-Host (' - ' + $h) }
  throw '[STOP] Corrija as ocorrências acima.'
}

Write-Host '[OK] Guard V2 passou.'