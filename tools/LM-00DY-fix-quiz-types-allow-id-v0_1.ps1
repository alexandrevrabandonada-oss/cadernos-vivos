param(
  [switch]$CleanNext,
  [switch]$Verify
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root  = (Get-Location).Path
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"

# bootstrap (se existir)
$boot = Join-Path $root "tools\_bootstrap.ps1"
if (Test-Path -LiteralPath $boot) { . $boot }

# fallbacks mínimos
if (-not (Get-Command EnsureDir -ErrorAction SilentlyContinue)) {
  function EnsureDir([string]$p) { if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
}
if (-not (Get-Command WriteUtf8NoBom -ErrorAction SilentlyContinue)) {
  function WriteUtf8NoBom([string]$p, [string]$c) { $enc = New-Object System.Text.UTF8Encoding($false); [IO.File]::WriteAllText($p, $c, $enc) }
}
if (-not (Get-Command BackupFile -ErrorAction SilentlyContinue)) {
  function BackupFile([string]$src, [string]$bkDir, [string]$tag) {
    EnsureDir $bkDir
    $name = ($src.Substring($root.Length)).TrimStart('\') -replace '[\\\/:]', '__'
    Copy-Item -Force -LiteralPath $src -Destination (Join-Path $bkDir ($tag + "__" + $name))
  }
}

Write-Host ("== LM-00DY FIX Quiz types allow id? == " + $stamp)
Write-Host ("Root: " + $root)

if ($CleanNext) {
  Write-Host "[CLEAN] removendo .next/.turbo/node_modules\.cache (best-effort)..."
  $targets = @(
    (Join-Path $root ".next"),
    (Join-Path $root ".turbo"),
    (Join-Path $root "node_modules\.cache")
  )
  foreach ($t in $targets) {
    if (Test-Path -LiteralPath $t) { Remove-Item -Recurse -Force -LiteralPath $t -ErrorAction SilentlyContinue }
  }
}

$bkDir = Join-Path $root ("tools\_patch_backup\" + $stamp + "-LM-00DY")
EnsureDir $bkDir

function PatchTypeAddOptionalId([string]$raw, [string]$typeName) {
  # retorna @{ raw = "..."; changed = 0/1 }
  $res = @{ raw = $raw; changed = 0 }

  # procura começo de type/interface QuizQuestion/QuizOption
  $rx = [regex]::new("(?m)^(?<indent>\s*)(export\s+)?(type|interface)\s+" + [regex]::Escape($typeName) + "\b")
  $m = $rx.Match($raw)
  if (-not $m.Success) { return $res }

  $start = $m.Index
  $open  = $raw.IndexOf("{", $start)
  if ($open -lt 0) { return $res }

  # acha o brace de fechamento (simples, mas suficiente pra type/interface)
  $depth = 0
  $close = -1
  for ($i = $open; $i -lt $raw.Length; $i++) {
    $ch = $raw[$i]
    if ($ch -eq "{") { $depth++ }
    elseif ($ch -eq "}") {
      $depth--
      if ($depth -eq 0) { $close = $i; break }
    }
  }
  if ($close -lt 0) { return $res }

  $block = $raw.Substring($open, ($close - $open + 1))
  if ($block -match "(?m)^\s*id\??\s*:") { return $res } # já tem id / id?

  $indent = $m.Groups["indent"].Value + "  "
  $insert = "`n" + $indent + "id?: string;"

  $rawNew = $raw.Substring(0, $open + 1) + $insert + $raw.Substring($open + 1)
  $res.raw = $rawNew
  $res.changed = 1
  return $res
}

$patched = New-Object System.Collections.Generic.List[string]

# varre app + src (se existir)
$scanRoots = @()
$scanRoots += (Join-Path $root "app")
$srcDir = Join-Path $root "src"
if (Test-Path -LiteralPath $srcDir) { $scanRoots += $srcDir }

$files = @()
foreach ($sr in $scanRoots) {
  if (Test-Path -LiteralPath $sr) {
    $files += Get-ChildItem -LiteralPath $sr -Recurse -File -Include *.ts,*.tsx -ErrorAction SilentlyContinue
  }
}

$changedAny = 0

foreach ($f in $files) {
  $raw = Get-Content -Raw -LiteralPath $f.FullName -Encoding UTF8

  $before = $raw
  $hit = $false

  if ($raw -match "\bQuizQuestion\b") {
    $p = PatchTypeAddOptionalId $raw "QuizQuestion"
    if ($p.changed -eq 1) { $raw = $p.raw; $hit = $true; $changedAny += 1 }
  }
  if ($raw -match "\bQuizOption\b") {
    $p2 = PatchTypeAddOptionalId $raw "QuizOption"
    if ($p2.changed -eq 1) { $raw = $p2.raw; $hit = $true; $changedAny += 1 }
  }

  if ($hit -and $raw -ne $before) {
    BackupFile $f.FullName $bkDir "types"
    WriteUtf8NoBom $f.FullName $raw
    $patched.Add($f.FullName) | Out-Null
    Write-Host ("[PATCH] " + $f.FullName.Substring($root.Length).TrimStart('\'))
  }
}

# fallback: se não achou definição nenhuma, remove id do QuizQuestion no course-content.ts (troca id: -> slug:)
if ($patched.Count -eq 0) {
  $fallbackRel = "app\formacao\cursos\direitos-trabalhistas-6x1\course-content.ts"
  $fallbackAbs = Join-Path $root $fallbackRel
  if (Test-Path -LiteralPath $fallbackAbs) {
    $raw = Get-Content -Raw -LiteralPath $fallbackAbs -Encoding UTF8
    $before = $raw

    # troca apenas "id:" do quiz (heurística simples: troca linhas id: "qX", para slug: "qX",)
    $raw = [regex]::Replace($raw, '(?m)^\s*id\s*:\s*"([^"]+)"\s*,\s*$', { param($m)
      $indent = $m.Value -replace '^(?<i>\s*).*$','$($Matches.i)'
      # acima pode falhar por $Matches, então faz manual:
      $line = $m.Value
      $sp = ($line -replace '^( *)id.*$','$1')
      if ($sp -eq $line) { $sp = "" }
      return ($sp + 'slug: "' + $m.Groups[1].Value + '",')
    })

    if ($raw -ne $before) {
      BackupFile $fallbackAbs $bkDir "fallback"
      WriteUtf8NoBom $fallbackAbs $raw
      $patched.Add($fallbackAbs) | Out-Null
      Write-Host ("[FALLBACK PATCH] " + $fallbackRel + " (id -> slug)")
    } else {
      throw "[STOP] Não achei definição de QuizQuestion/QuizOption e o fallback não alterou o course-content.ts."
    }
  } else {
    throw "[STOP] Não achei definição de QuizQuestion/QuizOption e também não achei o fallback: $fallbackAbs"
  }
}

# report
$repDir = Join-Path $root "reports"
EnsureDir $repDir
$rep = Join-Path $repDir ("LM-00DY-fix-quiz-types-allow-id-" + $stamp + ".md")

$lines = @()
$lines += "# LM-00DY — Fix Quiz types (permitir id?: string)"
$lines += ""
$lines += ("Data: " + (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"))
$lines += ("Root: " + $root)
$lines += ""
$lines += "## Patches"
foreach ($p in $patched) { $lines += ("- " + ($p.Substring($root.Length).TrimStart('\'))) }
$lines += ""
$lines += ("Backup -> " + $bkDir)
$lines += ""
$lines += "## Verify"
$lines += ("- CleanNext: " + [string]$CleanNext)
$lines += ("- Verify: " + [string]$Verify)

WriteUtf8NoBom $rep ($lines -join "`n")
Write-Host ("OK: report -> " + $rep)

if ($Verify) {
  Write-Host "[VERIFY] npm run build"
  npm run build
}

Write-Host "DONE."