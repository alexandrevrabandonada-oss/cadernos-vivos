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

  # 1) trocar st.kind -> kind no JSX (st é unknown)
  if ($out.IndexOf("{st.kind ?") -ge 0) {
    $out = $out.Replace("{st.kind ?", "{kind ?")
    $out = $out.Replace("({st.kind})", "({kind})")
    $out = $out.Replace("st.kind", "kind") # fallback se aparecer em outro formato
  }

  # 2) garantir const kind derivado de stepObj (se ainda não existir)
  if ($out.IndexOf("const kind =") -lt 0) {
    $hrefLine = 'const href = (typeof stepObj["href"] === "string" ? String(stepObj["href"]) : (typeof stepObj["url"] === "string" ? String(stepObj["url"]) : "")) || "";'
    $pos = $out.IndexOf($hrefLine)
    if ($pos -ge 0) {
      $insertAt = $pos + $hrefLine.Length
      $kindLine = "`r`n" + '                const kind = (typeof stepObj["kind"] === "string" ? String(stepObj["kind"]) : (typeof stepObj["type"] === "string" ? String(stepObj["type"]) : "")) || "";'
      $out = $out.Substring(0, $insertAt) + $kindLine + $out.Substring($insertAt)
    } else {
      # se não achar a linha do href, tenta inserir logo após const label
      $labelNeedle = '("Etapa " + String(idx + 1));'
      $p2 = $out.IndexOf($labelNeedle)
      if ($p2 -ge 0) {
        $ins2 = $p2 + $labelNeedle.Length
        $kindLine2 = "`r`n" + '                const kind = (typeof stepObj["kind"] === "string" ? String(stepObj["kind"]) : (typeof stepObj["type"] === "string" ? String(stepObj["type"]) : "")) || "";'
        $out = $out.Substring(0, $ins2) + $kindLine2 + $out.Substring($ins2)
      }
    }
  }

  return $out
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Fix — TrilhasV2 kind (v0_114)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que foi corrigido") | Out-Null
$rep.Add("- /v2/trilhas/[id]: removido acesso a st.kind (st é unknown); agora usamos const kind derivado de stepObj.") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null
$rp = WriteReport "cv-fix-v2-trilhas-kind-unknown-v0_114.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Fix aplicado e verificado."