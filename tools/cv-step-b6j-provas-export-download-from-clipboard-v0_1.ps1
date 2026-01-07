param()

$ErrorActionPreference = "Stop"

function FindRepoRoot([string]$start) {
  $cur = Resolve-Path $start
  while ($true) {
    $pkg = Join-Path $cur "package.json"
    if (Test-Path $pkg) { return $cur }
    $parent = Split-Path $cur -Parent
    if ($parent -eq $cur) { throw "Não achei package.json acima de $start. Rode no repo root." }
    $cur = $parent
  }
}

$root = FindRepoRoot (Get-Location).Path

# bootstrap (se existir)
$bootstrap = Join-Path $root "tools\_bootstrap.ps1"
if (Test-Path $bootstrap) {
  . $bootstrap
}

# fallbacks (caso bootstrap não exponha)
if (-not (Get-Command EnsureDir -ErrorAction SilentlyContinue)) {
  function EnsureDir([string]$p) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}
if (-not (Get-Command WriteUtf8NoBom -ErrorAction SilentlyContinue)) {
  function WriteUtf8NoBom([string]$p, [string]$content) {
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($p, $content, $enc)
  }
}

function BackupFile([string]$p, [string]$stamp) {
  $bkDir = Join-Path $root "tools\_patch_backup"
  EnsureDir $bkDir
  $leaf = Split-Path $p -Leaf
  $bk = Join-Path $bkDir ($stamp + "-" + $leaf + ".bak")
  Copy-Item -Force $p $bk
  Write-Host ("[BK] " + $bk)
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Write-Host ("== CV B6j (download payload from clipboard) == " + $stamp)
Write-Host ("[DIAG] Root: " + $root)

$target = Join-Path $root "src\components\v2\Cv2ProvasGroupedClient.tsx"
if (-not (Test-Path $target)) { throw "Arquivo alvo não encontrado: $target" }

$raw = Get-Content -Raw -Encoding UTF8 $target

# DIAG quick markers
$hasExport = ($raw -match "Exportar bloco")
$hasDl = ($raw -match "Baixar payload")
Write-Host ("[DIAG] has 'Exportar bloco': " + $hasExport)
Write-Host ("[DIAG] has 'Baixar payload': " + $hasDl)

$changed = $false

# 1) Helper function (one-time)
if ($raw -notmatch "function\s+cv2DownloadText\s*\(") {
$helper = @"
function cv2DownloadText(text: string, filename: string) {
  const blob = new Blob([text], { type: "text/plain;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
"@

  # try to insert right after "use client" line
  $ux = $raw.IndexOf('"use client"')
  if ($ux -lt 0) { $ux = $raw.IndexOf("'use client'") }

  if ($ux -ge 0) {
    $eol = $raw.IndexOf("`n", $ux)
    if ($eol -lt 0) { $eol = $raw.Length - 1 }
    $insertPos = [Math]::Min($raw.Length, $eol + 1)
    $raw = $raw.Insert($insertPos, "`n" + $helper + "`n")
  } else {
    $raw = $helper + "`n`n" + $raw
  }

  $changed = $true
  Write-Host "[PATCH] inserted cv2DownloadText() helper"
} else {
  Write-Host "[SKIP] helper cv2DownloadText() já existe"
}

# 2) Insert button after the first </button> that contains 'Exportar bloco'
if ($raw -notmatch "Baixar payload") {
  $i = $raw.IndexOf("Exportar bloco")
  if ($i -lt 0) { throw "Não achei o texto 'Exportar bloco' no componente (mudou label?)." }

  $j = $raw.IndexOf("</button>", $i)
  if ($j -lt 0) { throw "Achei 'Exportar bloco', mas não achei '</button>' depois dele." }

  $j2 = $j + "</button>".Length

  $btn = @"
<button
  type="button"
  className="cv2-btn"
  onClick={async () => {
    try {
      const txt = await navigator.clipboard.readText();
      if (!txt || !txt.trim()) {
        alert("Clipboard vazio. Clique em 'Exportar bloco' primeiro.");
        return;
      }
      const d = new Date();
      const y = String(d.getFullYear());
      const m = String(d.getMonth() + 1).padStart(2, "0");
      const da = String(d.getDate()).padStart(2, "0");
      const hh = String(d.getHours()).padStart(2, "0");
      const mm = String(d.getMinutes()).padStart(2, "0");
      const stamp = y + m + da + "-" + hh + mm;
      cv2DownloadText(txt, "cv2-provas-export-" + stamp + ".md");
    } catch (err) {
      console.error(err);
      alert("Não consegui ler o clipboard. Dica: clique em 'Exportar bloco' e cole num arquivo manualmente.");
    }
  }}
>
  Baixar payload (.md)
</button>
"@

  $raw = $raw.Insert($j2, "`n" + $btn + "`n")
  $changed = $true
  Write-Host "[PATCH] inserted 'Baixar payload (.md)' button"
} else {
  Write-Host "[SKIP] botão 'Baixar payload' já existe"
}

if ($changed) {
  BackupFile $target $stamp
  WriteUtf8NoBom $target $raw
  Write-Host ("[OK] patched: " + $target)
} else {
  Write-Host "[OK] nada para patchar"
}

# REPORT
$repDir = Join-Path $root "reports"
EnsureDir $repDir
$rep = Join-Path $repDir ("cv-step-b6j-provas-export-download-from-clipboard-v0_1-" + $stamp + ".md")
$repTxt = @"
# CV — B6j: Baixar payload (.md) a partir do clipboard

- when: $stamp
- file: src\components\v2\Cv2ProvasGroupedClient.tsx

## O que muda
- Adiciona helper cv2DownloadText()
- Adiciona botão: "Baixar payload (.md)" (lê do clipboard e baixa arquivo)

## Como usar
1) Clique "Exportar bloco"
2) Clique "Baixar payload (.md)"

## VERIFY
- tools\cv-verify.ps1
"@
WriteUtf8NoBom $rep $repTxt
Write-Host ("[REPORT] " + $rep)

# VERIFY
$verify = Join-Path $root "tools\cv-verify.ps1"
if (Test-Path $verify) {
  Write-Host ("[RUN] " + $verify)
  & pwsh -NoProfile -ExecutionPolicy Bypass -File $verify
  if ($LASTEXITCODE -ne 0) { throw "[STOP] verify falhou (exit $LASTEXITCODE)" }
} else {
  Write-Host "[WARN] tools\cv-verify.ps1 não encontrado. Rodando npm run lint/build..."
  & npm run lint
  if ($LASTEXITCODE -ne 0) { throw "[STOP] lint falhou" }
  & npm run build
  if ($LASTEXITCODE -ne 0) { throw "[STOP] build falhou" }
}

Write-Host "[DONE] B6j OK"