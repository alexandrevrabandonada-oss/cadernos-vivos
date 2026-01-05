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

$rel = "src\components\v2\TrilhasV2.tsx"

PatchText $rel {
  param($s)
  $out = $s

  # Remove anotação de retorno que depende do namespace global JSX
  if ($out.IndexOf("): JSX.Element {") -ge 0) {
    $out = $out.Replace("): JSX.Element {", ") {")
  }

  # Fallback: se houver "):JSX.Element{" sem espaços
  if ($out.IndexOf("):JSX.Element{") -ge 0) {
    $out = $out.Replace("):JSX.Element{", "){")
  }

  # Se existir outras ocorrências "JSX.Element" em tipos, troca por "unknown" (super seguro)
  if ($out.IndexOf("JSX.Element") -ge 0) {
    $out = $out.Replace("JSX.Element", "unknown")
  }

  return $out
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Fix — TrilhasV2 JSX namespace (v0_115)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que foi corrigido") | Out-Null
$rep.Add("- Removido retorno `JSX.Element` (namespace JSX não disponível no build); TS infere o tipo.") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null
$rp = WriteReport "cv-fix-trilhasv2-jsx-namespace-v0_115.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Fix aplicado e verificado."