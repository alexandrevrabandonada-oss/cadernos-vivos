# CV — V2 Hotfix — D6 lint: react/no-unescaped-entities + remove eslint-disable unused — v0_31
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

$repo = Get-Location
$bootstrap = Join-Path $repo "tools\_bootstrap.ps1"
if (-not (Test-Path -LiteralPath $bootstrap)) { throw "[STOP] tools/_bootstrap.ps1 não encontrado." }
. $bootstrap

Write-Host ("[DIAG] Repo: " + $repo)

$page = Join-Path $repo "src\app\c\[slug]\v2\trilhas\page.tsx"
$lib  = Join-Path $repo "src\lib\v2\trilhas.ts"

if (-not (Test-Path -LiteralPath $page)) { throw ("[STOP] Não achei: " + $page) }
if (-not (Test-Path -LiteralPath $lib))  { throw ("[STOP] Não achei: " + $lib) }

# 1) Fix no JSX: trocar aspas por &quot; no texto "type: "trail""
$raw = Get-Content -LiteralPath $page -Raw
$raw2 = $raw.Replace('type: "trail"', 'type: &quot;trail&quot;')

if ($raw2 -ne $raw) {
  $bk = BackupFile $page
  WriteUtf8NoBom $page $raw2
  Write-Host ("[OK] patched: " + $page + " (no-unescaped-entities)")
  if ($bk) { Write-Host ("[BK] " + $bk) }
} else {
  Write-Host "[WARN] Não encontrei 'type: ""trail""' em page.tsx (talvez já esteja corrigido ou texto mudou)."
}

# 2) Remover eslint-disable unused no topo do lib/v2/trilhas.ts
$lraw = Get-Content -LiteralPath $lib -Raw
$lines = $lraw -split "\r?\n"
$out = New-Object System.Collections.Generic.List[string]
$removed = $false

foreach ($ln in $lines) {
  if (-not $removed -and $ln.Trim() -eq "/* eslint-disable @typescript-eslint/consistent-type-imports */") {
    $removed = $true
    continue
  }
  $out.Add($ln)
}

if ($removed) {
  $bk2 = BackupFile $lib
  WriteUtf8NoBom $lib ($out -join "`n")
  Write-Host ("[OK] patched: " + $lib + " (removeu eslint-disable unused)")
  if ($bk2) { Write-Host ("[BK] " + $bk2) }
} else {
  Write-Host "[OK] trilhas.ts não tinha eslint-disable (sem mudança)."
}

# VERIFY (Guard → Lint → Build)
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
& $verify

# REPORT
$rep = @(
"# CV — Hotfix v0_31 — D6 lint fix (unescaped quotes + eslint-disable unused)",
"",
"## Fixes",
"- page.tsx (Trilhas V2): trocou `type: ""trail""` por `type: &quot;trail&quot;` para passar `react/no-unescaped-entities`.",
"- trilhas.ts: removeu `/* eslint-disable ... */` não utilizado (warning).",
"",
"## Verify",
"- tools/cv-verify.ps1 (Guard → Lint → Build)",
""
) -join "`n"
WriteReport "cv-v2-hotfix-d6-lint-unescaped-entities-v0_31.md" $rep | Out-Null

Write-Host "[OK] v0_31 aplicado e verificado."