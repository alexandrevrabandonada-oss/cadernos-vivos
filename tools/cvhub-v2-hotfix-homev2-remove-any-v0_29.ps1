# CV — V2 Hotfix — HomeV2: remover "any" (pickFios) — v0_29
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

$repo = Get-Location
$bootstrap = Join-Path $repo "tools\_bootstrap.ps1"
if (-not (Test-Path -LiteralPath $bootstrap)) { throw "[STOP] tools/_bootstrap.ps1 não encontrado." }
. $bootstrap

Write-Host ("[DIAG] Repo: " + $repo)

$homeCompPath = Join-Path $repo "src\components\v2\HomeV2.tsx"
if (-not (Test-Path -LiteralPath $homeCompPath)) { throw ("[STOP] Não achei: " + $homeCompPath) }
Write-Host ("[DIAG] HomeV2: " + $homeCompPath)

$raw = Get-Content -LiteralPath $homeCompPath -Raw
$lines = $raw -split "\r?\n"

$out = New-Object System.Collections.Generic.List[string]
$changed = $false

for ($i = 0; $i -lt $lines.Count; $i++) {
  $ln = $lines[$i]

  if ($ln.Contains('if (isObj(v) && Array.isArray((v as any).items)) {')) {
    # captura indent do bloco
    $indent = ""
    if ($ln -match "^(\s*)") { $indent = $Matches[1] }

    # escreve bloco novo (sem any)
    $out.Add($indent + 'if (isObj(v)) {')
    $out.Add($indent + '  const obj = v as Record<string, unknown>;')
    $out.Add($indent + '  const items = obj["items"];')
    $out.Add($indent + '  if (Array.isArray(items)) {')
    $out.Add($indent + '    const s = items.filter((x) => typeof x === "string").map((x) => String(x).trim()).filter(Boolean);')
    $out.Add($indent + '    if (s.length > 0) return s;')
    $out.Add($indent + '  }')
    $out.Add($indent + '}')

    # pula as linhas do bloco antigo até o "}" dele
    $i++
    while ($i -lt $lines.Count) {
      if ($lines[$i].Trim() -eq '}') { break }
      $i++
    }

    $changed = $true
    continue
  }

  $out.Add($ln)
}

if (-not $changed) {
  Write-Host "[WARN] Não encontrei o bloco com '(v as any).items' — talvez já esteja corrigido, ou mudou o texto."
} else {
  $bk = BackupFile $homeCompPath
  WriteUtf8NoBom $homeCompPath ($out -join "`n")
  Write-Host "[OK] patched: HomeV2.tsx (removeu any no pickFios)"
  if ($bk) { Write-Host ("[BK] " + $bk) }
}

# Guard extra: não pode sobrar "as any" no arquivo
$check = Get-Content -LiteralPath $homeCompPath -Raw
if ($check.Contains(" as any") -or $check.Contains("(v as any)")) {
  throw "[STOP] Ainda sobrou 'any' no HomeV2.tsx (procure por 'as any')."
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
if (-not (Test-Path -LiteralPath $verify)) { throw ("[STOP] Não achei: " + $verify) }
Write-Host ("[RUN] " + $verify)
& $verify

# REPORT
$report = @(
  "# CV — Hotfix v0_29 — HomeV2 sem any (pickFios)",
  "",
  "## Causa raiz",
  "- HomeV2.tsx ainda tinha (v as any).items para ler panorama.fios, e o eslint no-explicit-any travou.",
  "",
  "## Fix",
  "- Trocou o bloco por uma leitura segura via Record<string, unknown> + Array.isArray(items).",
  "",
  "## Arquivo",
  "- src/components/v2/HomeV2.tsx",
  "",
  "## Verify",
  "- tools/cv-verify.ps1 (Guard → Lint → Build)",
  ""
) -join "`n"

WriteReport "cv-v2-hotfix-homev2-remove-any-v0_29.md" $report | Out-Null
Write-Host "[OK] v0_29 aplicado e verificado."