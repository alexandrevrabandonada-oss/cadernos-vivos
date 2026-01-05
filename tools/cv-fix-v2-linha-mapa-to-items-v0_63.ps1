$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Write-Host ("[DIAG] Repo: " + $repo)

. (Join-Path $PSScriptRoot "_bootstrap.ps1")

$changed = New-Object System.Collections.Generic.List[string]

function PatchText([string]$rel, [scriptblock]$mutate) {
  $fullp = Join-Path $repo $rel
  if (!(Test-Path -LiteralPath $fullp)) { throw ("[STOP] nao achei: " + $fullp) }
  $raw = Get-Content -LiteralPath $fullp -Raw
  if ($null -eq $raw) { throw ("[STOP] leitura nula: " + $fullp) }

  $next = & $mutate $raw
  if ($null -eq $next) { throw "[STOP] mutate retornou null" }

  if ($next -ne $raw) {
    $bk = BackupFile $fullp
    WriteUtf8NoBom $fullp $next
    Write-Host ("[OK] patched: " + $fullp)
    Write-Host ("[BK] " + $bk)
    $script:changed.Add($fullp) | Out-Null
  } else {
    Write-Host ("[OK] sem mudanca: " + $fullp)
  }
}

$rel = "src\app\c\[slug]\v2\linha\page.tsx"

PatchText $rel {
  param($raw)

  $s = $raw

  if ($s.IndexOf("TimelineV2") -lt 0) { throw "[STOP] nao achei TimelineV2 na pagina /v2/linha" }
  if ($s.IndexOf("export default") -lt 0) { throw "[STOP] nao achei export default na pagina /v2/linha" }

  # 1) Inserir helper itemsFromMapa antes do export default (se ainda nao tiver)
  if ($s.IndexOf("function itemsFromMapa(") -lt 0) {
    $idx = $s.IndexOf("export default")
    if ($idx -lt 0) { throw "[STOP] export default index invalido" }

    $helper = @(
      'type AnyObj = Record<string, unknown>;',
      '',
      'function isObj(v: unknown): v is AnyObj {',
      '  return !!v && typeof v === "object" && !Array.isArray(v);',
      '}',
      '',
      'function itemsFromMapa(mapa: unknown): unknown[] {',
      '  if (!mapa) return [];',
      '  if (Array.isArray(mapa)) return mapa as unknown[];',
      '  if (isObj(mapa)) {',
      '    const t = (mapa as AnyObj)["timeline"];',
      '    if (Array.isArray(t)) return t as unknown[];',
      '    const it = (mapa as AnyObj)["items"];',
      '    if (Array.isArray(it)) return it as unknown[];',
      '    const n = (mapa as AnyObj)["nodes"];',
      '    if (Array.isArray(n)) return n as unknown[];',
      '  }',
      '  return [];',
      '}',
      '',
      ''
    ) -join "`r`n"

    $s = $s.Substring(0, $idx) + $helper + $s.Substring($idx)
  }

  # 2) Criar const items = ... antes do return (se ainda nao tiver)
  if ($s.IndexOf("const items = itemsFromMapa(") -lt 0) {
    $m = [regex]::Match($s, "(\r?\n\s*)return\s*\(")
    if (!$m.Success) { throw "[STOP] nao achei return( ) para inserir const items" }

    $insertPos = $m.Index
    $ins = "`r`n  const items = itemsFromMapa(mapa as unknown);`r`n"
    $s = $s.Substring(0, $insertPos) + $ins + $s.Substring($insertPos)
  }

  # 3) Trocar prop mapa -> items no <TimelineV2 ... />
  if ($s.Contains("mapa={mapa as unknown as JsonValue}")) {
    $s = $s.Replace("mapa={mapa as unknown as JsonValue}", "items={items}")
  } elseif ($s.Contains(" mapa={")) {
    $s = [regex]::Replace(
      $s,
      "<TimelineV2([^>]*?)\smapa=\{[^}]+\}([^>]*?)\/>",
      "<TimelineV2$1 items={items}$2 />"
    )
  }

  return $s
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Fix — /v2/linha mapa -> items (v0_63)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que foi corrigido") | Out-Null
$rep.Add("- /v2/linha: calcula items a partir de mapa e passa items para TimelineV2 (sem any).") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null

$rp = WriteReport "cv-fix-v2-linha-mapa-to-items-v0_63.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Fix aplicado e verificado."