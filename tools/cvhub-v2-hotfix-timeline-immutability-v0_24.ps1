# CV — V2 Hotfix — TimelineV2: remover window.location.hash (react-hooks/immutability) — v0_24
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

$repo = Get-Location
$bootstrap = Join-Path $repo "tools\_bootstrap.ps1"
if (-not (Test-Path -LiteralPath $bootstrap)) { throw "[STOP] tools/_bootstrap.ps1 não encontrado. Rode o tijolo infra antes." }
. $bootstrap

Write-Host ("[DIAG] Repo: " + $repo)

$timeline = Join-Path $repo "src\components\v2\TimelineV2.tsx"
if (-not (Test-Path -LiteralPath $timeline)) { throw ("[STOP] Não achei: " + $timeline) }
Write-Host ("[DIAG] TimelineV2: " + $timeline)

$raw = Get-Content -LiteralPath $timeline -Raw
$lines = $raw -split "\r?\n"

$out = New-Object System.Collections.Generic.List[string]
$changed = $false

foreach ($ln in $lines) {
  if ($ln.Contains("window.location.hash") -and $ln.Contains("=")) {
    # preserva indentação da linha original
    $indent = [regex]::Match($ln, '^\s*').Value

    $out.Add($indent + 'const el = document.getElementById(hash.slice(1));')
    $out.Add($indent + 'if (el) el.scrollIntoView({ behavior: "smooth", block: "start" });')
    $changed = $true
  } else {
    $out.Add($ln)
  }
}

if (-not $changed) {
  Write-Host "[WARN] Não encontrei linha com window.location.hash = ... (talvez já esteja corrigido)."
} else {
  $bk = BackupFile $timeline
  WriteUtf8NoBom $timeline ($out -join "`n")
  Write-Host "[OK] patched: TimelineV2.tsx (removeu window.location.hash; adicionou scrollIntoView)"
  if ($bk) { Write-Host ("[BK] " + $bk) }
}

# VERIFY (usa o verify padrão, que já roda guard+lint+build)
RunCmd "pwsh" @("-NoProfile","-ExecutionPolicy","Bypass","-File",(Join-Path $repo "tools\cv-verify.ps1"))

# REPORT
$reportLines = @(
  "# CV — Hotfix v0_24 — TimelineV2 sem window.location.hash",
  "",
  "## Causa raiz",
  "- ESLint (react-hooks/immutability) bloqueia mutação de window.location.hash dentro de componente/hook.",
  "",
  "## Fix",
  "- Removeu a mutação do hash.",
  "- Mantém UX: scrollIntoView no item do hash (o link já é copiado com #t-id).",
  "",
  "## Arquivo",
  "- src/components/v2/TimelineV2.tsx",
  "",
  "## Verify",
  "- tools/cv-verify.ps1 (guard + lint + build)",
  ""
) -join "`n"

WriteReport "cv-v2-hotfix-timeline-immutability-v0_24.md" $reportLines | Out-Null
Write-Host "[OK] v0_24 aplicado e verificado."