# CV — Hotfix — ReadingControls: hydrated sem setState em effect (useSyncExternalStore) + deps useMemo + MapaDockV2 props — v0_35
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

$repo = Get-Location
$bootstrap = Join-Path $repo "tools\_bootstrap.ps1"
if (Test-Path -LiteralPath $bootstrap) { . $bootstrap } else { throw "[STOP] tools/_bootstrap.ps1 não encontrado." }

Write-Host ("[DIAG] Repo: " + $repo)

function AddHydratedToUseMemoDeps([string]$s, [ref]$didChange) {
  $pos = 0
  $sb = New-Object System.Text.StringBuilder
  $changed = $false

  while ($true) {
    $idx = $s.IndexOf("useMemo(", $pos)
    if ($idx -lt 0) {
      [void]$sb.Append($s.Substring($pos))
      break
    }

    # tenta achar a deps array desse useMemo com parsing leve (paren depth)
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
        if ($ch -eq '"' -or $ch -eq "'" -or $ch -eq '`') {
          $inStr = $true
          $strCh = $ch
        } elseif ($ch -eq '(') {
          $paren++
        } elseif ($ch -eq ')') {
          $paren--
          if ($paren -le 0) { break }
        } elseif ($ch -eq ',' -and $paren -eq 1) {
          $commaPos = $j
          break
        }
      }

      $j++
    }

    if ($commaPos -lt 0) {
      # não achou deps; só passa reto
      [void]$sb.Append($s.Substring($pos, ($idx - $pos) + 7))
      $pos = $idx + 7
      continue
    }

    $k = $commaPos + 1
    while ($k -lt $s.Length -and [char]::IsWhiteSpace($s[$k])) { $k++ }
    if ($k -ge $s.Length -or $s[$k] -ne '[') {
      # deps não é array literal; passa reto
      [void]$sb.Append($s.Substring($pos, ($commaPos - $pos) + 1))
      $pos = $commaPos + 1
      continue
    }

    $depsStart = $k

    # acha o fechamento do array deps (bracket depth)
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
        if ($ch2 -eq '"' -or $ch2 -eq "'" -or $ch2 -eq '`') {
          $inStr2 = $true
          $strCh2 = $ch2
        } elseif ($ch2 -eq '[') {
          $br++
        } elseif ($ch2 -eq ']') {
          $br--
          if ($br -eq 0) { $depsEnd = $m; break }
        }
      }
      $m++
    }

    if ($depsEnd -lt 0) {
      # não achou fim; passa reto
      [void]$sb.Append($s.Substring($pos, ($depsStart - $pos) + 1))
      $pos = $depsStart + 1
      continue
    }

    # agora sim: escreve até o '[' e ajusta deps
    [void]$sb.Append($s.Substring($pos, ($depsStart - $pos) + 1))

    $depsInner = $s.Substring($depsStart + 1, $depsEnd - $depsStart - 1)
    if ($depsInner -notmatch '\bhydrated\b') {
      $trim = $depsInner.Trim()
      if ([string]::IsNullOrWhiteSpace($trim)) {
        $depsInner = "hydrated"
      } else {
        # mantém o original, só adiciona hydrated no final
        $depsInner = $depsInner.TrimEnd() + ", hydrated"
      }
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
# 1) PATCH ReadingControls
# -----------------------
$rcPath = Join-Path $repo "src\components\ReadingControls.tsx"
if (-not (Test-Path -LiteralPath $rcPath)) { throw ("[STOP] Não achei: " + $rcPath) }
Write-Host ("[DIAG] ReadingControls: " + $rcPath)

$raw = Get-Content -LiteralPath $rcPath -Raw
if (-not $raw) { throw "[STOP] ReadingControls vazio/ilegível." }

$lines = $raw -split "`r?`n"
$out = New-Object System.Collections.Generic.List[string]
$changedRC = $false

foreach ($ln in $lines) {
  $n = $ln

  # import: injeta useSyncExternalStore no import React, { ... } from "react"
  if ($n -match '^\s*import\s+React\s*,\s*\{\s*([^}]*)\}\s*from\s*["'']react["'']\s*;?\s*$') {
    if ($n -notmatch '\buseSyncExternalStore\b') {
      $inside = $Matches[1].Trim()
      if ([string]::IsNullOrWhiteSpace($inside)) {
        $n = 'import React, { useSyncExternalStore } from "react";'
      } else {
        $n = $n -replace '\}\s*from\s*["'']react["'']', (', useSyncExternalStore } from "react"')
      }
      $changedRC = $true
    }
  }

  # troca o hydration gate: const [hydrated, setHydrated] = useState(false);
  if ($n -match '^\s*const\s*\[\s*hydrated\s*,\s*setHydrated\s*\]\s*=\s*useState\s*\(') {
    $indent = ""
    if ($n -match '^(\s*)') { $indent = $Matches[1] }
    $out.Add($indent + 'const hydrated = useSyncExternalStore(() => () => {}, () => true, () => false);') | Out-Null
    $changedRC = $true
    continue
  }

  # remove a linha do useEffect hydration que o lint proíbe
  if ($n -match 'useEffect\s*\(.*setHydrated\s*\(\s*true\s*\)') {
    $changedRC = $true
    continue
  }
  if ($n -match 'setHydrated\s*\(\s*true\s*\)') {
    $changedRC = $true
    continue
  }

  $out.Add($n) | Out-Null
}

$text = ($out -join "`n")

# garante deps de useMemo incluir hydrated (resolve o warning)
$flag = $false
$text2 = AddHydratedToUseMemoDeps $text ([ref]$flag)
if ($flag) { $changedRC = $true; $text = $text2 }

if ($changedRC) {
  $bk = BackupFile $rcPath
  WriteUtf8NoBom $rcPath $text
  Write-Host "[OK] patched: ReadingControls (hydrated via useSyncExternalStore; remove setHydrated effect; deps useMemo)"
  if ($bk) { Write-Host ("[BK] " + $bk) }
} else {
  Write-Host "[OK] ReadingControls: nada pra mudar."
}

# -----------------------
# 2) PATCH MapaV2: passar mapa p/ MapaDockV2 se estiver faltando
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
      if ($n -match '/>\s*$') {
        $n = $n -replace '/>\s*$', ' mapa={mapa} />'
        $changedMapa = $true
      } else {
        # se não for self-closing, injeta antes do '>'
        $n = $n -replace '>\s*$', ' mapa={mapa}>'
        $changedMapa = $true
      }
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
  Write-Host "[WARN] Não achei src/components/v2/MapaV2.tsx — pulando patch do mapa."
}

# VERIFY
RunPs1 (Join-Path $repo "tools\cv-verify.ps1")

# REPORT
$rep = @(
  "# CV — Hotfix v0_35 — ReadingControls + MapaV2",
  "",
  "## ReadingControls",
  "- Removeu hydration gate proibido pelo lint (setState em effect).",
  "- Agora `hydrated` vem de `useSyncExternalStore` (SSR=false / client=true).",
  "- Ajustou deps de `useMemo` para incluir `hydrated` (remove warning).",
  "",
  "## MapaV2",
  "- Se necessário, passou `mapa={mapa}` para `<MapaDockV2 />` (corrige build).",
  "",
  "## Verify",
  "- tools/cv-verify.ps1 (guard + lint + build)",
  ""
) -join "`n"

WriteReport "cv-hotfix-readingcontrols-hydrated-syncstore-mapa-props-v0_35.md" $rep | Out-Null
Write-Host "[OK] v0_35 aplicado e verificado."