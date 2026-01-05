$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Write-Host ("[DIAG] Repo: " + $repo)

. (Join-Path $PSScriptRoot "_bootstrap.ps1")

$changed = New-Object System.Collections.Generic.List[string]

function PatchTextFile([string]$fullPath, [string]$newContent) {
  if (!(Test-Path -LiteralPath $fullPath)) { throw ("[STOP] file not found: " + $fullPath) }
  $old = Get-Content -LiteralPath $fullPath -Raw
  if ($old -eq $newContent) { return $false }
  $bk = BackupFile $fullPath
  WriteUtf8NoBom $fullPath $newContent
  Write-Host ("[OK] patched: " + $fullPath)
  Write-Host ("[BK] " + $bk)
  $script:changed.Add($fullPath) | Out-Null
  return $true
}

# 1) Detect export style in V2Nav
$v2NavPath = Join-Path $repo "src\components\v2\V2Nav.tsx"
if (!(Test-Path -LiteralPath $v2NavPath)) { throw ("[STOP] missing: " + $v2NavPath) }
$v2NavRaw = Get-Content -LiteralPath $v2NavPath -Raw

$v2NavIsDefault = $false
if ($v2NavRaw -match "export\s+default") {
  $v2NavIsDefault = $true
} elseif ($v2NavRaw -match "export\s+(function|const)\s+V2Nav") {
  $v2NavIsDefault = $false
} else {
  # fallback: the build error suggests default export exists
  $v2NavIsDefault = $true
}
Write-Host ("[DIAG] V2Nav export: " + ($(if ($v2NavIsDefault) { "default" } else { "named" })))

# 2) Patch imports in V2 pages
$v2Root = Join-Path $repo "src\app\c\[slug]\v2"
if (!(Test-Path -LiteralPath $v2Root)) { throw ("[STOP] missing: " + $v2Root) }

$pages = Get-ChildItem -LiteralPath $v2Root -Recurse -File -Filter "page.tsx"
Write-Host ("[DIAG] V2 pages found: " + $pages.Count)

$namedImport = 'import { V2Nav } from "@/components/v2/V2Nav";'
$defaultImport = 'import V2Nav from "@/components/v2/V2Nav";'

$hit = 0
foreach ($p in $pages) {
  $raw = Get-Content -LiteralPath $p.FullName -Raw

  $new = $raw

  if ($v2NavIsDefault) {
    if ($new.Contains($namedImport)) {
      $new = $new.Replace($namedImport, $defaultImport)
      $hit++
    }
  } else {
    if ($new.Contains($defaultImport)) {
      $new = $new.Replace($defaultImport, $namedImport)
      $hit++
    }
  }

  if ($new -ne $raw) {
    PatchTextFile $p.FullName $new | Out-Null
  }
}

Write-Host ("[DIAG] import hits changed: " + $hit)

# 3) VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# 4) REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Step D3 — Fix V2Nav import (v0_56)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que foi corrigido") | Out-Null
$rep.Add("- Ajuste automático do import do V2Nav nas páginas V2 (default vs named), conforme export real em src/components/v2/V2Nav.tsx.") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null
$rep.Add("") | Out-Null

$rp = WriteReport "cv-step-d3-fix-v2nav-import-v0_56.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] v0_56 aplicado e verificado."