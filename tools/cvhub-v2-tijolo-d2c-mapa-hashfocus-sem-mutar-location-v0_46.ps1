$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Write-Host ("[DIAG] Repo: " + $repo)

. (Join-Path $PSScriptRoot "_bootstrap.ps1")

$canvasPath = Join-Path $repo "src\components\v2\MapaCanvasV2.tsx"
$dockPath   = Join-Path $repo "src\components\v2\MapaDockV2.tsx"
$mapaV2Path = Join-Path $repo "src\components\v2\MapaV2.tsx"

function PatchFile($p, [ScriptBlock]$fn) {
  if (-not (Test-Path -LiteralPath $p)) {
    Write-Host ("[WARN] nao achei: " + $p)
    return $false
  }
  $raw = Get-Content -LiteralPath $p -Raw
  $out = & $fn $raw
  if ($null -eq $out) {
    Write-Host ("[OK] no change: " + $p)
    return $false
  }
  if ($out -eq $raw) {
    Write-Host ("[OK] no change: " + $p)
    return $false
  }
  $bk = BackupFile $p
  WriteUtf8NoBom $p $out
  Write-Host ("[OK] patched: " + $p)
  if ($bk) { Write-Host ("[BK] " + $bk) }
  return $true
}

# -----------------------
# 1) MapaCanvasV2: remover window.location.hash = ... (lint immutability)
#    -> dispara evento "cv:map:select" com { id }
# -----------------------
PatchFile $canvasPath {
  param($raw)

  if ($raw -notmatch 'window\.location\.hash\s*=\s*') { return $null }

  # substitui qualquer "window.location.hash = EXPR;" por dispatch de CustomEvent
  $patched = $raw -replace 'window\.location\.hash\s*=\s*([^;]+);', 'window.dispatchEvent(new CustomEvent("cv:map:select", { detail: { id: $1 } }));'

  return $patched
} | Out-Null

# -----------------------
# 2) MapaDockV2: ao receber evento do canvas, atualizar hash via history.replaceState
#    + ficar imune a "hashchange" (sem setState dentro de effect)
# -----------------------
PatchFile $dockPath {
  param($raw)

  $changed = $false
  $out = $raw

  # garante import de useSyncExternalStore
  if ($out -match 'from "react";') {
    if ($out -notmatch 'useSyncExternalStore') {
      $out = $out -replace 'import\s+\{([^}]+)\}\s+from\s+"react";', {
        $inside = $args[0].Groups[1].Value
        if ($inside -match '\buseSyncExternalStore\b') { return $args[0].Value }
        return ('import {' + ($inside.Trim() + ', useSyncExternalStore') + '} from "react";')
      }
      $changed = $true
    }
  }

  # injeta helpers (useHashId + setHashId) se nao existir
  if ($out -notmatch 'function\s+useHashId\(') {
    $lines = $out -split "`r?`n"
    $insAt = 0
    for ($i=0; $i -lt $lines.Count; $i++) {
      if ($lines[$i] -match '^\s*import\s') { $insAt = $i + 1 }
    }

    $helper = @()
    $helper += ''
    $helper += 'function readHashId(): string {'
    $helper += '  if (typeof window === "undefined") return "";'
    $helper += '  const h = window.location.hash || "";'
    $helper += '  return h.startsWith("#") ? h.slice(1) : h;'
    $helper += '}'
    $helper += ''
    $helper += 'function setHashId(id: string) {'
    $helper += '  try {'
    $helper += '    if (typeof window === "undefined") return;'
    $helper += '    const next = "#" + id;'
    $helper += '    if (window.location.hash === next) return;'
    $helper += '    window.history.replaceState(null, "", next);'
    $helper += '    window.dispatchEvent(new Event("hashchange"));'
    $helper += '  } catch {'
    $helper += '    // noop'
    $helper += '  }'
    $helper += '}'
    $helper += ''
    $helper += 'function useHashId(): string {'
    $helper += '  return useSyncExternalStore('
    $helper += '    (cb) => {'
    $helper += '      if (typeof window === "undefined") return () => {};'
    $helper += '      window.addEventListener("hashchange", cb);'
    $helper += '      window.addEventListener("popstate", cb);'
    $helper += '      return () => {'
    $helper += '        window.removeEventListener("hashchange", cb);'
    $helper += '        window.removeEventListener("popstate", cb);'
    $helper += '      };'
    $helper += '    },'
    $helper += '    () => readHashId(),'
    $helper += '    () => ""'
    $helper += '  );'
    $helper += '}'
    $helper += ''

    $newLines = @()
    $newLines += $lines[0..($insAt-1)]
    $newLines += $helper
    if ($insAt -lt $lines.Count) { $newLines += $lines[$insAt..($lines.Count-1)] }
    $out = ($newLines -join "`n")
    $changed = $true
  }

  # troca estado selectedId via useHashId (se existir padrão antigo)
  if ($out -match 'const\s+\[selectedId,\s*setSelectedId\]') {
    $out = $out -replace 'const\s+\[selectedId,\s*setSelectedId\]\s*=\s*useState<[^>]*>\([^\)]*\);', 'const selectedId = useHashId();'
    $changed = $true
  }

  # remove listener de hashchange antigo que setava state (se ainda houver)
  if ($out -match 'addEventListener\("hashchange",\s*onHash\)') {
    # melhor: deixa só o listener do custom event do canvas (se existir)
    # remove bloco do onHash bem simples (best-effort)
    $out = [regex]::Replace($out, 'useEffect\(\(\)\s*=>\s*\{\s*const\s+onHash\s*=\s*\(\)\s*=>[^\}]*window\.addEventListener\("hashchange",[^\)]*\);\s*return\s*\(\)\s*=>\s*window\.removeEventListener\("hashchange",[^\)]*\);\s*\},\s*\[\s*\]\s*\);', '')
    $changed = $true
  }

  # se tiver handler do evento do canvas usando setSelectedId, troca por setHashId
  if ($out -match 'cv:map:select' -and $out -match 'setSelectedId') {
    $out = $out -replace 'setSelectedId\(([^)]+)\);', 'setHashId($1);'
    $changed = $true
  }

  # se NAO tiver listener do canvas, injeta um (best-effort) pro evento cv:map:select
  if ($out -notmatch 'cv:map:select') {
    # tenta inserir um useEffect básico após definição de selectedId
    $needle = 'const selectedId = useHashId();'
    if ($out -match [regex]::Escape($needle)) {
      $inject = @()
      $inject += $needle
      $inject += ''
      $inject += '  useEffect(() => {'
      $inject += '    const onSelect = (ev: Event) => {'
      $inject += '      const ce = ev as CustomEvent<{ id?: string }>;'
      $inject += '      const id = ce.detail?.id;'
      $inject += '      if (id) setHashId(id);'
      $inject += '    };'
      $inject += '    window.addEventListener("cv:map:select", onSelect as EventListener);'
      $inject += '    return () => window.removeEventListener("cv:map:select", onSelect as EventListener);'
      $inject += '  }, []);'
      $out = $out -replace [regex]::Escape($needle), ($inject -join "`n")
      $changed = $true
    }
  }

  if (-not $changed) { return $null }
  return $out
} | Out-Null

# -----------------------
# 3) MapaV2: garantir que Dock recebe prop mapa (caso esteja faltando)
# -----------------------
PatchFile $mapaV2Path {
  param($raw)

  if ($raw -match '<MapaDockV2\s+slug=\{slug\}\s*/>') {
    return ($raw -replace '<MapaDockV2\s+slug=\{slug\}\s*/>', '<MapaDockV2 slug={slug} mapa={mapa} />')
  }

  # caso já exista mapa=, nada
  return $null
} | Out-Null

# -----------------------
# 4) VERIFY
# -----------------------
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# -----------------------
# 5) REPORT (sem backticks, pra nao quebrar PowerShell)
# -----------------------
$rep = @()
$rep += "# CV — V2 Tijolo D2c v0_46 — MapaV2 hash focus sem mutar window.location.hash"
$rep += ""
$rep += "## O que mudou"
$rep += "- MapaCanvasV2: removeu atribuicao direta em window.location.hash (lint immutability)."
$rep += "- Agora o canvas dispara evento cv:map:select com o id."
$rep += "- MapaDockV2: converte evento em update de hash via history.replaceState + dispara hashchange."
$rep += "- MapaV2: garante que Dock recebe a prop mapa."
$rep += ""
$rep += "## Arquivos"
$rep += "- src/components/v2/MapaCanvasV2.tsx"
$rep += "- src/components/v2/MapaDockV2.tsx"
$rep += "- src/components/v2/MapaV2.tsx"
$rep += ""
$rep += "## Verify"
$rep += "- tools/cv-verify.ps1 (guard + lint + build)"
$rep += ""

$rp = WriteReport "cv-v2-tijolo-d2c-mapa-hashfocus-sem-mutar-location-v0_46.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] D2c v0_46 aplicado."