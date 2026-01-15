param([string]$Path)
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"

function PickLatest([string]$dir){
  $f = Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue |
       Where-Object { $_.Name -like "*cv-runner*.md" } |
       Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if($null -eq $f){ return $null }
  return $f.FullName
}

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$reports = Join-Path $root "reports"
if([string]::IsNullOrWhiteSpace($Path)){
  $Path = PickLatest $reports
} else {
  if(-not (Test-Path -LiteralPath $Path)){
    $try = Join-Path $root $Path
    if(Test-Path -LiteralPath $try){ $Path = $try }
  }
}

if([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)){
  throw "Report não encontrado. Passe -Path ou confira a pasta reports/."
}

Write-Host ("[REPORT] " + $Path)
$raw = Get-Content -LiteralPath $Path -Raw
$arr = $raw -split "`r?`n"

Write-Host ""
Write-Host "==== ERROS (linhas com [ERR]/TIMEOUT/NO-OUTPUT/exit) ===="
$hits = New-Object System.Collections.Generic.List[int]
for($i=0;$i -lt $arr.Length;$i++){
  $s = $arr[$i]
  if($s -match "\[ERR\]" -or $s -match "TIMEOUT" -or $s -match "NO-OUTPUT" -or $s -match "exit:"){
    $hits.Add($i) | Out-Null
  }
}
if($hits.Count -eq 0){ Write-Host "(nenhuma linha de erro encontrada pelo filtro)"; }
foreach($ix in $hits){
  $a = [Math]::Max(0, $ix-3)
  $b = [Math]::Min($arr.Length-1, $ix+6)
  Write-Host ""
  Write-Host ("-- contexto linhas " + $a + " a " + $b + " --")
  for($j=$a;$j -le $b;$j++){ Write-Host $arr[$j] }
}

function PrintSection([string]$title,[string]$startPattern){
  Write-Host ""
  Write-Host ("==== " + $title + " (últimas ~120 linhas) ====")
  $idx = -1
  for($i=0;$i -lt $arr.Length;$i++){ if($arr[$i] -match $startPattern){ $idx = $i } }
  if($idx -lt 0){ Write-Host "(seção não encontrada)"; return }
  $from = [Math]::Max(0, $idx)
  $to = [Math]::Min($arr.Length-1, $idx+240)
  $slice = $arr[$from..$to]
  $tailFrom = [Math]::Max(0, $slice.Length-120)
  for($k=$tailFrom;$k -lt $slice.Length;$k++){ Write-Host $slice[$k] }
}

PrintSection "LINT" "### npm run lint"
PrintSection "BUILD" "### npm run build"

Write-Host ""
Write-Host "==== FIM DIGEST ===="