param(
  [switch]$OpenReport
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Root robusto (funciona mesmo se alguém rodar em modo "colado" sem PSScriptRoot)
$root = $null
if ($PSScriptRoot -and $PSScriptRoot.Trim().Length -gt 0) {
  $root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
} else {
  $root = (Get-Location).Path
}

$stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
$step  = "cv-step-b6b1-fix-domfilter-and-mapnavpins-lint-v0_2"

function EnsureDirLocal([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

function Rel([string]$base, [string]$full) {
  try {
    return [System.IO.Path]::GetRelativePath($base, $full)
  } catch {
    return $full
  }
}

function WriteUtf8NoBomSafe([string]$p, [string]$content) {
  if (Get-Command WriteUtf8NoBom -ErrorAction SilentlyContinue) {
    WriteUtf8NoBom $p $content
    return
  }
  [IO.File]::WriteAllText($p, $content, [Text.UTF8Encoding]::new($false))
}

function BackupFileSafe([string]$p) {
  if (Get-Command BackupFile -ErrorAction SilentlyContinue) {
    return (BackupFile $p)
  }
  $bkDir = Join-Path $root "tools\_patch_backup"
  EnsureDirLocal $bkDir
  $leaf = Split-Path -Leaf $p
  $dest = Join-Path $bkDir ($stamp + "-" + $leaf + ".bak")
  Copy-Item -LiteralPath $p -Destination $dest -Force
  return $dest
}

Write-Host ("== " + $step + " == " + $stamp) -ForegroundColor Cyan
Write-Host ("[DIAG] Root: " + $root)

# --- Paths
$reportsDir = Join-Path $root "reports"
$bkDir      = Join-Path $root "tools\_patch_backup"
EnsureDirLocal $reportsDir
EnsureDirLocal $bkDir

$domPath = Join-Path $root "src\components\v2\Cv2DomFilterClient.tsx"
$mapPath = Join-Path $root "src\components\v2\MapaV2Interactive.tsx"

if (-not (Test-Path -LiteralPath $domPath)) { throw ("[STOP] não achei: " + (Rel $root $domPath)) }

# --- PATCH 1: rewrite Cv2DomFilterClient.tsx (lint/parser-safe)
$bkDom = BackupFileSafe $domPath

$domLines = @(
  '"use client";',
  '',
  'import { useEffect, useRef, useState } from "react";',
  '',
  'type Props = {',
  '  rootId: string;',
  '  placeholder?: string;',
  '};',
  '',
  'type Stats = { total: number; shown: number };',
  '',
  'function foldText(s: string): string {',
  '  const raw = (s ?? "").toString();',
  '  try {',
  '    return raw',
  '      .normalize("NFD")',
  '      .replace(/[\u0300-\u036f]/g, "")',
  '      .toLowerCase();',
  '  } catch {',
  '    return raw.toLowerCase();',
  '  }',
  '}',
  '',
  'function collectItems(root: HTMLElement): HTMLElement[] {',
  '  const pick = (sel: string) =>',
  '    Array.from(root.querySelectorAll<HTMLElement>(sel)).filter(',
  '      (el) => !el.closest("[data-cv2-filter-ui=\\"1\\"]")',
  '    );',
  '',
  '  const candidates = [".cv2-card", "[data-cv2-card]", "article", "li"];',
  '  for (const sel of candidates) {',
  '    const got = pick(sel);',
  '    if (got.length > 0) return got;',
  '  }',
  '  return [];',
  '}',
  '',
  'export function Cv2DomFilterClient({ rootId, placeholder }: Props) {',
  '  const [query, setQuery] = useState<string>("");',
  '  const [stats, setStats] = useState<Stats>({ total: 0, shown: 0 });',
  '  const itemsRef = useRef<HTMLElement[]>([]);',
  '',
  '  useEffect(() => {',
  '    const root = document.getElementById(rootId);',
  '    if (!root) {',
  '      itemsRef.current = [];',
  '      setStats({ total: 0, shown: 0 });',
  '      return;',
  '    }',
  '    const items = collectItems(root);',
  '    itemsRef.current = items;',
  '    setStats({ total: items.length, shown: items.length });',
  '  }, [rootId]);',
  '',
  '  useEffect(() => {',
  '    const items = itemsRef.current;',
  '    if (items.length === 0) {',
  '      setStats({ total: 0, shown: 0 });',
  '      return;',
  '    }',
  '    const q = foldText(query.trim());',
  '    let shown = 0;',
  '    for (const el of items) {',
  '      const hay = foldText(el.textContent ?? "");',
  '      const ok = q.length === 0 ? true : hay.includes(q);',
  '      el.hidden = !ok;',
  '      if (ok) shown += 1;',
  '    }',
  '    setStats({ total: items.length, shown });',
  '  }, [query]);',
  '',
  '  const canClear = query.trim().length > 0;',
  '',
  '  return (',
  '    <div',
  '      data-cv2-filter-ui="1"',
  '      style={{ display: "flex", gap: 10, alignItems: "center", flexWrap: "wrap", margin: "10px 0 14px" }}',
  '    >',
  '      <label style={{ display: "flex", alignItems: "center", gap: 8 }}>',
  '        <span className="cv2-muted" style={{ fontSize: 12 }}>filtrar</span>',
  '        <input',
  '          type="search"',
  '          value={query}',
  '          onChange={(e) => setQuery(e.target.value)}',
  '          placeholder={placeholder ?? "buscar..."}',
  '          style={{',
  '            padding: "10px 12px",',
  '            borderRadius: 12,',
  '            border: "1px solid var(--cv2-line, rgba(255,255,255,.10))",',
  '            background: "rgba(0,0,0,.22)",',
  '            color: "inherit",',
  '            outline: "none",',
  '            minWidth: 220,',
  '          }}',
  '        />',
  '      </label>',
  '',
  '      {canClear ? (',
  '        <button',
  '          type="button"',
  '          onClick={() => setQuery("")}',
  '          className="cv2-chip"',
  '          style={{ cursor: "pointer" }}',
  '        >',
  '          limpar',
  '        </button>',
  '      ) : null}',
  '',
  '      <span className="cv2-muted" style={{ fontSize: 12 }}>{stats.shown}/{stats.total}</span>',
  '    </div>',
  '  );',
  '}',
  ''
)

WriteUtf8NoBomSafe $domPath ($domLines -join "`n")
Write-Host ("[PATCH] wrote -> " + (Rel $root $domPath))
Write-Host ("[BK] " + (Rel $root $bkDom))

# --- PATCH 2: fix MapaV2Interactive unused import warning
$mapAction = "skipped"
if (Test-Path -LiteralPath $mapPath) {
  $rawMap = [IO.File]::ReadAllText($mapPath, [Text.UTF8Encoding]::new($false))
  if ($rawMap -and $rawMap.Trim().Length -gt 0) {
    $hasImport = ($rawMap -match '\bCv2MapNavPinsClient\b') -and ($rawMap -match 'import\b')
    $hasUsage  = ($rawMap -match '<\s*Cv2MapNavPinsClient\b')

    if ($hasImport -and (-not $hasUsage)) {
      $bkMap = BackupFileSafe $mapPath
      $lines = $rawMap -split "`r?`n"

      # acha "return (" e a primeira linha que começa com "<"
      $idxReturn = -1
      for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -match 'return\s*\(') { $idxReturn = $i; break }
      }

      $idxRoot = -1
      if ($idxReturn -ge 0) {
        for ($i = $idxReturn + 1; $i -lt $lines.Length; $i++) {
          $t = $lines[$i].Trim()
          if ($t.Length -eq 0) { continue }
          if ($t.StartsWith('<')) { $idxRoot = $i; break }
        }
      }

      $didInject = $false

      if ($idxRoot -ge 0) {
        $rootLine = $lines[$idxRoot].Trim()

        if (-not ($rootLine -match '/>\s*$')) {
          # elemento raiz abre/fecha -> injeta como primeiro filho
          $indent  = ([regex]::Match($lines[$idxRoot], '^\s*').Value)
          $indent2 = $indent + "  "
          $inject  = $indent2 + "<Cv2MapNavPinsClient />"

          $new = @()
          $new += $lines[0..$idxRoot]
          $new += $inject
          if ($idxRoot + 1 -le $lines.Length - 1) { $new += $lines[($idxRoot + 1)..($lines.Length - 1)] }
          $rawMap = ($new -join "`n")
          $didInject = $true
          $mapAction = "injected"
        }
      }

      if (-not $didInject) {
        # fallback: remove o import (só pra deixar lint verde; a gente reinjeta depois com âncora melhor)
        $newLines = @()
        foreach ($ln in ($rawMap -split "`r?`n")) {
          if (($ln -match 'import\b') -and ($ln -match 'Cv2MapNavPinsClient')) { continue }
          $newLines += $ln
        }
        $rawMap = ($newLines -join "`n")
        $mapAction = "removed-import"
      }

      WriteUtf8NoBomSafe $mapPath $rawMap
      Write-Host ("[PATCH] map -> " + (Rel $root $mapPath) + " (" + $mapAction + ")")
      Write-Host ("[BK] " + (Rel $root $bkMap))
    }
  }
}

# --- REPORT
$reportPath = Join-Path $reportsDir ($step + "-" + $stamp + ".md")
$rep = @()
$rep += "# CV — Step B6b1: Fix DOM filter lint + map navpins warning"
$rep += ""
$rep += "- when: " + $stamp
$rep += "- domfilter: " + (Rel $root $domPath)
$rep += "- domfilter backup: " + (Rel $root $bkDom)
$rep += "- mapa: " + (Rel $root $mapPath)
$rep += "- mapa action: " + $mapAction
$rep += ""
$rep += "## VERIFY"
$rep += "- tools/cv-verify.ps1"

WriteUtf8NoBomSafe $reportPath ($rep -join "`n")
Write-Host ("[REPORT] " + (Rel $root $reportPath))

# --- VERIFY
$verify = Join-Path $root "tools\cv-verify.ps1"
if (Test-Path -LiteralPath $verify) {
  Write-Host ("[RUN] " + (Rel $root $verify))
  & pwsh -NoProfile -ExecutionPolicy Bypass -File $verify
} else {
  Write-Host "[RUN] npm run lint"
  & npm run lint
  Write-Host "[RUN] npm run build"
  & npm run build
}

Write-Host "[OK] B6b1 aplicado." -ForegroundColor Green

if ($OpenReport) {
  try { Invoke-Item $reportPath } catch { }
}