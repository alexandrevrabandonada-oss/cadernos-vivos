# CV — Hotfix — Next 16.1 params Promise + ReadingControls (hydrated sem setState em effect) + MapaDockV2 props + V2Nav key — v0_36
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$bootstrap = Join-Path $repo "tools\_bootstrap.ps1"
if (-not (Test-Path -LiteralPath $bootstrap)) { throw "[STOP] tools/_bootstrap.ps1 não encontrado." }
. $bootstrap

Write-Host ("[DIAG] Repo: " + $repo)

function AddHydratedToUseMemoDeps([string]$s, [ref]$didChange) {
  $pos = 0
  $sb = New-Object System.Text.StringBuilder
  $changed = $false

  while ($true) {
    $idx = $s.IndexOf("useMemo(", $pos)
    if ($idx -lt 0) { [void]$sb.Append($s.Substring($pos)); break }

    $j = $idx + 7
    $paren = 1
    $inStr = $false
    $strCh = ''
    $esc = $false
    $commaPos = -1

    while ($j -lt $s.Length) {
      $ch = $s[$j]
      if ($inStr) {
        if ($esc) { $esc = $false }
        elseif ($ch -eq '\') { $esc = $true }
        elseif ($ch -eq $strCh) { $inStr = $false }
      } else {
        if ($ch -eq '"' -or $ch -eq "'" -or $ch -eq '`') { $inStr = $true; $strCh = $ch }
        elseif ($ch -eq '(') { $paren++ }
        elseif ($ch -eq ')') { $paren--; if ($paren -le 0) { break } }
        elseif ($ch -eq ',' -and $paren -eq 1) { $commaPos = $j; break }
      }
      $j++
    }

    if ($commaPos -lt 0) { [void]$sb.Append($s.Substring($pos, ($idx - $pos) + 7)); $pos = $idx + 7; continue }

    $k = $commaPos + 1
    while ($k -lt $s.Length -and [char]::IsWhiteSpace($s[$k])) { $k++ }
    if ($k -ge $s.Length -or $s[$k] -ne '[') {
      [void]$sb.Append($s.Substring($pos, ($commaPos - $pos) + 1))
      $pos = $commaPos + 1
      continue
    }

    $depsStart = $k
    $m = $depsStart
    $br = 0
    $inStr2 = $false
    $strCh2 = ''
    $esc2 = $false
    $depsEnd = -1

    while ($m -lt $s.Length) {
      $ch2 = $s[$m]
      if ($inStr2) {
        if ($esc2) { $esc2 = $false }
        elseif ($ch2 -eq '\') { $esc2 = $true }
        elseif ($ch2 -eq $strCh2) { $inStr2 = $false }
      } else {
        if ($ch2 -eq '"' -or $ch2 -eq "'" -or $ch2 -eq '`') { $inStr2 = $true; $strCh2 = $ch2 }
        elseif ($ch2 -eq '[') { $br++ }
        elseif ($ch2 -eq ']') { $br--; if ($br -eq 0) { $depsEnd = $m; break } }
      }
      $m++
    }

    if ($depsEnd -lt 0) { [void]$sb.Append($s.Substring($pos, ($depsStart - $pos) + 1)); $pos = $depsStart + 1; continue }

    [void]$sb.Append($s.Substring($pos, ($depsStart - $pos) + 1))

    $depsInner = $s.Substring($depsStart + 1, $depsEnd - $depsStart - 1)
    if ($depsInner -notmatch '\bhydrated\b') {
      $trim = $depsInner.Trim()
      if ([string]::IsNullOrWhiteSpace($trim)) { $depsInner = "hydrated" }
      else { $depsInner = $depsInner.TrimEnd() + ", hydrated" }
      $changed = $true
    }

    [void]$sb.Append($depsInner)
    [void]$sb.Append("]")
    $pos = $depsEnd + 1
  }

  if ($changed) { $didChange.Value = $true }
  return $sb.ToString()
}

# -----------------------
# 1) ReadingControls hotfix
# -----------------------
$rcPath = Join-Path $repo "src\components\ReadingControls.tsx"
if (-not (Test-Path -LiteralPath $rcPath)) { throw ("[STOP] Não achei: " + $rcPath) }
Write-Host ("[DIAG] ReadingControls: " + $rcPath)

$raw = Get-Content -LiteralPath $rcPath -Raw
if (-not $raw) { throw "[STOP] ReadingControls vazio/ilegível." }

$hasReactDefault = $raw.Contains("import React")
$lines = $raw -split "`r?`n"
$out = New-Object System.Collections.Generic.List[string]
$changedRC = $false

foreach ($ln in $lines) {
  $n = $ln

  # remove import redundante do tipo: import { ... } from "react";
  if ($hasReactDefault -and ($n -match '^\s*import\s*\{\s*[^}]+\}\s*from\s*["'']react["'']\s*;?\s*$')) {
    $changedRC = $true
    continue
  }

  # garante useSyncExternalStore no import React, { ... } from "react"
  if ($n -match '^\s*import\s+React\s*,\s*\{\s*([^}]*)\}\s*from\s*["'']react["'']\s*;?\s*$') {
    if ($n -notmatch '\buseSyncExternalStore\b') {
      $n = $n -replace '\}\s*from\s*["'']react["'']', ', useSyncExternalStore } from "react"'
      $changedRC = $true
    }
  }

  # troca hydrated state por store SSR-safe (sem setState em effect)
  if ($n -match '^\s*const\s*\[\s*hydrated\s*,\s*setHydrated\s*\]\s*=\s*useState\s*\(\s*false\s*\)\s*;?\s*$') {
    $indent = ""
    if ($n -match '^(\s*)') { $indent = $Matches[1] }
    $out.Add($indent + 'const hydrated = useSyncExternalStore((cb) => { return () => {}; }, () => true, () => false);') | Out-Null
    $changedRC = $true
    continue
  }

  # remove o effect que só faz setHydrated(true)
  if ($n -match 'setHydrated\s*\(\s*true\s*\)') {
    $changedRC = $true
    continue
  }

  $out.Add($n) | Out-Null
}

$text = ($out -join "`n")

# ajusta deps de useMemo para incluir hydrated (evita warning)
$flag = $false
$text2 = AddHydratedToUseMemoDeps $text ([ref]$flag)
if ($flag) { $changedRC = $true; $text = $text2 }

if ($changedRC) {
  $bk = BackupFile $rcPath
  WriteUtf8NoBom $rcPath $text
  Write-Host "[OK] patched: ReadingControls (useSyncExternalStore + remove setHydrated effect + deps useMemo)"
  if ($bk) { Write-Host ("[BK] " + $bk) }
} else {
  Write-Host "[OK] ReadingControls: nada pra mudar."
}

# -----------------------
# 2) MapaV2: MapaDockV2 precisa de mapa={mapa}
# -----------------------
$mapaV2 = Join-Path $repo "src\components\v2\MapaV2.tsx"
if (Test-Path -LiteralPath $mapaV2) {
  Write-Host ("[DIAG] MapaV2: " + $mapaV2)
  $mr = Get-Content -LiteralPath $mapaV2 -Raw
  $mLines = $mr -split "`r?`n"
  $mOut = New-Object System.Collections.Generic.List[string]
  $changedMapa = $false

  foreach ($ln in $mLines) {
    $n = $ln
    if ($n -match '<MapaDockV2\b' -and $n -match 'slug=\{slug\}' -and $n -notmatch 'mapa=\{mapa\}') {
      if ($n -match '/>\s*$') { $n = $n -replace '/>\s*$', ' mapa={mapa} />'; $changedMapa = $true }
      else { $n = $n -replace '>\s*$', ' mapa={mapa}>'; $changedMapa = $true }
    }
    $mOut.Add($n) | Out-Null
  }

  if ($changedMapa) {
    $bk = BackupFile $mapaV2
    WriteUtf8NoBom $mapaV2 ($mOut -join "`n")
    Write-Host "[OK] patched: MapaV2 (MapaDockV2 agora recebe mapa={mapa})"
    if ($bk) { Write-Host ("[BK] " + $bk) }
  } else {
    Write-Host "[OK] MapaV2: nada pra mudar (já passa mapa)."
  }
} else {
  Write-Host "[WARN] Não achei src/components/v2/MapaV2.tsx — pulando."
}

# -----------------------
# 3) Next 16.1: params/searchParams como Promise — patch pages V2
# -----------------------
$v2Root = Join-Path $repo "src\app\c\[slug]\v2"
if (Test-Path -LiteralPath $v2Root) {
  $targets = Get-ChildItem -LiteralPath $v2Root -Recurse -File -Filter "page.tsx"
  Write-Host ("[DIAG] V2 pages encontradas: " + $targets.Count)

  foreach ($f in $targets) {
    $p = $f.FullName
    $r = Get-Content -LiteralPath $p -Raw
    if (-not $r) { continue }

    $isAsync = $r.Contains("export default async function") -or $r.Contains("async function Page") -or $r.Contains("export default async function Page")
    if (-not $isAsync) { continue }

    $o = $r
    $o = $o.Replace("props.params.", "(await props.params).")
    $o = $o.Replace("= props.params;", "= await props.params;")

    # caso a page use params direto
    if ($o -match '\bparams\.slug\b') { $o = $o.Replace("params.", "(await params).") }
    if ($o -match '= params;') { $o = $o.Replace("= params;", "= await params;") }

    $o = $o.Replace("props.searchParams.", "(await props.searchParams).")
    $o = $o.Replace("= props.searchParams;", "= await props.searchParams;")
    if ($o -match '\bsearchParams\.') { $o = $o.Replace("searchParams.", "(await searchParams).") }
    if ($o -match '= searchParams;') { $o = $o.Replace("= searchParams;", "= await searchParams;") }

    if ($o -ne $r) {
      $bk = BackupFile $p
      WriteUtf8NoBom $p $o
      Write-Host ("[OK] patched: " + $p)
      if ($bk) { Write-Host ("[BK] " + $bk) }
    }
  }
} else {
  Write-Host "[WARN] Não achei src/app/c/[slug]/v2 — pulando patch de params."
}

# -----------------------
# 4) V2Nav: key mais único (evita warning no console)
# -----------------------
$v2nav = Join-Path $repo "src\components\v2\V2Nav.tsx"
if (Test-Path -LiteralPath $v2nav) {
  Write-Host ("[DIAG] V2Nav: " + $v2nav)
  $vr = Get-Content -LiteralPath $v2nav -Raw
  if ($vr -match 'key=\{it\.key\}') {
    $bk = BackupFile $v2nav
    $vr2 = $vr.Replace('key={it.key}', 'key={it.key + ":" + it.href}')
    WriteUtf8NoBom $v2nav $vr2
    Write-Host "[OK] patched: V2Nav (key={it.key + ':' + it.href})"
    if ($bk) { Write-Host ("[BK] " + $bk) }
  } else {
    Write-Host "[OK] V2Nav: nada pra mudar."
  }
}

# VERIFY
RunPs1 (Join-Path $repo "tools\cv-verify.ps1")

# REPORT (sem crases)
$rep = @(
  '# CV — Hotfix v0_36 — Next 16.1 + ReadingControls + MapaV2 + V2Nav',
  '',
  '## Next 16.1 (dev): params/searchParams Promise',
  '- Em pages async na V2: props.params.x / params.x -> (await ...).x',
  '',
  '## ReadingControls',
  '- Removeu hydration gate com setState em effect (lint proíbe).',
  '- Hydrated agora vem de useSyncExternalStore (SSR=false, client=true).',
  '- Ajustou deps de useMemo para incluir hydrated.',
  '',
  '## MapaV2',
  '- Passou mapa={mapa} para MapaDockV2 quando necessário (corrige build).',
  '',
  '## V2Nav',
  '- key mais único para evitar warning de keys duplicadas no console.',
  '',
  '## Verify',
  '- tools/cv-verify.ps1 (guard + lint + build)',
  ''
) -join "`n"

WriteReport "cv-hotfix-next16-readingcontrols-mapa-v2nav-v0_36.md" $rep | Out-Null
Write-Host "[OK] v0_36 aplicado e verificado."