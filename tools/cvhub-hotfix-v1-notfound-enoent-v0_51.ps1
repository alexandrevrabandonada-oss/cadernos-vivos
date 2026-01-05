$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Write-Host ("[DIAG] Repo: " + $repo)

. (Join-Path $PSScriptRoot "_bootstrap.ps1")

$changed = New-Object System.Collections.Generic.List[string]

function PatchPageFile($filePath) {
  $raw = Get-Content -LiteralPath $filePath -Raw
  if (-not ($raw -match "getCaderno")) { return }

  # garante import notFound
  if (-not ($raw -match 'from "next/navigation"')) {
    # tenta inserir logo após imports existentes
    $lines = $raw -split "`r?`n"
    $out = New-Object System.Collections.Generic.List[string]
    $inserted = $false
    foreach ($ln in $lines) {
      $out.Add($ln) | Out-Null
      if (-not $inserted -and $ln.Trim().StartsWith("import ") -and ($ln -match 'from "next/')) {
        # deixa passar; inserimos depois do bloco de imports (quando encontrar primeira linha não-import)
      }
      if (-not $inserted -and (-not $ln.Trim().StartsWith("import ")) ) {
        $out.Insert($out.Count-1, 'import { notFound } from "next/navigation";') | Out-Null
        $inserted = $true
      }
    }
    if (-not $inserted) { $out.Add('import { notFound } from "next/navigation";') | Out-Null }
    $raw = ($out -join "`n")
  } elseif (-not ($raw -match "notFound")) {
    # se já importa next/navigation mas não tem notFound, injeta no mesmo import quando possível
    $raw = $raw -replace 'import\s*\{\s*([^}]*)\}\s*from\s*"next/navigation";', { 
      $inside = $args[0].Groups[1].Value
      if ($inside -match "\bnotFound\b") { $args[0].Value } else { 'import { ' + $inside.Trim() + ', notFound } from "next/navigation";' }
    }
  }

  # patch da linha: const X = await getCaderno(slug);
  $lines2 = $raw -split "`r?`n"
  $out2 = New-Object System.Collections.Generic.List[string]
  $did = $false

  foreach ($ln in $lines2) {
    if (-not $did -and ($ln -match '^\s*const\s+([A-Za-z0-9_]+)\s*=\s*await\s+getCaderno\(slug\)\s*;')) {
      $var = $Matches[1]
      $indent = ($ln -replace '^(\\s*).+$', '$1')

      $out2.Add(($indent + 'let ' + $var + ': Awaited<ReturnType<typeof getCaderno>>;')) | Out-Null
      $out2.Add(($indent + 'try {')) | Out-Null
      $out2.Add(($indent + '  ' + $var + ' = await getCaderno(slug);')) | Out-Null
      $out2.Add(($indent + '} catch (e) {')) | Out-Null
      $out2.Add(($indent + '  const err = e as { code?: string };')) | Out-Null
      $out2.Add(($indent + '  if (err && err.code === "ENOENT") return notFound();')) | Out-Null
      $out2.Add(($indent + '  throw e;')) | Out-Null
      $out2.Add(($indent + '}')) | Out-Null

      $did = $true
      continue
    }
    $out2.Add($ln) | Out-Null
  }

  if ($did) {
    $bk = BackupFile $filePath
    WriteUtf8NoBom $filePath ($out2 -join "`n")
    Write-Host ("[OK] patched: " + $filePath)
    if ($bk) { Write-Host ("[BK] " + $bk) }
    $script:changed.Add($filePath) | Out-Null
  }
}

# 1) Patch pages V1 em src/app/c/[slug] (sem tocar v2)
$root = Join-Path $repo "src\app\c\[slug]"
if (Test-Path -LiteralPath $root) {
  $pages = Get-ChildItem -LiteralPath $root -Recurse -File -Filter "page.tsx"
  Write-Host ("[DIAG] V1 pages found: " + $pages.Count)
  foreach ($p in $pages) {
    # pula V2
    if ($p.FullName -match '\\v2\\') { continue }
    PatchPageFile $p.FullName
  }
} else {
  Write-Host ("[WARN] nao achei pasta: " + $root)
}

# 2) (Opcional) Fallback meta.json no loader V1
$lib = Join-Path $repo "src\lib\cadernos.ts"
if (Test-Path -LiteralPath $lib) {
  $rawLib = Get-Content -LiteralPath $lib -Raw
  if (($rawLib -match '"caderno\.json"') -and (-not ($rawLib -match 'meta\.json'))) {
    # tenta trocar const metaPath -> let metaPath + fallback
    $needle1 = 'const metaPath = path.join(base, slug, "caderno.json");'
    $needle2 = "const metaPath = path.join(base, slug, 'caderno.json');"

    $rep = @()
    $rep += 'let metaPath = path.join(base, slug, "caderno.json");'
    $rep += 'try {'
    $rep += '  await fs.stat(metaPath);'
    $rep += '} catch {'
    $rep += '  metaPath = path.join(base, slug, "meta.json");'
    $rep += '}'
    $replacement = ($rep -join "`n")

    $didLib = $false
    if ($rawLib.Contains($needle1)) {
      $rawLib = $rawLib.Replace($needle1, $replacement)
      $didLib = $true
    } elseif ($rawLib.Contains($needle2)) {
      $rawLib = $rawLib.Replace($needle2, $replacement)
      $didLib = $true
    }

    if ($didLib) {
      $bk = BackupFile $lib
      WriteUtf8NoBom $lib $rawLib
      Write-Host ("[OK] patched: " + $lib + " (fallback meta.json)")
      if ($bk) { Write-Host ("[BK] " + $bk) }
      $changed.Add($lib) | Out-Null
    } else {
      Write-Host "[OK] cadernos.ts: padrao diferente; nao mexi."
    }
  } else {
    Write-Host "[OK] cadernos.ts: ja tem fallback ou nao usa caderno.json."
  }
} else {
  Write-Host ("[WARN] nao achei: " + $lib)
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep2 = @()
$rep2 += "# CV — Hotfix v0_51 — V1 /c/[slug] ENOENT vira notFound"
$rep2 += ""
$rep2 += "## Causa"
$rep2 += "- Acesso a slug placeholder (ex.: SEU-SLUG) sem pasta em content/cadernos; loader tenta ler caderno.json e explode ENOENT."
$rep2 += ""
$rep2 += "## Fix"
$rep2 += "- Pages V1 capturam ENOENT e retornam notFound() (404) ao inves de quebrar a renderizacao."
$rep2 += "- (Opcional) Loader V1 tenta caderno.json e cai para meta.json quando nao existir."
$rep2 += ""
$rep2 += "## Arquivos alterados"
if ($changed.Count -eq 0) {
  $rep2 += "- (nenhum — ja estava no padrao)"
} else {
  foreach ($f in $changed) { $rep2 += ("- " + $f) }
}
$rep2 += ""
$rep2 += "## Verify"
$rep2 += "- tools/cv-verify.ps1 (guard + lint + build)"
$rep2 += ""

$rp = WriteReport "cv-hotfix-v1-notfound-enoent-v0_51.md" ($rep2 -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Hotfix v0_51 aplicado e verificado."