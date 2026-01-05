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

# ---------------------------
# 1) /v2/debate/page.tsx — remover "as any"
# ---------------------------
PatchText "src\app\c\[slug]\v2\debate\page.tsx" {
  param($s)
  $out = $s

  # troca padrões comuns
  $out = $out.Replace('active={"debate" as any}', 'active="debate"')
  $out = $out.Replace("active={'debate' as any}", 'active="debate"')
  $out = $out.Replace('active={"debate" as unknown as any}', 'active="debate"')

  # fallback via regex (bem tolerante)
  $out = [regex]::Replace($out, 'active=\{\s*["'']debate["'']\s+as\s+any\s*\}', 'active="debate"')
  return $out
}

# ---------------------------
# 2) V2Nav.tsx — aceitar "debate" no tipo do active (quando existir union)
# ---------------------------
PatchText "src\components\v2\V2Nav.tsx" {
  param($s)
  $out = $s
  if ($out.IndexOf('"debate"') -ge 0) { return $out }

  $lines = $out -split "`r`n"
  $changedLocal = $false

  for ($i = 0; $i -lt $lines.Length; $i++) {
    $ln = $lines[$i]
    # pega linha de tipo/props que contém active e já tem "trilhas"
    if ($ln -match '\bactive\b' -and $ln -match '"trilhas"' -and $ln -notmatch '"debate"') {
      $lines[$i] = $ln.Replace('"trilhas"', '"trilhas" | "debate"')
      $changedLocal = $true
      break
    }
  }

  if ($changedLocal) { return ($lines -join "`r`n") }
  return $out
}

# ---------------------------
# 3) /c/[slug]/page.tsx — usar uiDefault + redirect (remove warnings)
# ---------------------------
PatchText "src\app\c\[slug]\page.tsx" {
  param($s)
  $out = $s

  # se já existe bloco, não mexe
  if ($out.IndexOf('uiDefault === "v2"') -ge 0 -and $out.IndexOf('redirect("/c/" + slug + "/v2")') -ge 0) {
    return $out
  }

  # garante que redirect está importado de next/navigation
  if ($out -match 'from\s+"next/navigation";') {
    # se tem import { ... } from "next/navigation";
    if ($out -match 'import\s*\{\s*[^}]*\s*\}\s*from\s*"next/navigation";') {
      $out = [regex]::Replace($out,
        'import\s*\{\s*([^}]*)\}\s*from\s*"next/navigation";',
        {
          param($m)
          $inner = $m.Groups[1].Value
          if ($inner -match '\bredirect\b') { return $m.Value }
          $inner2 = $inner.Trim()
          if ($inner2.Length -gt 0 -and !$inner2.Trim().EndsWith(",")) { $inner2 = $inner2 + "," }
          return ('import { ' + $inner2 + ' redirect } from "next/navigation";')
        }
      )
    } else {
      # tem from "next/navigation" mas não no formato acima — adiciona import simples no topo
      $out = "import { redirect } from ""next/navigation"";`r`n" + $out
    }
  } else {
    $out = "import { redirect } from ""next/navigation"";`r`n" + $out
  }

  # insere bloco logo após "const uiDefault = ...;"
  $m = [regex]::Match($out, 'const\s+uiDefault\s*=\s*[^;]+;\s*')
  if (!$m.Success) { return $out }

  $pos = $m.Index + $m.Length
  $block = @(
    'if (uiDefault === "v2") {',
    '  redirect("/c/" + slug + "/v2");',
    '}',
    ''
  ) -join "`r`n"

  return ($out.Substring(0, $pos) + "`r`n" + $block + $out.Substring($pos))
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Fix — D2 lint (v0_102)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que foi corrigido") | Out-Null
$rep.Add("- Removeu explicit-any no /v2/debate (active=""debate"").") | Out-Null
$rep.Add("- V2Nav passa a aceitar ""debate"" no tipo do active (quando houver union).") | Out-Null
$rep.Add("- /c/[slug] usa uiDefault+redirect quando v2 (remove warnings).") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null
$rp = WriteReport "cv-fix-d2-lint-v0_102.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Fix aplicado e verificado."