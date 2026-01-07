param(
  [switch]$OpenReport,
  [switch]$NoVerify
)

$ErrorActionPreference = 'Stop'

function FindRepoRoot([string]$start) {
  $cur = (Resolve-Path -LiteralPath $start).Path
  while ($true) {
    if (Test-Path -LiteralPath (Join-Path $cur 'package.json')) { return $cur }
    $parent = Split-Path -Parent $cur
    if ($parent -eq $cur -or [string]::IsNullOrWhiteSpace($parent)) { break }
    $cur = $parent
  }
  throw 'Nao achei package.json. Rode na raiz do repo.'
}

function EnsureDir([string]$p) { if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function WriteUtf8NoBom([string]$p, [string]$content) { [IO.File]::WriteAllText($p, $content, [Text.UTF8Encoding]::new($false)) }
function ReadText([string]$p) { return [IO.File]::ReadAllText($p, [Text.UTF8Encoding]::new($false)) }

function BackupFile([string]$filePath, [string]$backupDir) {
  EnsureDir $backupDir
  $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
  $name = Split-Path -Leaf $filePath
  $dest = Join-Path $backupDir ($ts + '-' + $name + '.bak')
  Copy-Item -LiteralPath $filePath -Destination $dest -Force
  return $dest
}

function Rel([string]$base, [string]$full) {
  try { $b = (Resolve-Path -LiteralPath $base).Path.TrimEnd('\') } catch { $b = $base.TrimEnd('\') }
  try { $f = (Resolve-Path -LiteralPath $full).Path } catch { $f = $full }
  if ($f.StartsWith($b)) { return $f.Substring($b.Length).TrimStart('\') }
  return $f
}

function FindTagEnd([string]$s, [int]$startLt) {
  $i = $startLt
  $inQ = [char]0
  while ($i -lt $s.Length) {
    $ch = $s[$i]
    if ($inQ -ne [char]0) {
      if ($ch -eq $inQ) { $inQ = [char]0 }
      $i++
      continue
    }
    if ($ch -eq '"' -or $ch -eq "'") { $inQ = $ch; $i++; continue }
    if ($ch -eq '>') { return $i }
    $i++
  }
  return -1
}

function InsertImportAfterLastImport([string]$text, [string]$importLine) {
  if ($text.Contains($importLine)) { return $text }
  $lines = $text -split "`r?`n"
  $last = -1
  for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match '^\s*import\b') { $last = $i }
  }
  if ($last -ge 0) {
    $before = @()
    $after = @()
    if ($last -ge 0) { $before = $lines[0..$last] }
    if ($last + 1 -le $lines.Length - 1) { $after = $lines[($last+1)..($lines.Length-1)] }
    $out = @()
    $out += $before
    $out += $importLine
    $out += $after
    return ($out -join "`n")
  }
  return ($importLine + "`n" + $text)
}

function PatchHubRootTag([string]$raw) {
  $needle = 'data-cv2-hub="map"'
  $pos = $raw.IndexOf($needle)
  if ($pos -lt 0) { return @{ ok=$false; text=$raw; note='needle not found: data-cv2-hub="map"' } }

  if ($raw.Contains('Cv2HubKeyNavClient') -and $raw.Contains('rootId="cv2-hub-map"')) {
    return @{ ok=$true; text=$raw; note='already has Cv2HubKeyNavClient injection' }
  }

  $lt = $raw.LastIndexOf('<', $pos)
  if ($lt -lt 0) { return @{ ok=$false; text=$raw; note='could not find < before hub marker' } }

  $gt = FindTagEnd $raw $lt
  if ($gt -lt 0) { return @{ ok=$false; text=$raw; note='could not find end of hub start tag' } }

  $tag = $raw.Substring($lt, $gt - $lt + 1)

  if (-not $tag.Contains('id="cv2-hub-map"')) {
    $tag = $tag.TrimEnd('>')
    $tag = $tag + ' id="cv2-hub-map">'
  }

  if (-not $tag.Contains('aria-label=')) {
    $tag = $tag.TrimEnd('>')
    $tag = $tag + ' aria-label="Navegação do hub V2">'
  }

  $inject = "`n      <Cv2HubKeyNavClient rootId=""cv2-hub-map"" />`n"

  $out = $raw.Substring(0, $lt) + $tag + $inject + $raw.Substring($gt + 1)
  return @{ ok=$true; text=$out; note='patched hub root tag + injected client nav' }
}

$root = FindRepoRoot (Get-Location).Path
$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$step = 'cv-step-b5e-hub-keyboard-nav'

$reportsDir = Join-Path $root 'reports'
$backupDir  = Join-Path $root 'tools\_patch_backup'
EnsureDir $reportsDir
EnsureDir $backupDir

$reportPath = Join-Path $reportsDir ($step + '-' + $ts + '.md')

$actions = New-Object System.Collections.Generic.List[string]
$backups = New-Object System.Collections.Generic.List[string]

# 1) Criar client component (não renderiza UI; só adiciona comportamento)
$clientPath = Join-Path $root 'src\components\v2\Cv2HubKeyNavClient.tsx'
if (Test-Path -LiteralPath $clientPath) {
  $actions.Add('Cv2HubKeyNavClient.tsx: ja existe (nao alterei).')
} else {
  EnsureDir (Split-Path -Parent $clientPath)
  $lines = @(
    '"use client";',
    '',
    'import { useEffect } from "react";',
    '',
    'type Props = {',
    '  rootId: string;',
    '};',
    '',
    'function asArray<T extends Element>(list: NodeListOf<T>): T[] {',
    '  const out: T[] = [];',
    '  list.forEach((x) => out.push(x));',
    '  return out;',
    '}',
    '',
    'export function Cv2HubKeyNavClient({ rootId }: Props) {',
    '  useEffect(() => {',
    '    const root = document.getElementById(rootId);',
    '    if (!root) return;',
    '',
    '    const selector = "a.cv2-cardInteractive, a.cv2-card";',
    '    const items = asArray(root.querySelectorAll<HTMLAnchorElement>(selector));',
    '    if (!items.length) return;',
    '',
    '    let index = 0;',
    '',
    '    const apply = () => {',
    '      items.forEach((el, i) => {',
    '        el.tabIndex = i === index ? 0 : -1;',
    '        if (i === index) el.setAttribute("data-cv2-active", "1");',
    '        else el.removeAttribute("data-cv2-active");',
    '      });',
    '    };',
    '',
    '    const clamp = (n: number) => {',
    '      if (n < 0) return 0;',
    '      if (n >= items.length) return items.length - 1;',
    '      return n;',
    '    };',
    '',
    '    const setIndex = (n: number, focus: boolean) => {',
    '      index = clamp(n);',
    '      apply();',
    '      if (focus) {',
    '        const el = items[index];',
    '        if (el) el.focus();',
    '      }',
    '    };',
    '',
    '    const onFocusIn = (ev: FocusEvent) => {',
    '      const t = ev.target as Element | null;',
    '      if (!t) return;',
    '      const a = t.closest(selector) as HTMLAnchorElement | null;',
    '      if (!a) return;',
    '      const idx = items.indexOf(a);',
    '      if (idx >= 0) {',
    '        index = idx;',
    '        apply();',
    '      }',
    '    };',
    '',
    '    const onKeyDown = (ev: KeyboardEvent) => {',
    '      const key = ev.key;',
    '      const active = document.activeElement as Element | null;',
    '      if (!active) return;',
    '      if (!root.contains(active)) return;',
    '',
    '      if (key === "ArrowRight" || key === "ArrowDown") {',
    '        ev.preventDefault();',
    '        setIndex(index + 1, true);',
    '        return;',
    '      }',
    '      if (key === "ArrowLeft" || key === "ArrowUp") {',
    '        ev.preventDefault();',
    '        setIndex(index - 1, true);',
    '        return;',
    '      }',
    '      if (key === "Home") {',
    '        ev.preventDefault();',
    '        setIndex(0, true);',
    '        return;',
    '      }',
    '      if (key === "End") {',
    '        ev.preventDefault();',
    '        setIndex(items.length - 1, true);',
    '        return;',
    '      }',
    '      if (key === "Enter" || key === " ") {',
    '        const a = active.closest(selector) as HTMLAnchorElement | null;',
    '        if (a) {',
    '          ev.preventDefault();',
    '          a.click();',
    '        }',
    '      }',
    '    };',
    '',
    '    // init: roving tabindex',
    '    apply();',
    '',
    '    root.addEventListener("focusin", onFocusIn as any);',
    '    root.addEventListener("keydown", onKeyDown as any);',
    '',
    '    return () => {',
    '      root.removeEventListener("focusin", onFocusIn as any);',
    '      root.removeEventListener("keydown", onKeyDown as any);',
    '    };',
    '  }, [rootId]);',
    '',
    '  return null;',
    '}'
  )
  WriteUtf8NoBom $clientPath ($lines -join "`n")
  $actions.Add('Created src/components/v2/Cv2HubKeyNavClient.tsx (use client; keyboard nav).')
}

# 2) CSS: highlight do card ativo (escopado V2)
$globals = Join-Path $root 'src\app\globals.css'
if (-not (Test-Path -LiteralPath $globals)) { throw ('globals.css nao encontrado: ' + $globals) }

$gRaw = ReadText $globals
$cssMarker = 'CV2 HUB KEYS: active highlight'
if ($gRaw.Contains($cssMarker)) {
  $actions.Add('globals.css: active highlight ja existe (marker encontrado).')
} else {
  $bk = BackupFile $globals $backupDir
  $backups.Add((Split-Path -Leaf $bk))

  $css = @(
    '',
    '/* CV2 HUB KEYS: active highlight */',
    '.cv-v2 a.cv2-cardInteractive[data-cv2-active="1"] {',
    '  border-color: rgba(183,255,90,0.38);',
    '  box-shadow: 0 10px 30px rgba(0,0,0,0.40), 0 0 0 1px rgba(183,255,90,0.12) inset;',
    '}',
    ''
  ) -join "`n"

  WriteUtf8NoBom $globals ($gRaw.TrimEnd() + "`n" + $css)
  $actions.Add('globals.css: added active highlight for roving focus (data-cv2-active).')
}

# 3) Patch HomeV2Hub.tsx: import + id/aria + inject client
$hub = Join-Path $root 'src\components\v2\HomeV2Hub.tsx'
if (-not (Test-Path -LiteralPath $hub)) { throw ('HomeV2Hub.tsx nao encontrado: ' + $hub) }

$hubRaw = ReadText $hub
$patched = $hubRaw

$importLine = 'import { Cv2HubKeyNavClient } from "./Cv2HubKeyNavClient";'
$patched = InsertImportAfterLastImport $patched $importLine

$res = PatchHubRootTag $patched
if (-not $res.ok) { throw ('Falha ao patchar HomeV2Hub.tsx: ' + $res.note) }
$patched = $res.text

if ($patched -ne $hubRaw) {
  $bk2 = BackupFile $hub $backupDir
  $backups.Add((Split-Path -Leaf $bk2))
  WriteUtf8NoBom $hub $patched
  $actions.Add('HomeV2Hub.tsx: import + id/aria + injected Cv2HubKeyNavClient (' + $res.note + ').')
} else {
  $actions.Add('HomeV2Hub.tsx: no changes needed.')
}

# 4) VERIFY
$verifyExit = 0
$verifyOut = ''
if (-not $NoVerify) {
  $verify = Join-Path $root 'tools\cv-verify.ps1'
  if (Test-Path -LiteralPath $verify) {
    $verifyOut = (& pwsh -NoProfile -ExecutionPolicy Bypass -File $verify 2>&1 | Out-String)
    $verifyExit = $LASTEXITCODE
  } else {
    $verifyOut = 'tools/cv-verify.ps1 nao encontrado (pulando)'
    $verifyExit = 0
  }
}

# 5) REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add('# CV — Step B5e: Hub keyboard nav (arrows + enter/home/end)')
$rep.Add('')
$rep.Add('- when: ' + $ts)
$rep.Add('- repo: ' + $root)
$rep.Add('')
$rep.Add('## ACTIONS')
foreach ($a in $actions) { $rep.Add('- ' + $a) }
$rep.Add('')
$rep.Add('## BACKUPS')
if ($backups.Count -eq 0) { $rep.Add('- (none)') } else { foreach ($b in $backups) { $rep.Add('- ' + $b) } }
$rep.Add('')
$rep.Add('## VERIFY')
$rep.Add('- exit: ' + $verifyExit)
$rep.Add('')
$rep.Add('--- VERIFY OUTPUT START ---')
foreach ($ln in ($verifyOut -split "`r?`n")) { $rep.Add($ln) }
$rep.Add('--- VERIFY OUTPUT END ---')
$rep.Add('')
$rep.Add('## NEXT')
if ($verifyExit -eq 0) {
  $rep.Add('- B5f: microtransicoes leves (opcional) + skeletons no Hub/Trilhas/Provas.')
  $rep.Add('- Depois: commit do bloco B5 (B5b..B5e) junto.')
} else {
  $rep.Add('- Corrigir verify e re-rodar.')
}

WriteUtf8NoBom $reportPath ($rep -join "`n")
Write-Host ('[OK] Report -> ' + $reportPath)
if ($OpenReport) { try { Start-Process $reportPath | Out-Null } catch {} }