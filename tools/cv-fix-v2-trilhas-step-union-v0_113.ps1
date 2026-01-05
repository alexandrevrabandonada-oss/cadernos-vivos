$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Write-Host ("[DIAG] Repo: " + $repo)

. (Join-Path $PSScriptRoot "_bootstrap.ps1")

$changed = New-Object System.Collections.Generic.List[string]

function PatchText([string]$rel, [scriptblock]$mutate) {
  $fp = Join-Path $repo $rel
  if (!(Test-Path -LiteralPath $fp)) { throw ("[STOP] nao achei: " + $fp) }
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

$rel = "src\app\c\[slug]\v2\trilhas\[id]\page.tsx"

PatchText $rel {
  param($s)
  $out = $s

  # 1) map: garantir array + tratar como unknown[]
  $out = [regex]::Replace(
    $out,
    '\{trail\.steps\.map\(\(st,\s*idx\)\s*=>\s*\{',
    '{(Array.isArray(trail.steps) ? (trail.steps as unknown[]) : []).map((st, idx) => {'
  )

  # 2) substituir acesso direto st.title por normalização segura (cria stepObj/stepId/label)
  $needleLabel = 'const label = st.title || ("Etapa " + String(idx + 1));'
  if ($out.IndexOf($needleLabel) -ge 0) {
    $block = @(
      '                const stepObj: Record<string, unknown> =',
      '                  (typeof st === "string" || typeof st === "number" || typeof st === "boolean")',
      '                    ? { title: String(st) }',
      '                    : ((st as unknown as Record<string, unknown>) || {});',
      '                const stepId = (typeof stepObj["id"] === "string" && stepObj["id"]) ? String(stepObj["id"]) : "etapa";',
      '                const label =',
      '                  ((typeof stepObj["title"] === "string" && stepObj["title"]) ? String(stepObj["title"]) : "") ||',
      '                  ((typeof stepObj["label"] === "string" && stepObj["label"]) ? String(stepObj["label"]) : "") ||',
      '                  ("Etapa " + String(idx + 1));'
    ) -join "`r`n"
    $out = $out.Replace($needleLabel, $block)
  }

  # 3) href: evitar st.href quando st for string
  $needleHref = 'const href = st.href || "";'
  if ($out.IndexOf($needleHref) -ge 0) {
    $hrefLine = '                const href = (typeof stepObj["href"] === "string" ? String(stepObj["href"]) : (typeof stepObj["url"] === "string" ? String(stepObj["url"]) : "")) || "";'
    $out = $out.Replace($needleHref, $hrefLine)
  }

  # 4) key: evitar st.id quando st for string
  $needleKey = 'key={(st.id || "etapa") + "-" + String(idx)}'
  if ($out.IndexOf($needleKey) -ge 0) {
    $out = $out.Replace($needleKey, 'key={(stepId + "-" + String(idx))}')
  }

  return $out
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Fix — TrilhasV2 [id] TrailStep union (v0_113)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que foi corrigido") | Out-Null
$rep.Add("- /v2/trilhas/[id]: steps pode ser string; normalizamos stepObj e derivamos stepId/label/href com segurança.") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null
$rp = WriteReport "cv-fix-v2-trilhas-step-union-v0_113.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Fix aplicado e verificado."