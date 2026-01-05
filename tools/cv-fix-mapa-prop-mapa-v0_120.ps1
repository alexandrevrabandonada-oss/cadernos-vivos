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

# 1) MapaV2Interactive: aceitar mapa?: unknown e repassar para MapaV2Client
$rel1 = 'src\components\v2\MapaV2Interactive.tsx'
PatchText $rel1 {
  param($s)
  $out = $s

  # a) amplia tipo do props
  if ($out -match 'props:\s*\{\s*slug:\s*string;\s*title\?:\s*string\s*\}') {
    $out = [regex]::Replace(
      $out,
      'props:\s*\{\s*slug:\s*string;\s*title\?:\s*string\s*\}',
      'props: { slug: string; title?: string; mapa?: unknown }',
      1
    )
  }

  # b) destrutura mapa se existir destruturação padrão
  if ($out -match 'const\s*\{\s*slug\s*,\s*title\s*\}\s*=\s*props;') {
    $out = [regex]::Replace(
      $out,
      'const\s*\{\s*slug\s*,\s*title\s*\}\s*=\s*props;',
      'const { slug, title, mapa } = props;',
      1
    )
  } elseif (($out -match 'const\s*\{\s*slug\s*\}\s*=\s*props;') -and ($out -notmatch '\bmapa\b')) {
    # se só pega slug, tenta inserir mapa e title (sem estragar)
    $out = [regex]::Replace(
      $out,
      'const\s*\{\s*slug\s*\}\s*=\s*props;',
      'const { slug, title, mapa } = props;',
      1
    )
  }

  # c) repassar mapa para o client component se existir <MapaV2Client ... />
  if ($out -match '<MapaV2Client' -and $out -notmatch '\bmapa=\{mapa\}') {
    # tenta achar a primeira ocorrência e inserir mapa={mapa} antes do fechamento
    $out = [regex]::Replace(
      $out,
      '<MapaV2Client([^>]*)\/>',
      '<MapaV2Client$1 mapa={mapa} />',
      1
    )
  }

  return $out
}

# 2) (segurança) MapaV2Client: aceitar mapa?: unknown caso ainda não aceite
$rel2 = 'src\components\v2\MapaV2Client.tsx'
PatchText $rel2 {
  param($s)
  $out = $s

  if ($out -match 'props:\s*\{\s*slug:\s*string;\s*title\?:\s*string\s*\}') {
    $out = [regex]::Replace(
      $out,
      'props:\s*\{\s*slug:\s*string;\s*title\?:\s*string\s*\}',
      'props: { slug: string; title?: string; mapa?: unknown }',
      1
    )
  }

  if ($out -match 'function\s+MapaV2Client\s*\(\s*props:\s*\{\s*slug:\s*string;\s*title\?:\s*string\s*\}\s*\)') {
    $out = [regex]::Replace(
      $out,
      'function\s+MapaV2Client\s*\(\s*props:\s*\{\s*slug:\s*string;\s*title\?:\s*string\s*\}\s*\)',
      'function MapaV2Client(props: { slug: string; title?: string; mapa?: unknown })',
      1
    )
  }

  return $out
}

# VERIFY
$verify = Join-Path $repo 'tools\cv-verify.ps1'
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add('# CV — FIX — MapaV2Interactive prop mapa (v0_120)') | Out-Null
$rep.Add('') | Out-Null
$rep.Add('## O que foi corrigido') | Out-Null
$rep.Add('- MapaV2Interactive agora aceita mapa?: unknown e repassa para MapaV2Client (evita erro de tipo no build).') | Out-Null
$rep.Add('- MapaV2Client também aceita mapa?: unknown (segurança).') | Out-Null
$rep.Add('') | Out-Null
$rep.Add('## Arquivos alterados') | Out-Null
foreach ($f in $changed) { $rep.Add('- ' + $f) | Out-Null }
$rep.Add('') | Out-Null
$rep.Add('## Verify') | Out-Null
$rep.Add('- tools/cv-verify.ps1 (guard + lint + build)') | Out-Null
$rp = WriteReport 'cv-fix-mapa-prop-mapa-v0_120.md' ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host '[OK] FIX aplicado e verificado.'