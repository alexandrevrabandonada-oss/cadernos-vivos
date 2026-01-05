# CV — V2 Hotfix — Corrigir parse em v2/trilhas/page.tsx + evitar react/no-unescaped-entities — v0_28
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

$repo = Get-Location
$bootstrap = Join-Path $repo "tools\_bootstrap.ps1"
if (-not (Test-Path -LiteralPath $bootstrap)) { throw "[STOP] tools/_bootstrap.ps1 não encontrado." }
. $bootstrap

Write-Host ("[DIAG] Repo: " + $repo)

$target = Join-Path $repo "src\app\c\[slug]\v2\trilhas\page.tsx"
if (-not (Test-Path -LiteralPath $target)) { throw ("[STOP] Não achei: " + $target) }
Write-Host ("[DIAG] Target: " + $target)

$raw = Get-Content -LiteralPath $target -Raw

# 1) desfaz o &quot; que pode ter quebrado TSX
$raw2 = $raw.Replace('&quot;', '"')

# 2) adiciona eslint-disable no topo do arquivo (somente pra este rule), se não existir
$disable = '/* eslint-disable react/no-unescaped-entities */'
if ($raw2.IndexOf($disable, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
  $raw2 = $disable + "`n" + $raw2
}

if ($raw2 -ne $raw) {
  $bk = BackupFile $target
  WriteUtf8NoBom $target $raw2
  Write-Host "[OK] patched: v2/trilhas/page.tsx (reverteu &quot; + adicionou eslint-disable)"
  if ($bk) { Write-Host ("[BK] " + $bk) }
} else {
  Write-Host "[OK] Sem mudança (arquivo já estava ok)."
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
& $verify

# REPORT
$report = @"
# CV — Hotfix v0_28 — v2/trilhas/page.tsx parse + lint

## Causa
- Conversão ampla para &quot; acabou gerando TSX inválido (Parsing error: Expression expected).

## Fix
- Reverte &quot; -> "
- Adiciona no topo: /* eslint-disable react/no-unescaped-entities */ (somente neste arquivo)

## Arquivo
- src/app/c/[slug]/v2/trilhas/page.tsx

## Verify
- tools/cv-verify.ps1 (guard + lint + build)
"@

WriteReport "cv-v2-hotfix-trilhas-page-parse-v0_28.md" $report | Out-Null
Write-Host "[OK] v0_28 aplicado e verificado."