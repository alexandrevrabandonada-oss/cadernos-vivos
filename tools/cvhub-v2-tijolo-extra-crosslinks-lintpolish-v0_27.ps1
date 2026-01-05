# CV — V2 Tijolo Extra — Crosslinks + Lint Polish — v0_27
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

$repo = Get-Location
$bootstrap = Join-Path $repo "tools\_bootstrap.ps1"
if (-not (Test-Path -LiteralPath $bootstrap)) { throw "[STOP] tools/_bootstrap.ps1 não encontrado. Rode o tijolo infra antes." }
. $bootstrap

function ReadLines([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) { throw ("[STOP] não achei arquivo: " + $p) }
  return Get-Content -LiteralPath $p
}
function WriteLines([string]$p, [string[]]$lines) {
  WriteLinesUtf8NoBom $p $lines
}
function ContainsText([string[]]$lines, [string]$needle) {
  return (($lines -join "`n").IndexOf($needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)
}

Write-Host ("[DIAG] Repo: " + $repo)

# ---------- PATCH 1) V1 -> link V2 (beta) ----------
$headerPath = Join-Path $repo "src\components\CadernoHeader.tsx"
if (Test-Path -LiteralPath $headerPath) {
  $lines = ReadLines $headerPath

  if (ContainsText $lines "/v2") {
    Write-Host "[SKIP] CadernoHeader já tem referência a /v2."
  } else {
    $out = New-Object System.Collections.Generic.List[string]
    $inserted = $false

    $iClose = -1
    for ($i=0; $i -lt $lines.Count; $i++) {
      if ($lines[$i] -match '^\s*\];\s*$') { $iClose = $i; break }
    }

    if ($iClose -lt 0) {
      Write-Host "[WARN] Não achei fechamento do array items (];). Não patchou CadernoHeader."
    } else {
      for ($i=0; $i -lt $lines.Count; $i++) {
        if ($i -eq $iClose -and -not $inserted) {
          $out.Add('    { href: "/c/" + slug + "/v2", label: "V2 (beta)" },')
          $inserted = $true
        }
        $out.Add($lines[$i])
      }

      $bk = BackupFile $headerPath
      WriteLines $headerPath $out.ToArray()
      Write-Host "[OK] patched: CadernoHeader.tsx (NavPills ganhou V2 beta)"
      if ($bk) { Write-Host ("[BK] " + $bk) }
    }
  }
} else {
  Write-Host "[WARN] Não achei src/components/CadernoHeader.tsx — pulando."
}

# ---------- PATCH 2) V2Nav -> link V1 ----------
$v2NavPath = Join-Path $repo "src\components\v2\V2Nav.tsx"
if (Test-Path -LiteralPath $v2NavPath) {
  $lines = ReadLines $v2NavPath

  if (ContainsText $lines '"/c/" + slug' -and ContainsText $lines 'V1') {
    Write-Host "[SKIP] V2Nav já tem link V1."
  } else {
    $out = New-Object System.Collections.Generic.List[string]
    $inserted = $false
    for ($i=0; $i -lt $lines.Count; $i++) {
      $ln = $lines[$i]
      $out.Add($ln)

      if (-not $inserted -and $ln -match 'const\s+items\s*=\s*\[') {
        # insere logo depois do "const items = ["
        $out.Add('    { href: "/c/" + slug, label: "V1" },')
        $inserted = $true
      }
    }

    if (-not $inserted) {
      Write-Host "[WARN] Não encontrei 'const items = [' no V2Nav — não inseri o link V1 (arquivo pode ter outra estrutura)."
    } else {
      $bk = BackupFile $v2NavPath
      WriteLines $v2NavPath $out.ToArray()
      Write-Host "[OK] patched: V2Nav.tsx (adicionou item V1)"
      if ($bk) { Write-Host ("[BK] " + $bk) }
    }
  }
} else {
  Write-Host "[WARN] Não achei src/components/v2/V2Nav.tsx — pulando."
}

# ---------- PATCH 3) TimelineV2: remover window.location.hash = hash; ----------
$timelinePath = Join-Path $repo "src\components\v2\TimelineV2.tsx"
if (Test-Path -LiteralPath $timelinePath) {
  $lines = ReadLines $timelinePath
  $out = New-Object System.Collections.Generic.List[string]
  $changed = $false

  foreach ($ln in $lines) {
    if ($ln -match 'window\.location\.hash\s*=\s*hash;') {
      $indent = ""
      if ($ln -match '^(\s*)') { $indent = $Matches[1] }

      $out.Add($indent + 'const el = document.getElementById(hash.slice(1));')
      $out.Add($indent + 'if (el) el.scrollIntoView({ behavior: "smooth", block: "start" });')
      $changed = $true
    } else {
      $out.Add($ln)
    }
  }

  if ($changed) {
    $bk = BackupFile $timelinePath
    WriteLines $timelinePath $out.ToArray()
    Write-Host "[OK] patched: TimelineV2.tsx (removeu window.location.hash, entrou scrollIntoView)"
    if ($bk) { Write-Host ("[BK] " + $bk) }
  } else {
    Write-Host "[SKIP] TimelineV2: não achei window.location.hash = hash; (talvez já corrigido)."
  }
} else {
  Write-Host "[WARN] Não achei src/components/v2/TimelineV2.tsx — pulando."
}

# ---------- PATCH 4) Trilhas page: trocar aspas " no TEXTO JSX por &quot; (evita react/no-unescaped-entities) ----------
$trilhasPage = Join-Path $repo "src\app\c\[slug]\v2\trilhas\page.tsx"
if (Test-Path -LiteralPath $trilhasPage) {
  $lines = ReadLines $trilhasPage
  $out = New-Object System.Collections.Generic.List[string]
  $changed = $false

  foreach ($ln in $lines) {
    # Só mexe em " depois do primeiro '>' (texto JSX), e só se o conteúdo não começar com '{'
    $idxLt = $ln.IndexOf("<")
    $idxGt = $ln.IndexOf(">")
    if ($idxLt -ge 0 -and $idxGt -gt $idxLt) {
      $before = $ln.Substring(0, $idxGt + 1)
      $after  = $ln.Substring($idxGt + 1)
      if ($after.TrimStart().StartsWith("{")) {
        $out.Add($ln)
        continue
      }
      if ($after.Contains('"')) {
        $after2 = $after.Replace('"', '&quot;')
        $out.Add($before + $after2)
        $changed = $true
        continue
      }
    }
    $out.Add($ln)
  }

  if ($changed) {
    $bk = BackupFile $trilhasPage
    WriteLines $trilhasPage $out.ToArray()
    Write-Host "[OK] patched: v2/trilhas/page.tsx (texto JSX com aspas -> &quot;)"
    if ($bk) { Write-Host ("[BK] " + $bk) }
  } else {
    Write-Host "[SKIP] v2/trilhas/page.tsx: nada para corrigir (sem aspas em texto JSX)."
  }
} else {
  Write-Host "[WARN] Não achei src/app/c/[slug]/v2/trilhas/page.tsx — pulando."
}

# ---------- PATCH 5) trilhas.ts: remover eslint-disable inútil (se existir) ----------
$trilhasLib = Join-Path $repo "src\lib\v2\trilhas.ts"
if (Test-Path -LiteralPath $trilhasLib) {
  $lines = ReadLines $trilhasLib
  $out = New-Object System.Collections.Generic.List[string]
  $removed = $false

  foreach ($ln in $lines) {
    if ($ln -match 'eslint-disable' -and $ln -match 'consistent-type-imports') {
      $removed = $true
      continue
    }
    $out.Add($ln)
  }

  if ($removed) {
    $bk = BackupFile $trilhasLib
    WriteLines $trilhasLib $out.ToArray()
    Write-Host "[OK] patched: src/lib/v2/trilhas.ts (removeu eslint-disable unused)"
    if ($bk) { Write-Host ("[BK] " + $bk) }
  } else {
    Write-Host "[SKIP] src/lib/v2/trilhas.ts: não achei eslint-disable para remover."
  }
} else {
  Write-Host "[WARN] Não achei src/lib/v2/trilhas.ts — pulando."
}

# ---------- VERIFY ----------
$verify = Join-Path $repo "tools\cv-verify.ps1"
if (Test-Path -LiteralPath $verify) {
  Write-Host ("[RUN] " + $verify)
  & $verify
} else {
  $npm = GetNpmCmd
  RunCmd $npm @("run","lint")
  RunCmd $npm @("run","build")
}

# ---------- REPORT ----------
$report = @(
  "# CV — V2 Tijolo Extra v0_27 — Crosslinks + Lint Polish",
  "",
  "## O que mudou",
  "- V1 NavPills (CadernoHeader): adiciona link para /v2 (beta).",
  "- V2Nav: adiciona link para V1 (quando possível pela estrutura do arquivo).",
  "- TimelineV2: remove `window.location.hash = hash;` (react-hooks/immutability) e usa scrollIntoView.",
  "- V2 Trilhas page: converte aspas `\"` em texto JSX para `&quot;` (react/no-unescaped-entities).",
  "- trilhas.ts: remove eslint-disable unused (consistent-type-imports), se existir.",
  "",
  "## Verify",
  "- tools/cv-verify.ps1 (guard + lint + build)",
  ""
) -join "`n"

WriteReport "cv-v2-tijolo-extra-crosslinks-lintpolish-v0_27.md" $report | Out-Null
Write-Host "[OK] v0_27 aplicado e verificado."