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

function InsertAfterLastImport([string]$src, [string]$lineToInsert) {
  if ($src.IndexOf($lineToInsert) -ge 0) { return $src }
  $lines = $src -split "(`r`n|`n|`r)"
  $lastImp = -1
  for ($i=0; $i -lt $lines.Length; $i++) {
    if ($lines[$i].Trim().StartsWith("import ")) { $lastImp = $i }
    elseif ($lastImp -ge 0 -and $lines[$i].Trim() -eq "") { continue }
    elseif ($lastImp -ge 0) { break }
  }
  if ($lastImp -lt 0) { return ($lineToInsert + "`r`n" + $src) }
  $out = New-Object System.Collections.Generic.List[string]
  for ($i=0; $i -le $lastImp; $i++) { $out.Add($lines[$i]) | Out-Null }
  $out.Add($lineToInsert) | Out-Null
  for ($i=$lastImp+1; $i -lt $lines.Length; $i++) { $out.Add($lines[$i]) | Out-Null }
  return ($out -join "`r`n")
}

# --- DIAG candidates
$v1Rel = FirstExisting @(
  "src\app\c\[slug]\page.tsx",
  "src\app\c\[slug]\page.ts"
)
Write-Host ("[DIAG] V1 page: " + ($(if ($v1Rel) { $v1Rel } else { "(nao achei)" })))

$v2NavRel = "src\components\v2\V2Nav.tsx"
Write-Host ("[DIAG] V2Nav: " + (Join-Path $repo $v2NavRel))

# 1) Patch V1 /c/[slug] → (a) link "Ver V2" e (b) redirect se meta.ui.default=="v2" (best-effort)
if ($v1Rel) {
  PatchText $v1Rel {
    param($raw)
    $s = $raw

    # a) garantir Link import
    if ($s -notmatch 'from\s*"next/link"' -and $s -notmatch "from\s*'next/link'") {
      $s = InsertAfterLastImport $s 'import Link from "next/link";'
    }

    # b) garantir redirect import (next/navigation)
    if ($s -match 'import\s*\{\s*([^}]+)\s*\}\s*from\s*"next/navigation"\s*;') {
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
    } elseif ($s -notmatch 'from\s*"next/navigation"' -and $s -notmatch "from\s*'next/navigation'") {
      $s = 'import { redirect } from "next/navigation";' + "`r`n" + $s
    }

    # c) helper uiDefault (sem any)
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
      if ($pos -gt 0) { $s = $s.Substring(0, $pos) + $helperLines + $s.Substring($pos) }
      else { $s = $helperLines + $s }
    }

    # d) detectar variável do getCaderno (pra não quebrar build)
    $dataVar = $null
    $m = [regex]::Match($s, '(?:const|let)\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*await\s+getCaderno\s*\(')
    if ($m.Success) { $dataVar = $m.Groups[1].Value }

    # e) inserir redirect somente se der pra detectar dataVar e se ainda não tiver redirect("/c/" + slug + "/v2")
    if ($dataVar -and $s.IndexOf('redirect("/c/" + slug + "/v2")') -lt 0 -and $s.IndexOf("redirect('/c/' + slug + '/v2')") -lt 0) {
      $idxRet = $s.IndexOf("return (")
      if ($idxRet -gt 0) {
        $redir = @(
          '',
          '  // feature flag: meta.ui.default == "v2" -> abre V2 por padrao',
          '  try {',
          '    const _m = (' + $dataVar + ' as unknown as { meta?: unknown }).meta;',
          '    const _d = uiDefault(_m);',
          '    if (_d === "v2") redirect("/c/" + slug + "/v2");',
          '  } catch {}',
          ''
        ) -join "`r`n"
        $s = $s.Substring(0, $idxRet) + $redir + $s.Substring($idxRet)
        Write-Host ("[DIAG] redirect inserido usando var: " + $dataVar)
      }
    } else {
      if (!$dataVar) { Write-Host "[DIAG] getCaderno var nao detectada: pulando redirect (so link Ver V2)." }
    }

    # f) inserir link "Ver V2" dentro do <main> (best-effort), só se existir "slug" no arquivo
    if ($s.IndexOf('href={"/c/" + slug + "/v2"}') -lt 0 -and $s -match '\bslug\b') {
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
  Write-Host "[WARN] Nao achei /c/[slug]/page.tsx para aplicar ui.default."
}

# 2) Patch V2Nav: adicionar link "V1" (best-effort)
PatchText $v2NavRel {
  param($raw)
  $s = $raw
  if ($s.IndexOf('title="Voltar para V1"') -ge 0 -or $s.IndexOf(">V1<") -ge 0) { return $s }

  $slugExpr = $null
  if ($s.IndexOf("props.slug") -ge 0) { $slugExpr = "props.slug" }
  elseif ($s -match '\bslug\b') { $slugExpr = "slug" }

  if (!$slugExpr) {
    Write-Host "[WARN] V2Nav sem slug detectavel; skip link V1."
    return $s
  }

  $closeIdx = $s.LastIndexOf("</nav>")
  if ($closeIdx -lt 0) {
    Write-Host "[WARN] V2Nav sem </nav>; skip link V1."
    return $s
  }

  $ins = @(
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

  $s = $s.Substring(0, $closeIdx) + $ins + $s.Substring($closeIdx)
  return $s
} | Out-Null

# 3) VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# 4) REPORT (strings safe: sem \")
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Extra — ui.default + links V1↔V2 (v0_66)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que entrou") | Out-Null
$rep.Add("- V1: link Ver V2 no topo (best-effort).") | Out-Null
$rep.Add("- V1: redirect para V2 quando meta.ui.default == v2 (apenas se detectar a variavel do getCaderno).") | Out-Null
$rep.Add("- V2Nav: botao V1 pra voltar rapido (best-effort).") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Como usar no caderno") | Out-Null
$rep.Add("- No meta.json: ui.default = v2 (ou uiDefault = v2).") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null

$rp = WriteReport "cv-extra-ui-default-and-links-v1-v2-v0_66.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Extra aplicado e verificado."