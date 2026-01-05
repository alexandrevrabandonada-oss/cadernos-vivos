param(
  [string]$ZipPath = "",
  [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function WL([string]$s) { Write-Host $s }
function EnsureDir([string]$p) { if (-not (Test-Path $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function WriteUtf8NoBom([string]$p, [string]$content) {
  EnsureDir (Split-Path -Parent $p)
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($p, $content, $enc)
}
function BackupFile([string]$p) {
  if (Test-Path $p) {
    $ts = (Get-Date -Format "yyyyMMdd_HHmmss")
    $bakDir = Join-Path (Get-Location) "tools\_patch_backup"
    EnsureDir $bakDir
    Copy-Item -Force $p (Join-Path $bakDir ((Split-Path -Leaf $p) + "." + $ts + ".bak"))
  }
}
function ResolveExe([string]$name) {
  $cmd = Get-Command $name -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source) { return $cmd.Source }
  return $name
}
function RunNative([string]$cwd, [string]$exe, [string[]]$cmdArgs) {
  $pretty = ($cmdArgs -join " ")
  WL ("[RUN] " + $exe + " " + $pretty)
  Push-Location $cwd
  & $exe @cmdArgs
  $code = $LASTEXITCODE
  Pop-Location
  if ($code -ne 0) { throw ("[STOP] comando falhou (exit " + $code + "): " + $exe + " " + $pretty) }
}

function ResolveRepoHere() {
  $here = (Get-Location).Path
  if ((Test-Path (Join-Path $here "package.json")) -and (Test-Path (Join-Path $here "src\app"))) { return $here }
  $child = Join-Path $here "cadernos-vivos"
  if ((Test-Path (Join-Path $child "package.json")) -and (Test-Path (Join-Path $child "src\app"))) { return $child }
  throw ("[STOP] Rode este script na raiz do repo (onde tem package.json e src\app). Atual: " + $here)
}

function PatchNext16Params([string]$file, [string[]]$keys) {
  if (-not (Test-Path $file)) { WL ("[WARN] não achei: " + $file); return }

  $raw = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8)

  # 1) trocar quaisquer 'any' explícitos (lint) por tipos seguros
  $raw2 = $raw.Replace(": any", ": unknown")

  # 2) garantir params como Promise<...> e inserir await
  $needsInsert = ($raw2 -match "export default async function") -and ($raw2 -match "\bparams\b") -and (-not ($raw2 -match "await\s+params"))

  # tenta padronizar assinatura pra Next 16
  # troca "{ params }: { params: { ... } }" ou "{ params }: { params: unknown }" etc por Promise<Record<string,string>>
  $raw2 = [regex]::Replace(
    $raw2,
    "\{\s*params\s*\}\s*:\s*\{\s*params\s*:\s*[^}]+\}",
    "{ params }: { params: Promise<Record<string, string>> }"
  )

  if ($needsInsert) {
    $m = [regex]::Match($raw2, "\)\s*\{")
    if ($m.Success) {
      $insertPos = $m.Index + $m.Length
      $awaitLine = "  const _params = await params;"

      $raw2 = $raw2.Substring(0, $insertPos) + "`n" + $awaitLine + "`n" + $raw2.Substring($insertPos)

      foreach ($k in $keys) {
        $raw2 = $raw2.Replace("params." + $k, "_params." + $k)
      }
    }
  }

  if ($raw2 -ne $raw) {
    BackupFile $file
    WriteUtf8NoBom $file $raw2
    WL ("[OK] patched: " + (Split-Path -Leaf $file))
  } else {
    WL ("[OK] ok: " + (Split-Path -Leaf $file))
  }
}

function TitleFromFile([string]$f) {
  $t = [IO.Path]::GetFileNameWithoutExtension($f)
  $t = $t -replace "_", " "
  $t = $t -replace "\s{2,}", " "
  return $t.Trim()
}

function TryFindZip([string]$repo, [string]$zipPathArg) {
  if ($zipPathArg -and (Test-Path $zipPathArg)) { return (Resolve-Path $zipPathArg).Path }
  $parent = Split-Path -Parent $repo
  $hits = @()
  try { $hits += Get-ChildItem -Path $repo -Filter "*.zip" -ErrorAction SilentlyContinue } catch {}
  try { $hits += Get-ChildItem -Path $parent -Filter "*.zip" -ErrorAction SilentlyContinue } catch {}
  $hits = $hits | Sort-Object LastWriteTime -Descending
  if ($hits.Count -gt 0) { return $hits[0].FullName }
  return ""
}

# -------------------------
# DIAG
# -------------------------
$repo = ResolveRepoHere
WL ("[DIAG] Repo: " + $repo)
$npmExe = ResolveExe "npm.cmd"
WL ("[DIAG] npm: " + $npmExe)

# -------------------------
# PATCH: Next 16 params + lint any (arquivos que já apareceram no erro)
# -------------------------
PatchNext16Params (Join-Path $repo "src\app\c\[slug]\page.tsx") @("slug")
PatchNext16Params (Join-Path $repo "src\app\c\[slug]\pratica\page.tsx") @("slug")
PatchNext16Params (Join-Path $repo "src\app\c\[slug]\quiz\page.tsx") @("slug")
PatchNext16Params (Join-Path $repo "src\app\c\[slug]\a\[aula]\page.tsx") @("slug","aula")
PatchNext16Params (Join-Path $repo "src\app\page.tsx") @()  # só remove any (se tiver)

# -------------------------
# ACERVO: importar ZIP opcional + gerar acervo.json
# -------------------------
$slug = "poluicao-vr"
$contentBase = Join-Path $repo ("content\cadernos\" + $slug)
EnsureDir $contentBase
$publicAcervo = Join-Path $repo ("public\cadernos\" + $slug + "\acervo")
EnsureDir $publicAcervo

$acervoJsonPath = Join-Path $contentBase "acervo.json"
BackupFile $acervoJsonPath

$imported = @()
$zip = TryFindZip $repo $ZipPath
if ($zip) {
  WL ("[STEP] Import: ZIP encontrado: " + $zip)
  $tmp = Join-Path $repo "tools\_tmp_import"
  if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
  EnsureDir $tmp
  Expand-Archive -LiteralPath $zip -DestinationPath $tmp -Force

  $files = Get-ChildItem -Path $tmp -Recurse -File | Where-Object { $_.Extension -match "\.(pdf|doc|docx)$" }
  foreach ($f in $files) {
    $dest = Join-Path $publicAcervo $f.Name
    Copy-Item -Force $f.FullName $dest
    $k = $f.Extension.TrimStart(".").ToLower()
    $imported += [PSCustomObject]@{
      file  = $f.Name
      title = (TitleFromFile $f.Name)
      kind  = $k
      tags  = @("pacote-inicial")
    }
  }
  WL ("[OK] Importou " + $imported.Count + " arquivos para public/cadernos/" + $slug + "/acervo")
} else {
  WL "[WARN] ZIP não encontrado automaticamente (ok)."
  WL "       Se quiser, rode: pwsh -File tools\cvhub-hotfix-next16-acervo-v0_2a.ps1 -ZipPath C:\caminho\pacote.zip"
}

if ($imported.Count -eq 0) {
  $imported = @(
    [PSCustomObject]@{ file=""; title="Sem import ainda (adicione um ZIP para listar PDFs/DOCs)"; kind="info"; tags=@("setup") }
  )
}

$acervoJson = ($imported | ConvertTo-Json -Depth 5)
WriteUtf8NoBom $acervoJsonPath $acervoJson
WL "[OK] acervo.json escrito."

# -------------------------
# REPORT (sem backtick, pra não quebrar parser)
# -------------------------
EnsureDir (Join-Path $repo "reports")
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repo "reports\cv-hotfix-next16-acervo-v0_2a.md"
$report = @(
  "# Hotfix Next16 + Acervo — " + $now,
  "",
  "O que fez:",
  "- Corrigiu params Promise do Next 16 (await params) nas rotas do caderno",
  "- Removeu 'any' onde estava quebrando lint",
  "- Import opcional de ZIP para public/cadernos/poluicao-vr/acervo",
  "- Gerou content/cadernos/poluicao-vr/acervo.json",
  "",
  "Como testar:",
  "- /c/poluicao-vr",
  "- /c/poluicao-vr/acervo"
) -join "`n"
WriteUtf8NoBom $reportPath $report
WL ("[OK] Report: " + $reportPath)

# -------------------------
# VERIFY
# -------------------------
WL "[VERIFY] npm run lint..."
RunNative $repo $npmExe @("run","lint")

if (-not $SkipBuild) {
  WL "[VERIFY] npm run build..."
  RunNative $repo $npmExe @("run","build")
} else {
  WL "[VERIFY] build pulado (-SkipBuild)."
}

WL ""
WL "[OK] Hotfix aplicado."
WL "[NEXT] Rode npm run dev e teste /c/poluicao-vr (e /acervo)."