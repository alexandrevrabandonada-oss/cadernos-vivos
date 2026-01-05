# CV — V2 Hotfix — MapaCanvasV2 sem window.location.hash (lint immutability) + V2Nav keys — v0_43
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
. (Join-Path $repo "tools\_bootstrap.ps1")

Write-Host ("[DIAG] Repo: " + $repo)

function PatchFile([string]$p, [scriptblock]$fn) {
  if (-not (Test-Path -LiteralPath $p)) { Write-Host ("[SKIP] missing: " + $p); return $false }
  $raw = Get-Content -LiteralPath $p -Raw
  if (-not $raw) { throw ("[STOP] arquivo vazio/ilegivel: " + $p) }
  $next = & $fn $raw
  if ($null -eq $next) { Write-Host ("[SKIP] no-op: " + $p); return $false }
  if ($next -eq $raw) { Write-Host ("[OK] no change: " + $p); return $false }
  $bk = BackupFile $p
  WriteUtf8NoBom $p $next
  Write-Host ("[OK] patched: " + $p)
  if ($bk) { Write-Host ("[BK] " + $bk) }
  return $true
}

# ------------------------------------------------------------
# 1) FIX: MapaCanvasV2 — nao mutar window.location.hash
# ------------------------------------------------------------
$canvasPath = Join-Path $repo "src\components\v2\MapaCanvasV2.tsx"
PatchFile $canvasPath {
  param($raw)

  if ($raw -notmatch 'window\.location\.hash\s*=\s*id') {
    return $null
  }

  $replacement = @"
      // atualiza o hash sem mutar window.location.hash (lint immutability)
      // mantem deep-link e dispara hashchange manualmente (replaceState nao dispara sozinho)
      try {
        if (typeof window !== "undefined") {
          window.history.replaceState(null, "", "#" + id);
          window.dispatchEvent(new Event("hashchange"));
        }
      } catch {
        // noop
      }
"@

  $next = [regex]::Replace(
    $raw,
    'try\s*\{\s*window\.location\.hash\s*=\s*id;\s*\}\s*catch\s*\{\s*[^}]*\s*\}',
    $replacement
  )

  # fallback caso a estrutura try/catch esteja diferente
  if ($next -eq $raw) {
    $next = $raw.Replace('window.location.hash = id;', 'window.history.replaceState(null, "", "#" + id); window.dispatchEvent(new Event("hashchange"));')
  }

  return $next
} | Out-Null

# ------------------------------------------------------------
# 2) POLISH: V2Nav — remove i nao usado + key robusto (href)
# ------------------------------------------------------------
$v2navPath = Join-Path $repo "src\components\v2\V2Nav.tsx"
if (Test-Path -LiteralPath $v2navPath) {
  $bk = BackupFile $v2navPath

  $lines = @(
    'import Link from "next/link";',
    '',
    'export default function V2Nav(props: { slug: string; active?: string }) {',
    '  const slug = props.slug;',
    '  const active = props.active ?? "";',
    '  const base = "/c/" + slug + "/v2";',
    '',
    '  const items = [',
    '    { key: "v2", label: "V2 Home", href: base },',
    '    { key: "mapa", label: "Mapa", href: base + "/mapa" },',
    '    { key: "linha", label: "Linha", href: base + "/linha" },',
    '    { key: "debate", label: "Debate", href: base + "/debate" },',
    '    { key: "provas", label: "Provas", href: base + "/provas" },',
    '    { key: "trilhas", label: "Trilhas", href: base + "/trilhas" },',
    '    { key: "v1", label: "V1", href: "/c/" + slug },',
    '  ];',
    '',
    '  return (',
    '    <nav style={{',
    '      display: "flex",',
    '      gap: 10,',
    '      flexWrap: "wrap",',
    '      alignItems: "center",',
    '      marginBottom: 12,',
    '      padding: "10px 12px",',
    '      borderRadius: 14,',
    '      border: "1px solid rgba(255,255,255,0.10)",',
    '      background: "rgba(0,0,0,0.20)",',
    '    }}>',
    '      {items.map((it) => {',
    '        const on = active === it.key;',
    '        return (',
    '          <Link',
    '            key={it.href}',
    '            href={it.href}',
    '            style={{',
    '              padding: "8px 10px",',
    '              borderRadius: 999,',
    '              border: "1px solid rgba(255,255,255,0.14)",',
    '              textDecoration: "none",',
    '              color: "white",',
    '              background: on ? "rgba(255,255,255,0.08)" : "rgba(0,0,0,0.18)",',
    '              fontWeight: on ? 800 : 650,',
    '            }}',
    '          >',
    '            {it.label}',
    '          </Link>',
    '        );',
    '      })}',
    '    </nav>',
    '  );',
    '}'
  )

  WriteLinesUtf8NoBom $v2navPath $lines
  Write-Host ("[OK] wrote: " + $v2navPath)
  if ($bk) { Write-Host ("[BK] " + $bk) }
} else {
  Write-Host ("[SKIP] missing: " + $v2navPath)
}

# ------------------------------------------------------------
# VERIFY
# ------------------------------------------------------------
RunPs1 (Join-Path $repo "tools\cv-verify.ps1")

# ------------------------------------------------------------
# REPORT
# ------------------------------------------------------------
$rep = @()
$rep += '# CV — V2 Hotfix v0_43 — Mapa hash sem mutacao + V2Nav keys'
$rep += ''
$rep += '## Fix'
$rep += '- MapaCanvasV2: remove window.location.hash = id; troca por history.replaceState + dispatch hashchange (lint react-hooks/immutability).'
$rep += '- V2Nav: remove i nao usado e padroniza keys (key=href) para eliminar warning no console.'
$rep += ''
$rep += '## Arquivos'
$rep += '- src/components/v2/MapaCanvasV2.tsx'
$rep += '- src/components/v2/V2Nav.tsx'
$rep += ''
$rep += '## Verify'
$rep += '- tools/cv-verify.ps1 (guard + lint + build)'
$rep += ''

WriteReport "cv-v2-hotfix-mapa-hash-nomutate-navkeys-v0_43.md" ($rep -join "`n") | Out-Null
Write-Host "[OK] v0_43 aplicado e verificado."