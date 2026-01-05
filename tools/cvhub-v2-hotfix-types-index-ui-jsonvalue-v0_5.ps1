param(
  [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo

# --- bootstrap ---
$bootstrap = Join-Path $repo "tools\_bootstrap.ps1"
if (Test-Path $bootstrap) {
  . $bootstrap
} else {
  function WL([string]$m){ Write-Host $m }
  function EnsureDir([string]$p){ New-Item -ItemType Directory -Force -Path $p | Out-Null }
  function WriteUtf8NoBom([string]$p,[string]$c){
    EnsureDir (Split-Path -Parent $p)
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($p,$c,$enc)
  }
  function BackupFile([string]$p){
    if (-not (Test-Path $p)) { return }
    $bdir = Join-Path $repo "tools\_patch_backup"
    EnsureDir $bdir
    $ts = Get-Date -Format "yyyyMMdd_HHmmss"
    $name = (Split-Path -Leaf $p) + "." + $ts + ".bak"
    Copy-Item -Force -LiteralPath $p -Destination (Join-Path $bdir $name)
  }
  function ResolveExe([string[]]$cands){
    foreach($c in $cands){
      $cmd = Get-Command $c -ErrorAction SilentlyContinue
      if ($cmd) { return $cmd.Source }
    }
    throw "[STOP] Não achei executável: " + ($cands -join ", ")
  }
  function RunNative([string]$cwd,[string]$exe,[string[]]$args){
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo.FileName = $exe
    $p.StartInfo.WorkingDirectory = $cwd
    $p.StartInfo.UseShellExecute = $false
    $p.StartInfo.RedirectStandardOutput = $true
    $p.StartInfo.RedirectStandardError = $true
    foreach($a in $args){ [void]$p.StartInfo.ArgumentList.Add($a) }
    [void]$p.Start()
    $o = $p.StandardOutput.ReadToEnd()
    $e = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    if ($o) { Write-Host $o }
    if ($e) { Write-Host $e }
    if ($p.ExitCode -ne 0) { throw "[STOP] comando falhou (exit $($p.ExitCode)): $exe $($args -join ' ')" }
  }
  function NewReport([string]$name,[string[]]$lines){
    $repDir = Join-Path $repo "reports"
    EnsureDir $repDir
    $p = Join-Path $repDir $name
    WriteUtf8NoBom $p ($lines -join "`n")
    return $p
  }
}

$npmExe = ResolveExe @("npm.cmd","npm.exe","npm")
WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)

$typesPath = Join-Path $repo "src\lib\v2\types.ts"
WL ("[DIAG] types: " + $typesPath)
if (-not (Test-Path $typesPath)) { throw "[STOP] types.ts não encontrado." }

BackupFile $typesPath
$raw = Get-Content -Raw -LiteralPath $typesPath
$before = $raw

# 1) JsonValue precisa aceitar objeto/array (JSON real)
$hasObj = ($raw -match "\{\s*\[k:\s*string\]\s*:\s*JsonValue") -or ($raw -match "Record<string,\s*JsonValue")
if ($raw -match "export\s+type\s+JsonValue" -and -not $hasObj) {
  $reJson = [regex] "(?s)export\s+type\s+JsonValue\s*=\s*.*?;"
  $raw2 = $reJson.Replace($raw, 'export type JsonValue = string | number | boolean | null | JsonValue[] | { [k: string]: JsonValue };', 1)
  if ($raw2 -ne $raw) { $raw = $raw2; WL "[OK] JsonValue atualizado (suporta objeto/array)." }
}

# 2) Index signature precisa aceitar undefined (pra props opcionais não quebrarem)
if ($raw -match "\[k:\s*string\]\s*:\s*JsonValue\s*;" -and ($raw -notmatch "\[k:\s*string\]\s*:\s*JsonValue\s*\|\s*undefined\s*;")) {
  $raw = [regex]::Replace($raw, "\[k:\s*string\]\s*:\s*JsonValue\s*;", "[k: string]: JsonValue | undefined;", 1)
  WL "[OK] Index signature: JsonValue -> JsonValue | undefined."
}

# 3) ui.default não pode ser opcional, senão vira undefined dentro do objeto
# cobre: ui?: { default?: UiDefault }  (com/sem ; dentro)
$raw = [regex]::Replace($raw,
  "ui\?\s*:\s*\{\s*default\?\s*:\s*UiDefault\s*;?\s*\}\s*;",
  "ui?: { default: UiDefault };",
  1
)

if ($raw -ne $before) {
  WriteUtf8NoBom $typesPath $raw
  WL "[OK] patched: types.ts (index + ui.default + JsonValue)."
} else {
  WL "[OK] types.ts já estava compatível — nenhuma mudança aplicada."
}

$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$repLines = @(
  ("# CV V2 Hotfix — types/index/ui/jsonvalue v0.5 — " + $now),
  "",
  "## Raiz do problema",
  "- MetaV2 tinha index signature [k: string]: JsonValue; e propriedades opcionais viram T | undefined.",
  "- ui.default opcional também vira UiDefault | undefined e isso não encaixa em JsonValue (JSON não tem undefined).",
  "",
  "## Fix",
  "- Index signature agora aceita JsonValue | undefined.",
  "- ui.default agora é obrigatório (default: UiDefault).",
  "- JsonValue garante suporte a objeto/array (JSON real).",
  "",
  "## Arquivo",
  "- src/lib/v2/types.ts"
)
$repPath = NewReport "cv-v2-hotfix-types-index-ui-jsonvalue-v0_5.md" $repLines
WL ("[OK] Report: " + $repPath)

WL "[VERIFY] npm run lint..."
RunNative $repo $npmExe @("run","lint")

if (-not $SkipBuild) {
  WL "[VERIFY] npm run build..."
  RunNative $repo $npmExe @("run","build")
} else {
  WL "[VERIFY] build pulado (-SkipBuild)."
}

WL ""
WL "[OK] Hotfix V2 types aplicado."