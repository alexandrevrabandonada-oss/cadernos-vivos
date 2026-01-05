$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Write-Host ("[DIAG] Repo: " + $repo)

. (Join-Path $PSScriptRoot "_bootstrap.ps1")

$changed = New-Object System.Collections.Generic.List[string]

function WriteRel([string]$rel, [string[]]$lines) {
  $fp = Join-Path $repo $rel
  EnsureDir (Split-Path -Parent $fp)
  if (Test-Path -LiteralPath $fp) {
    $bk = BackupFile $fp
    Write-Host ("[BK] " + $bk)
  }
  WriteUtf8NoBom $fp ($lines -join "`r`n")
  Write-Host ("[OK] wrote: " + $fp)
  $script:changed.Add($fp) | Out-Null
}

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
# 1) Reescreve V2Nav.tsx (server-safe, sem union, sem parsing error)
# ---------------------------
$v2NavLines = @(
  'import Link from "next/link";'
  'import type { CSSProperties } from "react";'
  ''
  'type NavItem = { key: string; label: string; href: (slug: string) => string };'
  ''
  'const items: NavItem[] = ['
  '  { key: "home", label: "Hub", href: (slug) => "/c/" + slug + "/v2" },'
  '  { key: "mapa", label: "Mapa", href: (slug) => "/c/" + slug + "/v2/mapa" },'
  '  { key: "linha", label: "Linha", href: (slug) => "/c/" + slug + "/v2/linha" },'
  '  { key: "debate", label: "Debate", href: (slug) => "/c/" + slug + "/v2/debate" },'
  '  { key: "provas", label: "Provas", href: (slug) => "/c/" + slug + "/v2/provas" },'
  '  { key: "trilhas", label: "Trilhas", href: (slug) => "/c/" + slug + "/v2/trilhas" },'
  '];'
  ''
  'export default function V2Nav(props: { slug: string; active?: string }) {'
  '  const { slug, active } = props;'
  ''
  '  const wrap: CSSProperties = {'
  '    display: "flex",'
  '    gap: 10,'
  '    flexWrap: "wrap",'
  '    marginTop: 12,'
  '    alignItems: "center",'
  '  };'
  ''
  '  const base: CSSProperties = {'
  '    display: "inline-flex",'
  '    alignItems: "center",'
  '    padding: "8px 10px",'
  '    borderRadius: 999,'
  '    border: "1px solid rgba(255,255,255,0.14)",'
  '    textDecoration: "none",'
  '    color: "inherit",'
  '    fontSize: 12,'
  '    background: "rgba(0,0,0,0.18)",'
  '  };'
  ''
  '  const on: CSSProperties = {'
  '    ...base,'
  '    background: "rgba(255,255,255,0.08)",'
  '  };'
  ''
  '  return ('
  '    <nav aria-label="Navegação V2" style={wrap}>'
  '      {items.map((it) => {'
  '        const isOn = (active ? active === it.key : it.key === "home");'
  '        return ('
  '          <Link key={it.key} href={it.href(slug)} style={isOn ? on : base}>'
  '            {it.label}'
  '          </Link>'
  '        );'
  '      })}'
  '    </nav>'
  '  );'
  '}'
)

WriteRel "src\components\v2\V2Nav.tsx" $v2NavLines

# ---------------------------
# 2) /c/[slug]/page.tsx — garantir que uiDefault e redirect são usados (zera warnings)
# ---------------------------
PatchText "src\app\c\[slug]\page.tsx" {
  param($s)
  $out = $s

  # se já tem o bloco, não mexe
  if ($out.IndexOf('if (uiDefault === "v2")') -ge 0 -and $out.IndexOf('redirect("/c/" + slug + "/v2")') -ge 0) {
    return $out
  }

  # precisa ter const uiDefault
  $ix = $out.IndexOf("const uiDefault")
  if ($ix -lt 0) { return $out }

  # acha fim da linha do uiDefault
  $semi = $out.IndexOf(";", $ix)
  $nl = $out.IndexOf("`n", $ix)
  $end = -1
  if ($semi -ge 0 -and ($nl -lt 0 -or $semi -lt $nl)) { $end = $semi + 1 }
  elseif ($nl -ge 0) { $end = $nl + 1 }
  else { $end = $ix }

  $insert = @(
    '  if (uiDefault === "v2") {'
    '    redirect("/c/" + slug + "/v2");'
    '  }'
    ''
  ) -join "`r`n"

  return ($out.Substring(0, $end) + "`r`n" + $insert + $out.Substring($end))
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Fix — V2Nav parsing + /c/[slug] usar uiDefault/redirect (v0_106)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que foi feito") | Out-Null
$rep.Add("- Reescrito V2Nav.tsx (active?: string) para eliminar erro de parsing no lint.") | Out-Null
$rep.Add("- /c/[slug]/page.tsx agora usa uiDefault e redirect (zera warnings).") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null
$rp = WriteReport "cv-fix-v2nav-and-slugpage-v0_106.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Fix aplicado e verificado."