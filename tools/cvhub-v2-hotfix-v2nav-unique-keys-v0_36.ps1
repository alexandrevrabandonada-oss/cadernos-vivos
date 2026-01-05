# CV — Hotfix — V2Nav unique keys (React warning) — v0_36
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

$repo = Get-Location
$bootstrap = Join-Path $repo "tools\_bootstrap.ps1"
if (Test-Path -LiteralPath $bootstrap) { . $bootstrap } else { throw "[STOP] tools/_bootstrap.ps1 não encontrado." }

$navPath = Join-Path $repo "src\components\v2\V2Nav.tsx"
if (-not (Test-Path -LiteralPath $navPath)) { throw ("[STOP] Não achei: " + $navPath) }

Write-Host ("[DIAG] V2Nav: " + $navPath)

$raw = Get-Content -LiteralPath $navPath -Raw
if (-not $raw) { throw "[STOP] V2Nav.tsx vazio/ilegível." }

$changed = $false
$next = $raw

# Caso padrão: key={it.key} -> key={it.href}
if ($next.Contains("key={it.key}")) {
  $next = $next.Replace("key={it.key}", "key={it.href}")
  $changed = $true
}

# fallback: key = { it.key } com espaços
if (-not $changed) {
  $next2 = $next -replace "key=\{\s*it\.key\s*\}", "key={it.href}"
  if ($next2 -ne $next) { $next = $next2; $changed = $true }
}

if (-not $changed) {
  Write-Host "[WARN] Não encontrei key={it.key}. Vou tentar detectar map de links e forçar key={it.href}."
  # tentativa genérica: primeira ocorrência de "key={" dentro do Link
  $next2 = $next -replace "<Link(\s+[^>]*?)\skey=\{[^}]+\}", "<Link`$1 key={it.href}"
  if ($next2 -ne $next) { $next = $next2; $changed = $true }
}

if ($changed) {
  $bk = BackupFile $navPath
  WriteUtf8NoBom $navPath $next
  Write-Host "[OK] patched: V2Nav.tsx (key agora usa href)"
  if ($bk) { Write-Host ("[BK] " + $bk) }
} else {
  Write-Host "[OK] nada para mudar (já estava ok ou padrão diferente)."
}

# VERIFY
RunPs1 (Join-Path $repo "tools\cv-verify.ps1")

# REPORT
$rep = @(
  "# CV — Hotfix v0_36 — V2Nav unique keys",
  "",
  "## Causa",
  "- Warning do React: keys duplicadas (provável repetição de it.key em itens do menu).",
  "",
  "## Fix",
  "- Troca key do map para usar href (tende a ser único): key={it.href}.",
  "",
  "## Arquivo",
  "- src/components/v2/V2Nav.tsx",
  "",
  "## Verify",
  "- tools/cv-verify.ps1 (guard + lint + build)",
  ""
) -join "`n"

WriteReport "cv-hotfix-v2nav-unique-keys-v0_36.md" $rep | Out-Null
Write-Host "[OK] v0_36 aplicado e verificado."