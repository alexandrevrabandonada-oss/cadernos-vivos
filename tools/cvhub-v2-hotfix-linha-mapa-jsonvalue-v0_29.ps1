# CV — V2 Hotfix — linha/linha-do-tempo: tipar mapa (unknown -> JsonValue) — v0_29
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = 'Stop'

$repo = Get-Location
$bootstrap = Join-Path $repo 'tools\_bootstrap.ps1'
if (-not (Test-Path -LiteralPath $bootstrap)) { throw '[STOP] tools/_bootstrap.ps1 não encontrado.' }
. $bootstrap

Write-Host ('[DIAG] Repo: ' + $repo)

$targets = @(
  (Join-Path $repo 'src\app\c\[slug]\v2\linha\page.tsx'),
  (Join-Path $repo 'src\app\c\[slug]\v2\linha-do-tempo\page.tsx')
)

function EnsureJsonValueTyping([string]$file) {
  if (-not (Test-Path -LiteralPath $file)) { Write-Host ('[SKIP] não achei: ' + $file); return }

  $raw = Get-Content -LiteralPath $file -Raw
  $raw2 = $raw
  $changed = $false

  # 1) garantir import type JsonValue
  if ($raw2 -notmatch 'import\s+type\s+\{\s*JsonValue\s*\}\s+from\s+["'']@\/lib\/v2["'']\s*;') {
    # insere após o último import do topo
    $lines = $raw2 -split "`r?`n"
    $out = New-Object System.Collections.Generic.List[string]
    $inserted = $false

    for ($i=0; $i -lt $lines.Count; $i++) {
      $out.Add($lines[$i])
      if (-not $inserted) {
        $isImport = $lines[$i] -match '^\s*import\s+'
        $nextIsImport = $false
        if ($i -lt ($lines.Count-1)) { $nextIsImport = $lines[$i+1] -match '^\s*import\s+' }

        if ($isImport -and (-not $nextIsImport)) {
          $out.Add('import type { JsonValue } from "@/lib/v2";')
          $inserted = $true
        }
      }
    }

    if ($inserted) {
      $raw2 = ($out -join "`n")
      $changed = $true
    }
  }

  # 2) tipar const mapa = c.mapa;
  if ($raw2 -match 'const\s+mapa\s*=\s*c\.mapa\s*;') {
    $raw2 = $raw2 -replace 'const\s+mapa\s*=\s*c\.mapa\s*;', 'const mapa = c.mapa as unknown as JsonValue;'
    $changed = $true
  } elseif ($raw2 -match 'const\s+mapa\s*=\s*c\.mapa') {
    # fallback (caso tenha type annotations / formatting)
    $raw2 = $raw2 -replace 'const\s+mapa\s*=\s*c\.mapa(\s*);', 'const mapa = c.mapa as unknown as JsonValue$1;'
    $changed = $true
  } else {
    # 3) fallback: cast direto no JSX (se não achar declaração)
    if ($raw2 -match 'mapa=\{mapa\}') {
      $raw2 = $raw2 -replace 'mapa=\{mapa\}', 'mapa={mapa as unknown as JsonValue}'
      $changed = $true
    }
  }

  if ($changed -and ($raw2 -ne $raw)) {
    $bk = BackupFile $file
    WriteUtf8NoBom $file $raw2
    Write-Host ('[OK] patched: ' + $file)
    if ($bk) { Write-Host ('[BK] ' + $bk) }
  } else {
    Write-Host ('[OK] no change: ' + $file)
  }
}

foreach ($t in $targets) { EnsureJsonValueTyping $t }

# VERIFY
RunPs1 (Join-Path $repo 'tools\cv-verify.ps1') @()

# REPORT
$report = @(
  '# CV — Hotfix v0_29 — Linha V2: mapa unknown -> JsonValue',
  '',
  '## Causa raiz',
  '- loadCadernoV2 devolve c.mapa tipado como unknown; TimelineV2 exige JsonValue.',
  '',
  '## Fix',
  '- Adiciona: import type { JsonValue } from "@/lib/v2";',
  '- Tipagem: const mapa = c.mapa as unknown as JsonValue;',
  '',
  '## Arquivos',
  '- src/app/c/[slug]/v2/linha/page.tsx',
  '- src/app/c/[slug]/v2/linha-do-tempo/page.tsx',
  '',
  '## Verify',
  '- tools/cv-verify.ps1 (Guard → Lint → Build)',
  ''
) -join "`n"

WriteReport 'cv-v2-hotfix-linha-mapa-jsonvalue-v0_29.md' $report | Out-Null
Write-Host '[OK] v0_29 aplicado e verificado.'