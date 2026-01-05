$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Write-Host ("[DIAG] Repo: " + $repo)

. (Join-Path $PSScriptRoot "_bootstrap.ps1")

$changed = New-Object System.Collections.Generic.List[string]

function PatchText([string]$rel, [scriptblock]$mutate) {
  $full = Join-Path $repo $rel
  if (!(Test-Path -LiteralPath $full)) {
    Write-Host ("[SKIP] nao achei: " + $full)
    return
  }
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

# 1) HomeV2Hub: aceitar mapa/stats opcionais (compat com v2/page.tsx)
PatchText "src\components\v2\HomeV2Hub.tsx" {
  param($s)
  $out = $s

  # caso A: export default function HomeV2Hub(props: { slug: string; title: string; })
  $out2 = [regex]::Replace(
    $out,
    'export\s+default\s+function\s+HomeV2Hub\s*\(\s*props\s*:\s*\{\s*slug\s*:\s*string\s*;\s*title\s*:\s*string\s*;?\s*\}\s*\)',
    'export default function HomeV2Hub(props: { slug: string; title: string; mapa?: unknown; stats?: unknown })'
  )
  $out = $out2

  # caso B: export default function HomeV2Hub({ slug, title }: { slug: string; title: string; })
  $out2 = [regex]::Replace(
    $out,
    'export\s+default\s+function\s+HomeV2Hub\s*\(\s*\{\s*slug\s*,\s*title\s*\}\s*:\s*\{\s*slug\s*:\s*string\s*;\s*title\s*:\s*string\s*;?\s*\}\s*\)',
    'export default function HomeV2Hub({ slug, title, mapa, stats }: { slug: string; title: string; mapa?: unknown; stats?: unknown })'
  )
  $out = $out2

  # se for o caso B e o arquivo ainda referencia props., não quebra — mas ao menos tipa
  return $out
}

# 2) /c/[slug]/page.tsx: usar uiDefault + redirect (remove warnings e ativa default=v2)
PatchText "src\app\c\[slug]\page.tsx" {
  param($s)
  $out = $s

  if ($out.IndexOf('uiDefault === "v2"') -ge 0 -and $out.IndexOf("redirect(") -ge 0) {
    return $out
  }

  $idx = $out.IndexOf("const uiDefault")
  if ($idx -lt 0) { return $out }

  $semi = $out.IndexOf(";", $idx)
  if ($semi -lt 0) { return $out }

  $nl = $out.IndexOf("`n", $semi)
  if ($nl -lt 0) { $nl = $semi }

  $ins = @"
  if (uiDefault === "v2") {
    redirect("/c/" + slug + "/v2");
  }

"@

  return ($out.Substring(0, $nl + 1) + $ins + $out.Substring($nl + 1))
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Fix — HomeV2Hub props + /c/[slug] redirect (v0_95)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que foi corrigido") | Out-Null
$rep.Add("- HomeV2Hub agora aceita mapa/stats opcionais (evita erro de props em /v2/page).") | Out-Null
$rep.Add("- /c/[slug] agora usa uiDefault e redirect quando default=v2 (remove warnings).") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null

$rp = WriteReport "cv-fix-homev2hub-props-and-slug-redirect-v0_95.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Fix aplicado e verificado."