param()
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$v2Dir = Join-Path $repoRoot "src\app\c\[slug]\v2"
if (!(Test-Path -LiteralPath $v2Dir)) { throw ("v2Dir não existe: " + $v2Dir) }

function BackupFile([string]$filePath) {
  $bkDir = Join-Path $repoRoot "tools\_patch_backup"
  New-Item -ItemType Directory -Force -Path $bkDir | Out-Null
  $stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
  $leaf = (Split-Path -Leaf $filePath) -replace "[\\\/:\s]", "_"
  $bk = Join-Path $bkDir ($stamp + "-" + $leaf + ".bak")
  Copy-Item -LiteralPath $filePath -Destination $bk -Force
  return $bk
}

function WriteUtf8NoBom([string]$filePath, [string]$content) {
  [IO.File]::WriteAllText($filePath, $content, [Text.UTF8Encoding]::new($false))
}

$files = Get-ChildItem -LiteralPath $v2Dir -Recurse -File -Filter "page.tsx"
$patched = @()

foreach ($f in $files) {
  $raw = Get-Content -Raw -LiteralPath $f.FullName
  $p = $raw

  # injeta slug={slug} em <V2Nav ...> que não tem slug=
  $p2 = [regex]::Replace($p, "<V2Nav\b([^>]*?)\/?>", {
    param($m)
    $attrs = $m.Groups[1].Value
    if ($attrs -match "\bslug\s*=") { return $m.Value }
    $end = ($m.Value.TrimEnd().EndsWith("/>")) ? " />" : ">"
    $attrs2 = $attrs
    if ($attrs2.Length -gt 0 -and ($attrs2 -notmatch "^\s")) { $attrs2 = " " + $attrs2 }
    return "<V2Nav slug={slug}" + $attrs2 + $end
  })

  if ($p2 -ne $raw) {
    $bk = BackupFile $f.FullName
    WriteUtf8NoBom $f.FullName $p2
    $rel = $f.FullName.Substring($repoRoot.Length + 1)
    Write-Host ("[PATCH] " + $rel)
    Write-Host ("[BK]    tools\_patch_backup\" + (Split-Path -Leaf $bk))
    $patched += $rel
  }
}

if ($patched.Count -eq 0) { Write-Host "[SKIP] nada para ajustar em V2Nav." }

$npm = (Get-Command npm.cmd -ErrorAction Stop).Path
Write-Host "[RUN] npm run lint"
$lintOut = (& $npm run lint 2>&1 | Out-String)
$lintExit = $LASTEXITCODE
if ($lintExit -ne 0) { Write-Host $lintOut; throw ("[STOP] lint falhou (exit=" + $lintExit + ")") }

Write-Host "[RUN] npm run build"
$buildOut = (& $npm run build 2>&1 | Out-String)
$buildExit = $LASTEXITCODE
if ($buildExit -ne 0) { Write-Host $buildOut; throw ("[STOP] build falhou (exit=" + $buildExit + ")") }

Write-Host "[OK] B6R concluído (V2Nav com slug obrigatório em todas as páginas V2)."
