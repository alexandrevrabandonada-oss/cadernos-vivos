# CV — Hotfix — ReadingControls hydration mismatch (SSR vs Client) — v0_33
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

$repo = Get-Location
$bootstrap = Join-Path $repo "tools\_bootstrap.ps1"
if (Test-Path -LiteralPath $bootstrap) { . $bootstrap } else { throw "[STOP] tools/_bootstrap.ps1 não encontrado." }

Write-Host ("[DIAG] Repo: " + $repo)

# 1) localizar ReadingControls.tsx
$candidates = @(
  (Join-Path $repo "src\components\ReadingControls.tsx"),
  (Join-Path $repo "src\components\ReadingControls\index.tsx"),
  (Join-Path $repo "src\components\ReadingControls\ReadingControls.tsx"),
  (Join-Path $repo "src\components\reading\ReadingControls.tsx")
)

$rcPath = $null
foreach ($p in $candidates) { if (Test-Path -LiteralPath $p) { $rcPath = $p; break } }

if (-not $rcPath) {
  $hits = Get-ChildItem -LiteralPath (Join-Path $repo "src") -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "*ReadingControls*.tsx" } |
    Select-Object -First 1
  if ($hits) { $rcPath = $hits.FullName }
}

if (-not $rcPath) { throw "[STOP] Não achei ReadingControls*.tsx em src/." }

Write-Host ("[DIAG] ReadingControls: " + $rcPath)

$raw = Get-Content -LiteralPath $rcPath -Raw
if (-not $raw) { throw "[STOP] ReadingControls vazio/ilegível." }

# Se já tem hydrated gate, não duplica
if ($raw.Contains("const [hydrated, setHydrated]")) {
  Write-Host "[OK] ReadingControls já tem hydrated gate — nada a fazer."
  RunPs1 (Join-Path $repo "tools\cv-verify.ps1")
  WriteReport "cv-hotfix-readingcontrols-hydration-v0_33.md" "# CV — Hotfix v0_33 — já estava aplicado" | Out-Null
  exit 0
}

$lines = $raw -split "`r?`n"
$out = New-Object System.Collections.Generic.List[string]
$changed = $false

# 2) garantir import de useState/useEffect
$reactImportIdx = -1
for ($i=0; $i -lt $lines.Length; $i++) {
  $ln = $lines[$i]
  if ($ln -match "from\s+['""]react['""]\s*;?\s*$") {
    $reactImportIdx = $i
    break
  }
}

if ($reactImportIdx -ge 0) {
  $ln = $lines[$reactImportIdx]
  if ($ln -match "import\s*\{([^}]*)\}\s*from\s+['""]react['""]") {
    $inside = $Matches[1]
    $parts = @()
    foreach ($p in ($inside -split ",")) {
      $t = $p.Trim()
      if ($t) { $parts += $t }
    }
    if (-not ($parts -contains "useState")) { $parts += "useState"; $changed = $true }
    if (-not ($parts -contains "useEffect")) { $parts += "useEffect"; $changed = $true }

    if ($changed) {
      $newInside = ($parts -join ", ")
      $newLn = $ln -replace "import\s*\{[^}]*\}\s*from\s+['""]react['""]", ("import { " + $newInside + " } from `"react`"")
      $lines[$reactImportIdx] = $newLn
    }
  } else {
    # não usa import { } — adiciona um novo import logo após
    $ins = 'import { useEffect, useState } from "react";'
    $lines = $lines[0..$reactImportIdx] + @($ins) + $lines[($reactImportIdx+1)..($lines.Length-1)]
    $changed = $true
  }
} else {
  # sem import de react — adiciona no topo (após "use client" se existir)
  $insertAt = 0
  if ($lines.Length -gt 0 -and $lines[0].Trim().ToLower() -eq '"use client";') { $insertAt = 1 }
  $ins = 'import { useEffect, useState } from "react";'
  $lines = $lines[0..($insertAt-1)] + @($ins) + $lines[$insertAt..($lines.Length-1)]
  $changed = $true
}

# 3) inserir hydrated gate dentro do componente ReadingControls
# procura função ReadingControls
$fnIdx = -1
for ($i=0; $i -lt $lines.Length; $i++) {
  $ln = $lines[$i]
  if ($ln -match "function\s+ReadingControls\b" -or $ln -match "export\s+default\s+function\s+ReadingControls\b" -or $ln -match "export\s+function\s+ReadingControls\b") {
    $fnIdx = $i
    break
  }
}

if ($fnIdx -lt 0) {
  # fallback: procura "ReadingControls(" (caso arrow/const)
  for ($i=0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match "ReadingControls\s*\(") { $fnIdx = $i; break }
  }
}

if ($fnIdx -lt 0) { throw "[STOP] Não consegui localizar o corpo do componente ReadingControls para inserir hydrated gate." }

# achar a linha com "{" que abre o corpo
$braceIdx = -1
for ($i=$fnIdx; $i -lt [Math]::Min($fnIdx+15, $lines.Length); $i++) {
  if ($lines[$i].Contains("{")) { $braceIdx = $i; break }
}
if ($braceIdx -lt 0) { throw "[STOP] Não achei '{' de abertura do componente ReadingControls." }

# indentação
$indent = ""
if ($lines[$braceIdx] -match "^(\s*)") { $indent = $Matches[1] + "  " } else { $indent = "  " }

# insere logo após a abertura
$inject = @(
  ($indent + 'const [hydrated, setHydrated] = useState(false);'),
  ($indent + 'useEffect(() => { setHydrated(true); }, []);'),
  ($indent + '')
)

$newLines = New-Object System.Collections.Generic.List[string]
for ($i=0; $i -lt $lines.Length; $i++) {
  $newLines.Add($lines[$i]) | Out-Null
  if ($i -eq $braceIdx) {
    foreach ($x in $inject) { $newLines.Add($x) | Out-Null }
    $changed = $true
  }
}
$lines = $newLines.ToArray()

# 4) substituir checks "typeof window !== 'undefined'" para depender de hydrated
# (mantém SSR e 1º render do client iguais; depois do mount, hydrated=true libera o comportamento)
$text = ($lines -join "`n")

$before = $text

# com &&
$text = [regex]::Replace($text, 'typeof\s+window\s*!==\s*(?:"|'')undefined(?:"|'')\s*&&\s*', 'hydrated && ')
$text = [regex]::Replace($text, 'typeof\s+window\s*!=\s*(?:"|'')undefined(?:"|'')\s*&&\s*', 'hydrated && ')

# sozinho
$text = [regex]::Replace($text, 'typeof\s+window\s*!==\s*(?:"|'')undefined(?:"|'')', 'hydrated')
$text = [regex]::Replace($text, 'typeof\s+window\s*!=\s*(?:"|'')undefined(?:"|'')', 'hydrated')

if ($text -ne $before) { $changed = $true }

# 5) gravar
if ($changed) {
  $bk = BackupFile $rcPath
  WriteUtf8NoBom $rcPath $text
  Write-Host "[OK] patched: ReadingControls (hydrated gate + checks estáveis SSR/client)"
  if ($bk) { Write-Host ("[BK] " + $bk) }
} else {
  Write-Host "[OK] nada para mudar (já estava estável)."
}

# 6) VERIFY
RunPs1 (Join-Path $repo "tools\cv-verify.ps1")

# 7) REPORT
$rep = @(
  "# CV — Hotfix v0_33 — ReadingControls hydration mismatch",
  "",
  "## Sintoma",
  "- Hydration failed: SSR renderizou 'Ouvir (indisponível)'/disabled, client renderizou 'Ouvir'/enabled.",
  "",
  "## Causa",
  "- Client Component calculava disponibilidade (window/speechSynthesis) no render, mudando entre SSR e client.",
  "",
  "## Fix",
  "- Adiciona gate `hydrated` (useState(false) + useEffect -> true).",
  "- Troca checks `typeof window !== 'undefined'` para depender de `hydrated`.",
  "- Mantém SSR e 1º render do client iguais; após mount, libera o estado real.",
  "",
  "## Arquivo",
  "- " + $rcPath,
  "",
  "## Verify",
  "- tools/cv-verify.ps1 (guard + lint + build)",
  ""
) -join "`n"

WriteReport "cv-hotfix-readingcontrols-hydration-v0_33.md" $rep | Out-Null
Write-Host "[OK] v0_33 aplicado e verificado."