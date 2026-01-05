$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Write-Host ("[DIAG] Repo: " + $repo)

$bootstrap = Join-Path $PSScriptRoot "_bootstrap.ps1"
if (Test-Path -LiteralPath $bootstrap) { . $bootstrap; Write-Host ("[DIAG] Bootstrap: " + $bootstrap) }

if (-not (Get-Command EnsureDir -ErrorAction SilentlyContinue)) {
  function EnsureDir([string]$p) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}
if (-not (Get-Command WriteUtf8NoBom -ErrorAction SilentlyContinue)) {
  function WriteUtf8NoBom([string]$p, [string]$t) {
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($p, $t, $enc)
  }
}
if (-not (Get-Command BackupFile -ErrorAction SilentlyContinue)) {
  function BackupFile([string]$p) {
    if (-not (Test-Path -LiteralPath $p)) { return $null }
    $bkDir = Join-Path $repo "tools\_patch_backup"
    EnsureDir $bkDir
    $ts = Get-Date -Format "yyyyMMdd-HHmmss"
    $leaf = Split-Path -Leaf $p
    $bk = Join-Path $bkDir ($ts + "-" + $leaf + ".bak")
    Copy-Item -LiteralPath $p -Destination $bk -Force
    return $bk
  }
}
if (-not (Get-Command RunPs1 -ErrorAction SilentlyContinue)) {
  function RunPs1([string]$p) {
    & $PSHOME\pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $p
    if ($LASTEXITCODE -ne 0) { throw ("[STOP] RunPs1 falhou (exit " + $LASTEXITCODE + "): " + $p) }
  }
}
if (-not (Get-Command WriteReport -ErrorAction SilentlyContinue)) {
  function WriteReport([string]$name, [string]$content) {
    $dir = Join-Path $repo "reports"
    EnsureDir $dir
    $p = Join-Path $dir $name
    WriteUtf8NoBom $p $content
    return $p
  }
}

# -----------------------
# A) MapaCanvasV2 — remover window.location.hash=
# -----------------------
$canvasPath = Join-Path $repo "src\components\v2\MapaCanvasV2.tsx"
if (Test-Path -LiteralPath $canvasPath) {
  $raw = Get-Content -LiteralPath $canvasPath -Raw

  $rep = 'window.history.replaceState(null, "", "#" + id); window.dispatchEvent(new Event("hashchange"));'

  $fixed = $raw
  $fixed = [regex]::Replace($fixed, 'window\.location\.hash\s*=\s*id\s*;', $rep)
  $fixed = [regex]::Replace($fixed, 'window\.location\.hash\s*=\s*"#"\s*\+\s*id\s*;', $rep)
  $fixed = [regex]::Replace($fixed, 'window\.location\.hash\s*=\s*"#"\s*\+\s*\(id\)\s*;', $rep)

  if ($fixed -ne $raw) {
    $bk = BackupFile $canvasPath
    WriteUtf8NoBom $canvasPath $fixed
    Write-Host ("[OK] patched: " + $canvasPath + " (hash via replaceState)")
    if ($bk) { Write-Host ("[BK] " + $bk) }
  } else {
    Write-Host "[OK] MapaCanvasV2: nada pra mudar (window.location.hash= nao encontrado)."
  }
} else {
  Write-Host ("[SKIP] nao achei: " + $canvasPath)
}

# -----------------------
# B) MapaV2 — passar mapa={mapa} no Dock
# -----------------------
$mapaV2Path = Join-Path $repo "src\components\v2\MapaV2.tsx"
if (Test-Path -LiteralPath $mapaV2Path) {
  $raw = Get-Content -LiteralPath $mapaV2Path -Raw

  $fixed = $raw
  $fixed = [regex]::Replace($fixed, '<MapaDockV2\s+slug=\{slug\}\s*\/>', '<MapaDockV2 slug={slug} mapa={mapa} />')
  $fixed = [regex]::Replace($fixed, '<MapaDockV2\s+slug=\{slug\}\s*\/\s*>', '<MapaDockV2 slug={slug} mapa={mapa} />')

  if ($fixed -ne $raw) {
    $bk = BackupFile $mapaV2Path
    WriteUtf8NoBom $mapaV2Path $fixed
    Write-Host ("[OK] patched: " + $mapaV2Path + " (Dock recebe mapa)")
    if ($bk) { Write-Host ("[BK] " + $bk) }
  } else {
    Write-Host "[OK] MapaV2: ja parece passar mapa no Dock (ou padrao diferente)."
  }
} else {
  Write-Host ("[SKIP] nao achei: " + $mapaV2Path)
}

# -----------------------
# C) V2Nav — reescrever (keys ok + sem warning i)
# -----------------------
$v2NavPath = Join-Path $repo "src\components\v2\V2Nav.tsx"
EnsureDir (Split-Path -Parent $v2NavPath)

$bk = BackupFile $v2NavPath

$navLines = @(
'import Link from "next/link";',
'',
'type NavKey = "home" | "mapa" | "debate" | "provas" | "linha" | "linhaTempo" | "trilhas" | "v1";',
'',
'export default function V2Nav(props: { slug: string; active?: NavKey }) {',
'  const slug = props.slug;',
'  const active = props.active ?? "home";',
'',
'  const items: { key: NavKey; label: string; href: string }[] = [',
'    { key: "home", label: "V2", href: "/c/" + slug + "/v2" },',
'    { key: "mapa", label: "Mapa", href: "/c/" + slug + "/v2/mapa" },',
'    { key: "debate", label: "Debate", href: "/c/" + slug + "/v2/debate" },',
'    { key: "provas", label: "Provas", href: "/c/" + slug + "/v2/provas" },',
'    { key: "linha", label: "Linha", href: "/c/" + slug + "/v2/linha" },',
'    { key: "linhaTempo", label: "Linha do tempo", href: "/c/" + slug + "/v2/linha-do-tempo" },',
'    { key: "trilhas", label: "Trilhas", href: "/c/" + slug + "/v2/trilhas" },',
'    { key: "v1", label: "V1", href: "/c/" + slug },',
'  ];',
'',
'  return (',
'    <nav style={{ display: "flex", flexWrap: "wrap", gap: 10, alignItems: "center", marginTop: 6, marginBottom: 10 }}>',
'      {items.map((it) => {',
'        const on = active === it.key;',
'        return (',
'          <Link',
'            key={it.key}',
'            href={it.href}',
'            style={{',
'              padding: "8px 10px",',
'              borderRadius: 999,',
'              border: "1px solid rgba(255,255,255,0.14)",',
'              textDecoration: "none",',
'              color: "white",',
'              background: on ? "rgba(255,255,255,0.08)" : "rgba(0,0,0,0.20)",',
'              opacity: on ? 1 : 0.92,',
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

WriteUtf8NoBom $v2NavPath ($navLines -join "`n")
Write-Host ("[OK] wrote: " + $v2NavPath)
if ($bk) { Write-Host ("[BK] " + $bk) }

# -----------------------
# VERIFY
# -----------------------
$verify = Join-Path $repo "tools\cv-verify.ps1"
if (Test-Path -LiteralPath $verify) {
  Write-Host ("[RUN] " + $verify)
  RunPs1 $verify
} else {
  Write-Host ("[WARN] verify nao encontrado: " + $verify)
}

# -----------------------
# REPORT
# -----------------------
$rep = @()
$rep += "# CV — V2 Hotfix v0_40 — hash + Dock props + V2Nav keys"
$rep += ""
$rep += "## Mudancas"
$rep += "- MapaCanvasV2: troca window.location.hash por history.replaceState + evento hashchange."
$rep += "- MapaV2: MapaDockV2 recebe mapa={mapa}."
$rep += "- V2Nav: reescrito para garantir keys e remover warning."
$rep += ""
$rep += "## Arquivos"
$rep += "- src/components/v2/MapaCanvasV2.tsx"
$rep += "- src/components/v2/MapaV2.tsx"
$rep += "- src/components/v2/V2Nav.tsx"
$rep += ""
$rep += "## Verify"
$rep += "- tools/cv-verify.ps1 (guard + lint + build)"
$rep += ""

$rp = WriteReport "cv-v2-hotfix-mapa-hash-navkeys-v0_40.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] v0_40 aplicado."