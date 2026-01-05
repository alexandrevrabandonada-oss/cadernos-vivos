$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Write-Host ("[DIAG] Repo: " + $repo)

. (Join-Path $PSScriptRoot "_bootstrap.ps1")

$changed = New-Object System.Collections.Generic.List[string]

function PatchText([string]$rel, [scriptblock]$mutate) {
  $full = Join-Path $repo $rel
  if (!(Test-Path -LiteralPath $full)) { throw ("[STOP] nao achei: " + $full) }
  $raw = Get-Content -LiteralPath $full -Raw
  if ($null -eq $raw) { throw ("[STOP] leitura nula: " + $full) }

  $next = & $mutate $raw
  if ($null -eq $next) { throw "[STOP] mutate retornou null" }

  if ($next -ne $raw) {
    $bk = BackupFile $full
    WriteUtf8NoBom $full $next
    Write-Host ("[OK] patched: " + $full)
    Write-Host ("[BK] " + $bk)
    $script:changed.Add($full) | Out-Null
  } else {
    Write-Host ("[OK] sem mudanca: " + $full)
  }
}

$rel = "src\components\v2\MapaV2.tsx"

PatchText $rel {
  param($raw)
  $s = $raw

  # 1) garantir idx no map (tanto no bloco hasXY quanto no bloco grid)
  $s = $s.Replace("{nodes.map((n) => {", "{nodes.map((n, idx) => {")

  # 2) remover Math.random do render: fallback determinístico por idx
  $oldLeft = 'const left = typeof n.x === "number" ? n.x : 40 + (Math.random() * 40);'
  $oldTop  = 'const top = typeof n.y === "number" ? n.y : 40 + (Math.random() * 40);'

  $newLeft = 'const left = typeof n.x === "number" ? n.x : 40 + ((idx % 5) * 240);'
  $newTop  = 'const top = typeof n.y === "number" ? n.y : 40 + (Math.floor(idx / 5) * 120);'

  if ($s.IndexOf($oldLeft) -ge 0) { $s = $s.Replace($oldLeft, $newLeft) }
  else {
    # fallback regex (caso tenha mudado espaçamento)
    $s = [regex]::Replace($s, 'const\s+left\s*=\s*typeof\s+n\.x\s*===\s*"number"\s*\?\s*n\.x\s*:\s*40\s*\+\s*\(Math\.random\(\)\s*\*\s*40\)\s*;', $newLeft)
  }

  if ($s.IndexOf($oldTop) -ge 0) { $s = $s.Replace($oldTop, $newTop) }
  else {
    $s = [regex]::Replace($s, 'const\s+top\s*=\s*typeof\s+n\.y\s*===\s*"number"\s*\?\s*n\.y\s*:\s*40\s*\+\s*\(Math\.random\(\)\s*\*\s*40\)\s*;', $newTop)
  }

  return $s
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Fix — MapaV2 sem Math.random (v0_73)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que foi corrigido") | Out-Null
$rep.Add("- Removeu Math.random do render (eslint react-hooks/purity).") | Out-Null
$rep.Add("- Fallback de posicao agora e deterministico via idx (grid simples).") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null

$rp = WriteReport "cv-fix-mapav2-no-random-v0_73.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Fix aplicado e verificado."