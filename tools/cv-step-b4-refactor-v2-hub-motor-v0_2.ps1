param(
  [switch]$OpenReport,
  [switch]$NoVerify
)

$ErrorActionPreference = "Stop"

function FindRepoRoot([string]$start) {
  $cur = (Resolve-Path -LiteralPath $start).Path
  while ($true) {
    if (Test-Path -LiteralPath (Join-Path $cur "package.json")) { return $cur }
    $parent = Split-Path -Parent $cur
    if ($parent -eq $cur -or [string]::IsNullOrWhiteSpace($parent)) { break }
    $cur = $parent
  }
  throw "Não achei package.json. Rode na raiz do repo."
}

$root = FindRepoRoot (Get-Location).Path

# Bootstrap (opcional)
$bootstrap = Join-Path $root "tools\_bootstrap.ps1"
if (Test-Path -LiteralPath $bootstrap) { . $bootstrap }

# Fallbacks mínimos
if (-not (Get-Command EnsureDir -ErrorAction SilentlyContinue)) {
  function EnsureDir([string]$p) { if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
}
if (-not (Get-Command WriteUtf8NoBom -ErrorAction SilentlyContinue)) {
  function WriteUtf8NoBom([string]$p, [string]$content) { [IO.File]::WriteAllText($p, $content, [Text.UTF8Encoding]::new($false)) }
}
if (-not (Get-Command BackupFile -ErrorAction SilentlyContinue)) {
  function BackupFile([string]$filePath, [string]$backupDir) {
    EnsureDir $backupDir
    $ts = Get-Date -Format "yyyyMMdd-HHmmss"
    $name = Split-Path -Leaf $filePath
    $dest = Join-Path $backupDir ($ts + "-" + $name + ".bak")
    Copy-Item -LiteralPath $filePath -Destination $dest -Force
    return $dest
  }
}

function Rel([string]$base, [string]$full) {
  try { $b = (Resolve-Path -LiteralPath $base).Path.TrimEnd('\') } catch { $b = $base.TrimEnd('\') }
  try { $f = (Resolve-Path -LiteralPath $full).Path } catch { $f = $full }
  if ($f.StartsWith($b)) { return $f.Substring($b.Length).TrimStart('\') }
  return $f
}

function InsertAfterImports([string]$raw, [string[]]$insertLines) {
  $lines = @($raw -split "`n", 0, 'SimpleMatch')
  $lastImport = -1
  for ($i = 0; $i -lt $lines.Length; $i++) {
    $t = $lines[$i].TrimStart()
    if ($t.StartsWith("import ")) { $lastImport = $i; continue }
    if ($lastImport -ge 0 -and $t -ne "" -and -not $t.StartsWith("//")) { break }
  }
  if ($lastImport -lt 0) {
    return (($insertLines + @("") + $lines) -join "`n")
  }
  $before = @($lines[0..$lastImport])
  $after = @()
  if (($lastImport+1) -le ($lines.Length-1)) { $after = @($lines[($lastImport+1)..($lines.Length-1)]) }
  return (($before + $insertLines + $after) -join "`n")
}

function EnsureImportLine([string]$raw, [string]$importLine) {
  if ($raw -match [regex]::Escape($importLine)) { return $raw }
  return (InsertAfterImports $raw @($importLine))
}

function AddNamedImportToModule([string]$raw, [string]$modulePath, [string]$name, [switch]$TypeOnly) {
  # tenta achar import { ... } from "module"
  $lines = @($raw -split "`n", 0, 'SimpleMatch')
  for ($i = 0; $i -lt $lines.Length; $i++) {
    $line = $lines[$i]
    if ($line -match ("^\s*import\s+(type\s+)?{\s*([^}]*)\s*}\s*from\s*['""]" + [regex]::Escape($modulePath) + "['""];\s*$")) {
      $isType = $Matches[1]
      $inside = $Matches[2]
      $parts = @()
      foreach ($p in ($inside -split ",")) { $t = $p.Trim(); if ($t) { $parts += $t } }
      if (-not ($parts -contains $name)) { $parts += $name }
      $newInside = ($parts | Select-Object -Unique) -join ", "
      if ($TypeOnly) {
        $lines[$i] = ("import type { " + $newInside + " } from """ + $modulePath + """;")
      } else {
        if ($isType) {
          # manter type-only se já era type-only
          $lines[$i] = ("import type { " + $newInside + " } from """ + $modulePath + """;")
        } else {
          $lines[$i] = ("import { " + $newInside + " } from """ + $modulePath + """;")
        }
      }
      return ($lines -join "`n")
    }
  }

  # não achou import existente -> insere um novo
  if ($TypeOnly) {
    return (InsertAfterImports $raw @('import type { ' + $name + ' } from "' + $modulePath + '";'))
  }
  return (InsertAfterImports $raw @('import { ' + $name + ' } from "' + $modulePath + '";'))
}

function RemoveNamedImport([string]$raw, [string]$name) {
  $lines = @($raw -split "`n", 0, 'SimpleMatch')
  for ($i = 0; $i -lt $lines.Length; $i++) {
    $line = $lines[$i]
    if ($line -match "^\s*import\s*{\s*([^}]*)\s*}\s*from\s*(['""][^'""]+['""])\s*;\s*$") {
      $inside = $Matches[1]
      $from = $Matches[2]
      $parts = @()
      foreach ($p in ($inside -split ",")) {
        $t = $p.Trim()
        if ($t) { $parts += $t }
      }
      $kept = @()
      foreach ($p in $parts) {
        if ($p -match ("^" + [regex]::Escape($name) + "(\s+as\s+.+)?$")) { continue }
        $kept += $p
      }
      if ($kept.Count -eq $parts.Count) { continue } # não tinha
      if ($kept.Count -eq 0) {
        $lines[$i] = "" # remove a linha
      } else {
        $lines[$i] = ("import { " + ($kept -join ", ") + " } from " + $from + ";")
      }
    }
  }
  return (($lines | Where-Object { $_ -ne "" }) -join "`n")
}

function EnsureGenerateMetadata([string]$raw) {
  if ($raw -match "export\s+async\s+function\s+generateMetadata") { return $raw }

  $idx = $raw.IndexOf("export default")
  if ($idx -lt 0) { return $raw }

  $block = @(
    '',
    'export async function generateMetadata({ params }: { params: { slug: string } }): Promise<Metadata> {',
    '  const meta = await cvReadMetaLoose(params.slug);',
    '  const title = (typeof meta.title === "string" && meta.title.trim().length) ? meta.title.trim() : params.slug;',
    '  const m = meta as unknown as Record<string, unknown>;',
    '  const rawDesc = (typeof m["description"] === "string") ? (m["description"] as string) : "";',
    '  const description = rawDesc.trim().length ? rawDesc.trim() : undefined;',
    '  return {',
    '    title: title + " • Cadernos Vivos",',
    '    description,',
    '  };',
    '}',
    ''
  ) -join "`n"

  return ($raw.Substring(0, $idx) + $block + $raw.Substring($idx))
}

function EnsureNotFoundGuard([string]$raw, [ref]$didAddImport) {
  if ($raw -notmatch "\bloadCadernoV2\s*\(") { return $raw }
  if ($raw -match "\bnotFound\s*\(") { return $raw }

  # procura: const X = await loadCadernoV2(
  $m = [regex]::Match($raw, "(?m)^\s*const\s+(?<var>[A-Za-z_][A-Za-z0-9_]*)\s*=\s*await\s+loadCadernoV2\s*\(")
  if (-not $m.Success) { return $raw }

  $var = $m.Groups["var"].Value
  $lines = @($raw -split "`n", 0, 'SimpleMatch')
  for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match ("^\s*const\s+" + [regex]::Escape($var) + "\s*=\s*await\s+loadCadernoV2\s*\(")) {
      # insere após essa linha
      $insert = "  if (!" + $var + ") return notFound();"
      $new = @()
      $new += $lines[0..$i]
      $new += $insert
      if (($i+1) -le ($lines.Length-1)) { $new += $lines[($i+1)..($lines.Length-1)] }
      $didAddImport.Value = $true
      return ($new -join "`n")
    }
  }
  return $raw
}

# Paths
$target = Join-Path $root "src\app\c\[slug]\v2\page.tsx"
if (-not (Test-Path -LiteralPath $target)) { throw ("target não encontrado: " + $target) }

$reportsDir = Join-Path $root "reports"
$backupDir  = Join-Path $root "tools\_patch_backup"
EnsureDir $reportsDir
EnsureDir $backupDir

$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$reportPath = Join-Path $reportsDir ("cv-step-b4-refactor-v2-hub-motor-" + $ts + ".md")

$raw = [IO.File]::ReadAllText($target, [Text.UTF8Encoding]::new($false))
$bk = BackupFile $target $backupDir

$actions = @()

# 1) Troca getCaderno -> loadCadernoV2 (somente se houver getCaderno)
if ($raw -match "\bgetCaderno\b") {
  $raw = RemoveNamedImport $raw "getCaderno"
  $raw = [regex]::Replace($raw, "\bgetCaderno\b", "loadCadernoV2")
  $actions += "Replaced getCaderno -> loadCadernoV2 (imports + calls)."
}

# 2) Garante import de loadCadernoV2 (sem duplicar)
if ($raw -notmatch "\bloadCadernoV2\b") {
  # se não usa, não adiciona import
} else {
  $raw = AddNamedImportToModule $raw "@/lib/v2" "loadCadernoV2"
  $actions += 'Ensured import { loadCadernoV2 } from "@/lib/v2".'
}

# 3) generateMetadata + imports (Metadata + cvReadMetaLoose)
$hadGen = ($raw -match "export\s+async\s+function\s+generateMetadata")
if (-not $hadGen) {
  $raw = EnsureImportLine $raw 'import type { Metadata } from "next";'
  $raw = EnsureImportLine $raw 'import { cvReadMetaLoose } from "@/lib/v2/load";'
  $raw = EnsureGenerateMetadata $raw
  $actions += "Added generateMetadata() using cvReadMetaLoose."
}

# 4) Guard notFound() se der pra inserir com segurança
$needNotFoundImport = $false
$raw2 = EnsureNotFoundGuard $raw ([ref]$needNotFoundImport)
if ($raw2 -ne $raw) {
  $raw = $raw2
  if ($needNotFoundImport) {
    $raw = EnsureImportLine $raw 'import { notFound } from "next/navigation";'
    $actions += "Added notFound() guard after loadCadernoV2."
  }
}

WriteUtf8NoBom $target $raw

# VERIFY
$verifyExit = 0
$verifyOut = ""
if (-not $NoVerify) {
  $verify = Join-Path $root "tools\cv-verify.ps1"
  if (Test-Path -LiteralPath $verify) {
    $verifyOut = (& pwsh -NoProfile -ExecutionPolicy Bypass -File $verify 2>&1 | Out-String)
    $verifyExit = $LASTEXITCODE
  } else {
    $verifyOut = "tools/cv-verify.ps1 não encontrado (pulando)"
  }
}

# REPORT
$rep = @()
$rep += "# CV — Step B4: Refactor V2 Hub to use safe motor"
$rep += ""
$rep += ("- when: " + $ts)
$rep += ("- target: `" + (Rel $root $target) + "`")
$rep += ("- backup: `" + (Split-Path -Leaf $bk) + "`")
$rep += ""
$rep += "## ACTIONS"
if ($actions.Count -eq 0) { $rep += "- (no changes)" } else { foreach ($a in $actions) { $rep += ("- " + $a) } }
$rep += ""
$rep += "## VERIFY"
$rep += ("- exit: **" + $verifyExit + "**")
$rep += ""
$rep += '```'
$rep += ($verifyOut.TrimEnd())
$rep += '```'
$rep += ""
$rep += "## NEXT"
if ($verifyExit -eq 0) {
  $rep += "- ✅ Tudo verde. Próximo: B4a (Debate V2), B4b (Linha), B4c (Mapa)… sempre 1 página por tijolo."
} else {
  $rep += "- ⚠️ Verify falhou. Corrigir o erro apontado e re-rodar."
}

WriteUtf8NoBom $reportPath ($rep -join "`n")
Write-Host ("[OK] Report -> " + $reportPath)
if ($OpenReport) { try { Start-Process $reportPath | Out-Null } catch {} }