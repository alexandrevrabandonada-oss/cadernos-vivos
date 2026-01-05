$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Write-Host ("[DIAG] Repo: " + $repo)

. (Join-Path $PSScriptRoot "_bootstrap.ps1")

$changed = New-Object System.Collections.Generic.List[string]

function GetIndent([string]$line) {
  $i = 0
  while ($i -lt $line.Length) {
    $ch = $line[$i]
    if ($ch -ne " " -and $ch -ne "`t") { break }
    $i++
  }
  return $line.Substring(0, $i)
}

function EnsureNotFoundImport([string]$raw) {
  if ($raw -match '\bnotFound\b' -and $raw -match 'from\s+"next/navigation"') { return $raw }

  if ($raw -match 'import\s*\{\s*([^}]*)\}\s*from\s*"next/navigation";') {
    return [regex]::Replace(
      $raw,
      'import\s*\{\s*([^}]*)\}\s*from\s*"next/navigation";',
      {
        $inside = $args[0].Groups[1].Value
        if ($inside -match '\bnotFound\b') { return $args[0].Value }
        return ('import { ' + $inside.Trim() + ', notFound } from "next/navigation";')
      },
      1
    )
  }

  # senão: inserir após o último import
  $lines = $raw -split "`r?`n"
  $out = New-Object System.Collections.Generic.List[string]
  $insertAt = -1
  for ($i=0; $i -lt $lines.Length; $i++) {
    if ($lines[$i].Trim().StartsWith("import ")) { $insertAt = $i }
  }
  if ($insertAt -ge 0) {
    for ($i=0; $i -lt $lines.Length; $i++) {
      $out.Add($lines[$i]) | Out-Null
      if ($i -eq $insertAt) {
        $out.Add('import { notFound } from "next/navigation";') | Out-Null
      }
    }
    return ($out -join "`n")
  }

  # fallback: topo do arquivo
  return ('import { notFound } from "next/navigation";' + "`n" + $raw)
}

function RepairBrokenPrefix([string]$raw) {
  $prefix = "const data = await getCaderno(slug);"
  $lines = $raw -split "`r?`n"
  $out = New-Object System.Collections.Generic.List[string]

  foreach ($line in $lines) {
    $trimL = $line.TrimStart()
    if ($trimL.StartsWith($prefix)) {
      $indent = GetIndent $line
      if ($trimL.Trim() -eq $prefix) {
        # remove linha pura "const data = await..."
        continue
      }
      $rest = $trimL.Substring($prefix.Length)
      $out.Add($indent + $rest.TrimStart()) | Out-Null
      continue
    }
    $out.Add($line) | Out-Null
  }

  # de-dupe simples de "let data: Awaited<ReturnType<typeof getCaderno>>;"
  $seenLet = $false
  $out2 = New-Object System.Collections.Generic.List[string]
  foreach ($line in $out) {
    $t = $line.Trim()
    if ($t -match '^let\s+data\s*:\s*Awaited<ReturnType<typeof\s+getCaderno>>\s*;\s*$') {
      if ($seenLet) { continue }
      $seenLet = $true
    }
    $out2.Add($line) | Out-Null
  }

  return ($out2 -join "`n")
}

# varrer pages V1 (exceto v2)
$root = Join-Path $repo "src\app\c\[slug]"
if (-not (Test-Path -LiteralPath $root)) {
  throw ("[STOP] nao achei pasta: " + $root)
}

$pages = Get-ChildItem -LiteralPath $root -Recurse -File -Filter "page.tsx" | Where-Object { $_.FullName -notmatch "\\v2\\" }
Write-Host ("[DIAG] V1 pages: " + $pages.Count)

foreach ($p in $pages) {
  $raw0 = Get-Content -LiteralPath $p.FullName -Raw

  # só mexe se tiver sinais do estrago (prefix colado) OU se tiver "return notFound()" sem import
  $looksBroken = ($raw0 -match 'const\s+data\s*=\s*await\s+getCaderno\(slug\);\s*let\s+data') -or
                 ($raw0 -match 'const\s+data\s*=\s*await\s+getCaderno\(slug\);\s*try\s*\{') -or
                 ($raw0 -match 'const\s+data\s*=\s*await\s+getCaderno\(slug\);\s*\}') -or
                 ($raw0 -match 'const\s+data\s*=\s*await\s+getCaderno\(slug\);\s*data\s*=') -or
                 (($raw0 -match 'return\s+notFound\(\)') -and -not ($raw0 -match 'from\s+"next/navigation"'))

  if (-not $looksBroken) { continue }

  $raw1 = RepairBrokenPrefix $raw0
  $raw2 = EnsureNotFoundImport $raw1

  if ($raw2 -ne $raw0) {
    $bk = BackupFile $p.FullName
    WriteUtf8NoBom $p.FullName $raw2
    Write-Host ("[OK] repaired: " + $p.FullName)
    if ($bk) { Write-Host ("[BK] " + $bk) }
    $changed.Add($p.FullName) | Out-Null
  }
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Repair v0_52 — conserta prefix quebrado em pages V1 (/c/[slug])") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que aconteceu") | Out-Null
$rep.Add("- Linhas foram corrompidas com prefixo colado `const data = await getCaderno(slug);` no começo de várias linhas, gerando múltiplas defs/const reassign e quebrando build.") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que foi feito") | Out-Null
$rep.Add("- Remove prefixo colado linha-a-linha.") | Out-Null
$rep.Add("- Remove linha pura `const data = await getCaderno(slug);` (pra não sobrar const).") | Out-Null
$rep.Add("- Garante import de `notFound` quando necessário.") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
if ($changed.Count -eq 0) {
  $rep.Add("- (nenhum — nada parecia corrompido)") | Out-Null
} else {
  foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
}
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null
$rep.Add("") | Out-Null

$rp = WriteReport "cv-repair-v1-notfound-broken-prefix-v0_52.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Repair v0_52 aplicado e verificado."