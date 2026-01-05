# CV — Guard V2 (anti-regex href + anti-import backslash)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/_bootstrap.ps1"

$repo = Get-Location
$src  = Join-Path $repo 'src'
if (-not (Test-Path -LiteralPath $src)) { throw ('[STOP] não achei src/: ' + $src) }

$patterns = @(
  @{ Name = 'href-regex'; Regex = 'href=\{\/c\/\/'; Hint = 'Use href={"/c/" + slug + "..."} (string), nunca regex.' },
  @{ Name = 'import-backslash-dq'; Regex = 'from\s+"@\/[^"\r\n]*\\'; Hint = 'Use forward slash em module specifier: "@/components/v2/V2Nav".' },
  @{ Name = 'import-backslash-sq'; Regex = "from\s+'@\/[^'\r\n]*\\"; Hint = 'Use forward slash em module specifier: "@/components/v2/V2Nav".' }
)

$hits = @()
$files = Get-ChildItem -LiteralPath $src -Recurse -File -Include *.ts,*.tsx
foreach ($f in $files) {
  $t = Get-Content -LiteralPath $f.FullName -Raw
  foreach ($p in $patterns) {
    if ($t -match $p.Regex) {
      $hits += ('[' + $p.Name + '] ' + $f.FullName + ' — ' + $p.Hint)
      break
    }
  }
}

if ($hits.Count -gt 0) {
  Write-Host '[STOP] Guard V2 falhou. Ocorrências:'
  foreach ($h in $hits) { Write-Host (' - ' + $h) }
  throw '[STOP] Corrija as ocorrências acima.'
}

Write-Host '[OK] Guard V2 passou.'