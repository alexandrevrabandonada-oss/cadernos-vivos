$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Write-Host ("[DIAG] Repo: " + $repo)

. (Join-Path $PSScriptRoot "_bootstrap.ps1")

$changed = New-Object System.Collections.Generic.List[string]

function PatchText([string]$rel, [scriptblock]$mutate) {
  $fullp = Join-Path $repo $rel
  if (!(Test-Path -LiteralPath $fullp)) { Write-Host ("[WARN] nao achei: " + $fullp); return $false }
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
    return $true
  } else {
    Write-Host ("[OK] sem mudanca: " + $fullp)
    return $false
  }
}

function FirstExisting([string[]]$rels) {
  foreach ($r in $rels) {
    $p = Join-Path $repo $r
    if (Test-Path -LiteralPath $p) { return $r }
  }
  return $null
}

# --- DIAG candidates
$v1Rel = FirstExisting @(
  "src\app\c\[slug]\page.tsx",
  "src\app\c\[slug]\page.ts"
)
Write-Host ("[DIAG] V1 page: " + ($(if ($v1Rel) { $v1Rel } else { "(nao achei)" })))

$v2NavRel = "src\components\v2\V2Nav.tsx"
Write-Host ("[DIAG] V2Nav: " + (Join-Path $repo $v2NavRel))

# 1) Patch V1 /c/[slug] → redirect para V2 quando meta.ui.default == "v2"
#    e adiciona link "Ver V2" no topo.
if ($v1Rel) {
  PatchText $v1Rel {
    param($raw)

    $s = $raw

    # 1.1) garantir import redirect
    if ($s -notmatch 'redirect\s*\}\s*from\s*"next/navigation"') {
      # caso comum: import { notFound } from "next/navigation";
      if ($s -match 'import\s*\{\s*([^}]+)\s*\}\s*from\s*"next/navigation"') {
        if ($s -notmatch 'from\s*"next/navigation"') { return $s }
        if ($s -notmatch 'notFound') {
          # nao sabemos o formato; deixa quieto
        } else {
          $s = [regex]::Replace(
            $s,
            'import\s*\{\s*([^}]+)\s*\}\s*from\s*"next/navigation"\s*;',
            { param($m)
              $inner = $m.Groups[1].Value
              if ($inner -match '\bredirect\b') { return $m.Value }
              return 'import { ' + $inner.Trim() + ', redirect } from "next/navigation";'
            },
            1
          )
        }
      } else {
        # se nao tiver import {...} de next/navigation, tenta adicionar no topo
        $s = 'import { redirect } from "next/navigation";' + "`r`n" + $s
      }
    }

    # 1.2) garantir import Link
    if ($s -notmatch 'from\s*"next/link"') {
      # insere após último import do bloco inicial
      $lines = $s -split "(`r`n|`n|`r)"
      $lastImp = -1
      for ($i=0; $i -lt $lines.Length; $i++) {
        if ($lines[$i].Trim().StartsWith("import ")) { $lastImp = $i }
        elseif ($lastImp -ge 0 -and $lines[$i].Trim() -eq "") { continue }
        elseif ($lastImp -ge 0) { break }
      }
      if ($lastImp -ge 0) {
        $out = New-Object System.Collections.Generic.List[string]
        for ($i=0; $i -le $lastImp; $i++) { $out.Add($lines[$i]) | Out-Null }
        $out.Add('import Link from "next/link";') | Out-Null
        for ($i=$lastImp+1; $i -lt $lines.Length; $i++) { $out.Add($lines[$i]) | Out-Null }
        $s = ($out -join "`r`n")
      } else {
        $s = 'import Link from "next/link";' + "`r`n" + $s
      }
    }

    # 1.3) inserir helper uiDefault (sem any)
    if ($s.IndexOf("function uiDefault(") -lt 0) {
      $helperLines = @(
        'type AnyObj = Record<string, unknown>;',
        '',
        'function isObj(v: unknown): v is AnyObj {',
        '  return !!v && typeof v === "object" && !Array.isArray(v);',
        '}',
        '',
        'function uiDefault(meta: unknown): string {',
        '  if (!isObj(meta)) return "";',
        '  const ui = (meta as AnyObj)["ui"];',
        '  if (isObj(ui)) {',
        '    const d = (ui as AnyObj)["default"];',
        '    if (typeof d === "string") return d;',
        '  }',
        '  const d2 = (meta as AnyObj)["uiDefault"];',
        '  if (typeof d2 === "string") return d2;',
        '  return "";',
        '}',
        ''
      ) -join "`r`n"

      $pos = $s.IndexOf("export default")
      if ($pos -gt 0) {
        $s = $s.Substring(0, $pos) + $helperLines + $s.Substring($pos)
      } else {
        # fallback: coloca no topo
        $s = $helperLines + $s
      }
    }

    # 1.4) inserir redirect (se ainda nao existir)
    if ($s.IndexOf("uiDefault(") -ge 0 -and $s.IndexOf("redirect(") -lt 0) {
      $idxRet = $s.IndexOf("return (")
      if ($idxRet -gt 0) {
        # tenta achar uma variavel "data" e "slug" no escopo; usa pattern mais seguro (não quebra se não existir)
        $redir = @(
          '',
          '  // feature flag: meta.ui.default = "v2" → abre V2 por padrão',
          '  try {',
          '    const _m = (data as unknown as { meta?: unknown }).meta;',
          '    const _d = uiDefault(_m);',
          '    if (_d === "v2") redirect("/c/" + slug + "/v2");',
          '  } catch {}',
          ''
        ) -join "`r`n"
        $s = $s.Substring(0, $idxRet) + $redir + $s.Substring($idxRet)
      }
    }

    # 1.5) inserir link "Ver V2" dentro do <main> (best-effort)
    if ($s.IndexOf('href={"/c/" + slug + "/v2"}') -lt 0 -and $s.IndexOf('href={"/c/" + slug + "/v2"') -lt 0) {
      $mainIdx = $s.IndexOf("<main")
      if ($mainIdx -gt 0) {
        $gt = $s.IndexOf(">", $mainIdx)
        if ($gt -gt 0) {
          $ins = @(
            '',
            '      <div style={{ display: "flex", justifyContent: "flex-end", marginBottom: 10 }}>',
            '        <Link href={"/c/" + slug + "/v2"} style={{ fontSize: 12, opacity: 0.85, textDecoration: "underline" }}>',
            '          Ver V2',
            '        </Link>',
            '      </div>',
            ''
          ) -join "`r`n"
          $s = $s.Substring(0, $gt + 1) + $ins + $s.Substring($gt + 1)
        }
      }
    }

    return $s
  } | Out-Null
} else {
  Write-Host "[WARN] Nao achei /c/[slug]/page.tsx para aplicar meta.ui.default."
}

# 2) Patch V2Nav: adicionar link "V1" (best-effort, sem mexer na navegação principal)
PatchText $v2NavRel {
  param($raw)

  $s = $raw
  if ($s.IndexOf('title="Voltar para V1"') -ge 0 -or $s.IndexOf('>V1<') -ge 0) { return $s }

  $slugExpr = "props.slug"
  if ($s.IndexOf("props.slug") -lt 0) {
    if ($s -match '\bslug\b') { $slugExpr = "slug" } else { $slugExpr = "props.slug" }
  }

  $closeIdx = $s.LastIndexOf("</nav>")
  if ($closeIdx -lt 0) {
    Write-Host "[WARN] V2Nav sem </nav>; skip link V1."
    return $s
  }

  $insLines = @(
    '',
    '      <a',
    '        href={"/c/" + ' + $slugExpr + '}',
    '        title="Voltar para V1"',
    '        style={{',
    '          marginLeft: 10,',
    '          fontSize: 12,',
    '          fontWeight: 900,',
    '          padding: "6px 10px",',
    '          borderRadius: 999,',
    '          border: "1px solid rgba(255,255,255,0.14)",',
    '          background: "rgba(255,255,255,0.06)",',
    '          textDecoration: "none",',
    '          color: "inherit",',
    '        }}',
    '      >',
    '        V1',
    '      </a>',
    ''
  ) -join "`r`n"

  $s = $s.Substring(0, $closeIdx) + $insLines + $s.Substring($closeIdx)
  return $s
} | Out-Null

# 3) VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# 4) REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Extra — meta.ui.default + links V1↔V2 (v0_65)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que entrou") | Out-Null
$rep.Add("- Feature flag no V1: se `meta.ui.default` (ou `meta.uiDefault`) == `v2`, `/c/[slug]` redireciona pra `/c/[slug]/v2`.") | Out-Null
$rep.Add("- Link `Ver V2` no topo da página V1 (best-effort).") | Out-Null
$rep.Add("- Link `V1` no V2Nav (best-effort) pra voltar rápido.") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Como usar no caderno") | Out-Null
$rep.Add("- No `meta.json`, adicione: `\"ui\": { \"default\": \"v2\" }` (ou `\"uiDefault\": \"v2\"`).") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null

$rp = WriteReport "cv-extra-ui-default-and-links-v1-v2-v0_65.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Extra aplicado e verificado."