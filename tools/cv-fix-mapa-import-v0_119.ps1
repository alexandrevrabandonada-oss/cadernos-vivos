$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Write-Host ("[DIAG] Repo: " + $repo)

. (Join-Path $PSScriptRoot "_bootstrap.ps1")

$changed = New-Object System.Collections.Generic.List[string]

function PatchText([string]$rel, [scriptblock]$mutate) {
  $fp = Join-Path $repo $rel
  if (!(Test-Path -LiteralPath $fp)) {
    Write-Host ("[SKIP] nao achei: " + $fp)
    return
  }
  $raw = Get-Content -LiteralPath $fp -Raw
  if ($null -eq $raw) { throw ("[STOP] leitura nula: " + $fp) }
  $next = & $mutate $raw
  if ($null -eq $next) { throw "[STOP] mutate retornou null" }

  if ($next -ne $raw) {
    $bk = BackupFile $fp
    WriteUtf8NoBom $fp $next
    Write-Host ("[OK] patched: " + $fp)
    Write-Host ("[BK] " + $bk)
    $script:changed.Add($fp) | Out-Null
  } else {
    Write-Host ("[OK] sem mudanca: " + $fp)
  }
}

$rel = 'src\app\c\[slug]\v2\mapa\page.tsx'

PatchText $rel {
  param($s)
  $out = $s

  # 1) Corrige caminho duplicado "...InteractiveInteractive"
  if ($out.IndexOf('MapaV2InteractiveInteractive') -ge 0) {
    $out = $out.Replace('MapaV2InteractiveInteractive', 'MapaV2Interactive')
  }

  # 2) Garante default import (sem chaves)
  if ($out -match 'import\s*\{\s*MapaV2Interactive\s*\}\s*from\s*"@/components/v2/MapaV2Interactive";') {
    $out = [regex]::Replace(
      $out,
      'import\s*\{\s*MapaV2Interactive\s*\}\s*from\s*"@/components/v2/MapaV2Interactive";',
      'import MapaV2Interactive from "@/components/v2/MapaV2Interactive";',
      1
    )
  }

  # 3) Caso tenha import bizarro com path errado ainda (alias do erro)
  if ($out -match 'import\s*\{\s*MapaV2Interactive\s*\}\s*from\s*"@/components/v2/MapaV2Interactive";' -eq $false) {
    if ($out -match 'import\s*\{\s*MapaV2Interactive\s*\}\s*from\s*"@/components/v2/MapaV2Interactive";') {
      # nada
    } else {
      # Se existir "import ... from "@/components/v2/MapaV2Interactive";" como named, troca.
      if ($out -match 'import\s*\{\s*MapaV2Interactive\s*\}\s*from\s*"@/components/v2/MapaV2Interactive";') {
        # nada
      }
    }
  }

  # 4) Se por algum motivo virou "import { MapaV2Interactive } from ...MapaV2Interactive"
  if ($out -match 'import\s*\{\s*MapaV2Interactive\s*\}\s*from\s*"@/components/v2/MapaV2Interactive";') {
    $out = [regex]::Replace(
      $out,
      'import\s*\{\s*MapaV2Interactive\s*\}\s*from\s*"@/components/v2/MapaV2Interactive";',
      'import MapaV2Interactive from "@/components/v2/MapaV2Interactive";',
      1
    )
  }

  # 5) Se ainda sobrou import com chaves mas path ok, conserta também
  if ($out -match 'import\s*\{\s*MapaV2Interactive\s*\}\s*from\s*"@/components/v2/MapaV2Interactive";') {
    $out = [regex]::Replace(
      $out,
      'import\s*\{\s*MapaV2Interactive\s*\}\s*from\s*"@/components/v2/MapaV2Interactive";',
      'import MapaV2Interactive from "@/components/v2/MapaV2Interactive";',
      1
    )
  }

  # 6) Se o import atual for do tipo "import { MapaV2Interactive } from "@/components/v2/MapaV2InteractiveInteractive";"
  if ($out -match 'import\s*\{\s*MapaV2Interactive\s*\}\s*from\s*"@/components/v2/MapaV2Interactive";') {
    # ok
  }

  return $out
}

# VERIFY
$verify = Join-Path $repo 'tools\cv-verify.ps1'
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add('# CV — FIX — /v2/mapa import MapaV2Interactive (v0_119)') | Out-Null
$rep.Add('') | Out-Null
$rep.Add('## O que foi corrigido') | Out-Null
$rep.Add('- Ajuste de import no /c/[slug]/v2/mapa para apontar para "@/components/v2/MapaV2Interactive" (sem duplicar Interactive).') | Out-Null
$rep.Add('- Troca para default import (MapaV2Interactive é export default).') | Out-Null
$rep.Add('') | Out-Null
$rep.Add('## Arquivos alterados') | Out-Null
foreach ($f in $changed) { $rep.Add('- ' + $f) | Out-Null }
$rep.Add('') | Out-Null
$rep.Add('## Verify') | Out-Null
$rep.Add('- tools/cv-verify.ps1 (guard + lint + build)') | Out-Null
$rp = WriteReport 'cv-fix-mapa-import-v0_119.md' ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host '[OK] FIX aplicado e verificado.'