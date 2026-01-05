# CV — V2 Extra — meta.ui.default + redirect V1→V2 (opt-in) — v0_31
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = 'Stop'

$repo = Get-Location
$bootstrap = Join-Path $repo 'tools\_bootstrap.ps1'
if (-not (Test-Path -LiteralPath $bootstrap)) { throw '[STOP] tools/_bootstrap.ps1 não encontrado.' }
. $bootstrap

Write-Host ('[DIAG] Repo: ' + $repo)

$v1Page = Join-Path $repo 'src\app\c\[slug]\page.tsx'
if (-not (Test-Path -LiteralPath $v1Page)) { throw ('[STOP] Não achei: ' + $v1Page) }
Write-Host ('[DIAG] V1 page: ' + $v1Page)

$raw = Get-Content -LiteralPath $v1Page -Raw
$orig = $raw

# 1) garantir import do redirect
$hasNextNav = $raw -match "from\s+['""]next/navigation['""]"
if ($hasNextNav) {
  # tenta inserir redirect dentro de import { ... } existente
  $m = [regex]::Match($raw, "import\s+\{(?<inside>[^}]*)\}\s+from\s+['""]next/navigation['""]\s*;")
  if ($m.Success) {
    $inside = $m.Groups['inside'].Value
    if ($inside -notmatch "\bredirect\b") {
      $inside2 = ($inside.Trim())
      if ($inside2.Length -gt 0) { $inside2 = $inside2 + ", redirect" } else { $inside2 = "redirect" }
      $oldLine = $m.Value
      $newLine = "import { " + $inside2 + " } from `"next/navigation`";"
      $raw = $raw.Replace($oldLine, $newLine)
      Write-Host '[OK] import next/navigation: adicionou redirect'
    } else {
      Write-Host '[OK] import next/navigation já tem redirect'
    }
  } else {
    # existe next/navigation mas não no formato esperado → adiciona import separado no topo
    $raw = "import { redirect } from `"next/navigation`";`n" + $raw
    Write-Host '[OK] adicionou import redirect (linha nova)'
  }
} else {
  $raw = "import { redirect } from `"next/navigation`";`n" + $raw
  Write-Host '[OK] adicionou import redirect (linha nova)'
}

# 2) inserir lógica de ui.default após carregar caderno
# procura por: const X = await loadCaderno...(slug)
$lines = $raw -split "`r?`n"
$out = New-Object System.Collections.Generic.List[string]
$changed = $false
$inserted = $false

for ($i=0; $i -lt $lines.Length; $i++) {
  $ln = $lines[$i]
  $out.Add($ln)

  if (-not $inserted) {
    $mm = [regex]::Match($ln, "^\s*(const|let)\s+(?<v>[A-Za-z_][A-Za-z0-9_]*)\s*=\s*await\s+loadCaderno[A-Za-z0-9_]*\s*\(")
    if ($mm.Success) {
      $v = $mm.Groups['v'].Value

      # evita duplicar
      $peek = ($lines -join "`n")
      if ($peek -match "meta\?\.\s*ui\?\.\s*default" -or $peek -match "\buiDefault\b") {
        Write-Host '[OK] parece que ui.default já existe — não vou duplicar'
        $inserted = $true
        continue
      }

      $indent = ''
      $m2 = [regex]::Match($ln, '^(\s*)')
      if ($m2.Success) { $indent = $m2.Groups[1].Value }

      $out.Add($indent + 'const uiDefault = (' + $v + ' as { meta?: { ui?: { default?: string } } }).meta?.ui?.default;')
      $out.Add($indent + 'if (uiDefault === "v2") {')
      $out.Add($indent + '  redirect("/c/" + slug + "/v2");')
      $out.Add($indent + '}')
      $inserted = $true
      $changed = $true
      Write-Host ('[OK] inseriu redirect opt-in (meta.ui.default) após carregar ' + $v)
    }
  }
}

$raw2 = ($out -join "`n")

if ($raw2 -ne $orig) {
  $bk = BackupFile $v1Page
  WriteUtf8NoBom $v1Page $raw2
  Write-Host ('[OK] patched: ' + $v1Page)
  if ($bk) { Write-Host ('[BK] ' + $bk) }
} else {
  Write-Host '[OK] no change: V1 page'
}

# 3) VERIFY
RunPs1 (Join-Path $repo 'tools\cv-verify.ps1') @()

# 4) REPORT
$report = @(
  '# CV — Extra v0_31 — meta.ui.default (V1→V2 opt-in)',
  '',
  '## O que mudou',
  '- /c/[slug] agora pode redirecionar para /c/[slug]/v2 se meta.ui.default === "v2".',
  '- Se a flag não existir, V1 continua como sempre.',
  '',
  '## Como usar',
  '- No meta do caderno, adicione algo como:',
  '  - "ui": { "default": "v2" }',
  '',
  '## Arquivo alterado',
  '- src/app/c/[slug]/page.tsx',
  '',
  '## Verify',
  '- tools/cv-verify.ps1 (Guard → Lint → Build)',
  ''
) -join "`n"

WriteReport 'cv-v2-extra-ui-default-redirect-v0_31.md' $report | Out-Null
Write-Host '[OK] v0_31 aplicado e verificado.'