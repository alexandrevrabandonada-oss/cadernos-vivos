param([switch]$OpenReport)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function EnsureDir([string]$p){
  if(-not (Test-Path -LiteralPath $p)){
    New-Item -ItemType Directory -Force -Path $p | Out-Null
  }
}
function WriteUtf8NoBom([string]$path,[string]$content){
  $enc = New-Object System.Text.UTF8Encoding($false)
  [IO.File]::WriteAllText($path, $content, $enc)
}
function AppendUtf8NoBom([string]$path,[string]$content){
  $enc = New-Object System.Text.UTF8Encoding($false)
  [IO.File]::AppendAllText($path, $content, $enc)
}
function NowStamp(){ (Get-Date).ToString("yyyyMMdd-HHmmss") }
function BackupFile([string]$src,[string]$dstDir){
  EnsureDir $dstDir
  if(Test-Path -LiteralPath $src){
    $name = Split-Path -Leaf $src
    Copy-Item -Force -LiteralPath $src -Destination (Join-Path $dstDir $name)
  }
}

$repoRoot   = (Resolve-Path ".").Path
$reportsDir = Join-Path $repoRoot "reports"
$backupRoot = Join-Path $repoRoot "tools\_patch_backup"
EnsureDir $reportsDir
EnsureDir $backupRoot

$stamp = NowStamp
$backupDir = Join-Path $backupRoot ("b8p2-replug-v2-pages-" + $stamp)
EnsureDir $backupDir

$reportPath = Join-Path $reportsDir ("{0}-cv-b8p2-replug-v2-pages-shellv2.md" -f $stamp)
WriteUtf8NoBom $reportPath ("# CV B8P2 v0.2 — Replug V2 Pages => ShellV2`n`n- Data: **$stamp**`n- Repo: $repoRoot`n`n")

function H2([string]$t){ AppendUtf8NoBom $reportPath ("## " + $t + "`n`n") }
function LI([string]$t){ AppendUtf8NoBom $reportPath ("- " + $t + "`n") }

function ReplaceReturnMainWithShellV2 {
  param(
    [string]$filePath,
    [string]$active,
    [string]$title,
    [string]$subtitle
  )

  if(-not (Test-Path -LiteralPath $filePath)){
    return @{ changed = $false; reason = "missing" }
  }

  $raw = Get-Content -Raw -Encoding UTF8 -LiteralPath $filePath
  $lines = $raw -split "`r?`n"

  # Ensure import ShellV2 exists
  if(-not ($raw.Contains('from "@/components/v2/ShellV2"'))){
    $insertAt = -1
    for($i=0; $i -lt $lines.Count; $i++){
      if($lines[$i].StartsWith("import ")){ $insertAt = $i }
      else { if($insertAt -ge 0){ break } }
    }
    if($insertAt -ge 0){
      $newLines = New-Object System.Collections.Generic.List[string]
      for($i=0; $i -lt $lines.Count; $i++){
        $newLines.Add($lines[$i])
        if($i -eq $insertAt){
          $newLines.Add('import ShellV2 from "@/components/v2/ShellV2";')
        }
      }
      $lines = $newLines.ToArray()
      $raw = ($lines -join "`n")
    }
  }

  # Find return( ... ) then <main ...> ... </main>
  $idxReturn = -1
  for($i=0; $i -lt $lines.Count; $i++){
    if($lines[$i] -match "^\s*return\s*\(\s*$"){ $idxReturn = $i; break }
  }
  if($idxReturn -lt 0){
    return @{ changed = $false; reason = "no-return-paren" }
  }

  $idxMainOpen = -1
  for($i=$idxReturn; $i -lt [Math]::Min($lines.Count, $idxReturn+240); $i++){
    if($lines[$i] -match "^\s*<main\b"){ $idxMainOpen = $i; break }
  }

  # Already ShellV2? just remove duplicates and enforce active (best-effort)
  if($idxMainOpen -lt 0){
    if($raw.Contains("<ShellV2")){
      $patched = New-Object System.Collections.Generic.List[string]
      foreach($l in $lines){
        $isDup = ($l -match "<Cv2V2Nav\b") -or ($l -match "<Cv2DoorGuide\b") -or ($l -match "<Cv2PortalsCurated\b")
        if(-not $isDup){ $patched.Add($l) }
      }
      $raw2 = ($patched.ToArray() -join "`n")
      $raw2 = [regex]::Replace($raw2, 'active\s*=\s*"(hub|mapa|linha|linha-do-tempo|provas|trilhas|debate)"', ('active="' + $active + '"'))
      if($raw2 -ne ($lines -join "`n")){
        WriteUtf8NoBom $filePath $raw2
        return @{ changed = $true; reason = "already-shellv2-updated" }
      }
      return @{ changed = $false; reason = "already-shellv2-nochange" }
    }
    return @{ changed = $false; reason = "no-main" }
  }

  $idxMainClose = -1
  for($i=$idxMainOpen; $i -lt [Math]::Min($lines.Count, $idxMainOpen+520); $i++){
    if($lines[$i] -match "^\s*</main>\s*$"){ $idxMainClose = $i; break }
  }
  if($idxMainClose -lt 0){
    return @{ changed = $false; reason = "no-main-close" }
  }

  $inner = @()
  for($i=$idxMainOpen+1; $i -lt $idxMainClose; $i++){ $inner += $lines[$i] }

  # Strip duplicates inside return
  $inner2 = @()
  foreach($l in $inner){
    $isDup = ($l -match "<Cv2V2Nav\b") -or ($l -match "<Cv2DoorGuide\b") -or ($l -match "<Cv2PortalsCurated\b")
    if(-not $isDup){ $inner2 += $l }
  }

  # Build new return block
  $indent = "  "
  $block = New-Object System.Collections.Generic.List[string]
  $block.Add($lines[$idxReturn])
  $block.Add(($indent + '<ShellV2 slug={slug} active="' + $active + '" title="' + $title + '" subtitle="' + $subtitle + '">'))
  foreach($l in $inner2){ $block.Add($l) }
  $block.Add(($indent + "</ShellV2>"))
  $block.Add(");")

  # Find end of return block ");"
  $idxEnd = -1
  for($i=$idxMainClose; $i -lt [Math]::Min($lines.Count, $idxMainClose+80); $i++){
    if($lines[$i] -match "^\s*\)\s*;\s*$"){ $idxEnd = $i; break }
  }
  if($idxEnd -lt 0){ $idxEnd = $idxMainClose + 1 }

  $out = New-Object System.Collections.Generic.List[string]
  for($i=0; $i -lt $lines.Count; $i++){
    if($i -eq $idxReturn){
      foreach($b in $block){ $out.Add($b) }
      $i = $idxEnd
      continue
    }
    $out.Add($lines[$i])
  }

  # Remove unused import lines (safe)
  $out2 = New-Object System.Collections.Generic.List[string]
  foreach($l in $out){
    $trim = $l.Trim()
    $isImportDup = ($trim -match '^import\s+Cv2V2Nav\s+') -or ($trim -match '^import\s+Cv2DoorGuide\s+') -or ($trim -match '^import\s+Cv2PortalsCurated\s+')
    if(-not $isImportDup){ $out2.Add($l) }
  }

  $final = ($out2.ToArray() -join "`n")
  if($final -ne ($lines -join "`n")){
    WriteUtf8NoBom $filePath $final
    return @{ changed = $true; reason = "wrapped-main" }
  }

  return @{ changed = $false; reason = "nochange" }
}

H2 "PATCH"

$targets = @(
  @{ rel = "src\app\c\[slug]\v2\page.tsx"; active = "hub"; title = "Hub"; subtitle = "Núcleo do universo. Escolha uma porta." },
  @{ rel = "src\app\c\[slug]\v2\mapa\page.tsx"; active = "mapa"; title = "Mapa"; subtitle = "Mapa é o eixo. O resto são portas." },
  @{ rel = "src\app\c\[slug]\v2\linha\page.tsx"; active = "linha"; title = "Linha"; subtitle = "O fio narrativo: contexto e conexões." },
  @{ rel = "src\app\c\[slug]\v2\linha-do-tempo\page.tsx"; active = "linha-do-tempo"; title = "Linha do tempo"; subtitle = "Cronologia: fatos em ordem para entender o todo." },
  @{ rel = "src\app\c\[slug]\v2\provas\page.tsx"; active = "provas"; title = "Provas"; subtitle = "Fontes, documentos e evidências." },
  @{ rel = "src\app\c\[slug]\v2\trilhas\page.tsx"; active = "trilhas"; title = "Trilhas"; subtitle = "Caminhos guiados: estudar, agir, compartilhar." },
  @{ rel = "src\app\c\[slug]\v2\trilhas\[id]\page.tsx"; active = "trilhas"; title = "Trilhas"; subtitle = "Detalhe da trilha: passos e materiais." },
  @{ rel = "src\app\c\[slug]\v2\debate\page.tsx"; active = "debate"; title = "Debate"; subtitle = "Perguntas, respostas e construção coletiva." }
)

foreach($t in $targets){
  $full = Join-Path $repoRoot $t.rel
  BackupFile $full $backupDir
  $res = ReplaceReturnMainWithShellV2 -filePath $full -active $t.active -title $t.title -subtitle $t.subtitle
  LI ($t.rel + " => " + ($res.reason) + ( $(if($res.changed){" [CHANGED]"} else {" [SKIP]"}) ))
}
AppendUtf8NoBom $reportPath "`n"

H2 "VERIFY (runner canônico — quoting seguro)"

$runner = Join-Path $repoRoot "tools\cv-runner.ps1"
if(-not (Test-Path -LiteralPath $runner)){
  throw "tools\cv-runner.ps1 não encontrado"
}

$pwsh = (Get-Command pwsh -ErrorAction Stop).Source
AppendUtf8NoBom $reportPath "[RUN] tools/cv-runner.ps1`n~~~`n"
$out = & $pwsh -NoProfile -ExecutionPolicy Bypass -File $runner 2>&1
$code2 = $LASTEXITCODE
if($null -ne $out){
  foreach($l in $out){ AppendUtf8NoBom $reportPath (([string]$l) + "`n") }
}
AppendUtf8NoBom $reportPath ("~~~`nexit: " + $code2 + "`n`n")

if($code2 -ne 0){
  throw ("Runner failed with exit " + $code2)
}

H2 "DONE"
LI ("backups: " + $backupDir)
LI ("report: " + $reportPath)

Write-Host ("[REPORT] " + $reportPath)
if($OpenReport){
  try { Start-Process $reportPath | Out-Null } catch {}
}