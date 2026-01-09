# cv-hotfix-b7c3-core-nodes-expr-and-lintignore-v0_1
$ErrorActionPreference = "Stop"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$repoRoot = (Resolve-Path ".").Path

function EnsureDir([string]$abs) { if (-not (Test-Path -LiteralPath $abs)) { [IO.Directory]::CreateDirectory($abs) | Out-Null } }
function ReadText([string]$abs) { if (-not (Test-Path -LiteralPath $abs)) { return $null }; return [IO.File]::ReadAllText($abs) }
function WriteText([string]$abs, [string]$text) { $enc = New-Object System.Text.UTF8Encoding($false); EnsureDir (Split-Path -Parent $abs); [IO.File]::WriteAllText($abs, $text, $enc) }
function BackupFile([string]$rel) {
  $abs = Join-Path $repoRoot $rel
  if (-not (Test-Path -LiteralPath $abs)) { return }
  $bkDir = Join-Path $repoRoot "tools\_patch_backup"
  EnsureDir $bkDir
  $dst = Join-Path $bkDir ($stamp + "-" + (Split-Path -Leaf $abs))
  Copy-Item -LiteralPath $abs -Destination $dst -Force
}
function TryRun([string]$label, [scriptblock]$sb) {
  try { $out = & $sb 2>&1 | Out-String; return @("## " + $label, "", $out.TrimEnd(), "") }
  catch { return @("## " + $label, "", ("[ERR] " + $_.Exception.Message), "") }
}
function AddLines([System.Collections.Generic.List[string]]$list, [object]$block) { if ($null -eq $block) { return }; foreach ($x in @($block)) { $list.Add([string]$x) | Out-Null } }

EnsureDir (Join-Path $repoRoot "reports")
EnsureDir (Join-Path $repoRoot "tools\_patch_backup")

$rep = Join-Path $repoRoot ("reports\" + $stamp + "-cv-hotfix-b7c3-core-nodes-expr-and-lintignore.md")
$r = New-Object System.Collections.Generic.List[string]
$r.Add("# Hotfix B7C3 — CoreNodes expr + lint ignore backups — " + $stamp) | Out-Null
$r.Add("") | Out-Null
$r.Add("Repo: " + $repoRoot) | Out-Null
$r.Add("") | Out-Null
AddLines $r (TryRun "Git status (pre)" { git status })

# -------------------------
# PATCH A) package.json: lint ignorando tools/_patch_backup/**
# -------------------------
$pkgRel = "package.json"
$pkgAbs = Join-Path $repoRoot $pkgRel
$pkg = ReadText $pkgAbs
if ($null -eq $pkg) { throw "Missing package.json" }
BackupFile $pkgRel

if ($pkg -match '"lint"\s*:\s*"eslint\b' -and $pkg -notmatch '--ignore-pattern\s+tools/_patch_backup/\*\*') {
  # troca só o script lint (primeira ocorrência)
  $pkg2 = [Regex]::Replace(
    $pkg,
    '"lint"\s*:\s*"eslint([^"]*)"',
    '"lint": "eslint --ignore-pattern tools/_patch_backup/**$1"',
    1
  )
  $pkg = $pkg2
  WriteText $pkgAbs $pkg
  $r.Add("## Patch A") | Out-Null
  $r.Add("- package.json: lint agora ignora tools/_patch_backup/**") | Out-Null
  $r.Add("") | Out-Null
} else {
  $r.Add("## Patch A") | Out-Null
  $r.Add("- package.json: sem mudança (já tinha ignore-pattern ou lint diferente)") | Out-Null
  $r.Add("") | Out-Null
}

# -------------------------
# PATCH B) .eslintignore (extra / redundância)
# -------------------------
$eiRel = ".eslintignore"
$eiAbs = Join-Path $repoRoot $eiRel
$ei = ReadText $eiAbs
if ($null -eq $ei) { $ei = "" } else { BackupFile $eiRel }

if ($ei -notmatch 'tools/_patch_backup') {
  $add = @(
    "",
    "# Cadernos Vivos — backups locais (não lintar)",
    "tools/_patch_backup/**",
    ""
  ) -join "`n"
  $ei = ($ei.TrimEnd() + $add + "`n")
  WriteText $eiAbs $ei
  $r.Add("## Patch B") | Out-Null
  $r.Add("- .eslintignore: adiciona tools/_patch_backup/**") | Out-Null
  $r.Add("") | Out-Null
} else {
  $r.Add("## Patch B") | Out-Null
  $r.Add("- .eslintignore: já continha tools/_patch_backup") | Out-Null
  $r.Add("") | Out-Null
}

# -------------------------
# PATCH C) Corrigir coreNodes={meta.coreNodes} -> expr válido
# -------------------------
function PickExpr([string]$raw) {
  # 1) se existe const caderno/data/meta
  $hasCaderno = ($raw -match '(?m)\b(const|let|var)\s+caderno\b')
  $hasData    = ($raw -match '(?m)\b(const|let|var)\s+data\b')
  $hasMetaVar = ($raw -match '(?m)\b(const|let|var)\s+meta\b') -or ($raw -match '(?m)\bconst\s*{\s*meta\b')

  if ($hasCaderno) { return "caderno.meta.coreNodes" }
  if ($hasData)    { return "data.meta.coreNodes" }
  if ($hasMetaVar) { return "meta.coreNodes" }

  # 2) tenta descobrir o nome da variável que recebe loadCadernoV2
  $m = [Regex]::Match($raw, '(?m)\b(const|let|var)\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*await\s+loadCadernoV2\s*\(')
  if ($m.Success) {
    $v = $m.Groups[2].Value
    return ($v + ".meta.coreNodes")
  }

  # fallback: não injeta nada (evita identifier inexistente)
  return "undefined"
}

function FixCoreNodesExpr([string]$rel) {
  $abs = Join-Path $repoRoot $rel
  $raw = ReadText $abs
  if ($null -eq $raw) { return }

  if ($raw -notmatch '<Cv2CoreNodes\b') { return }

  BackupFile $rel
  $expr = PickExpr $raw

  # troca somente os casos meta.coreNodes (que quebraram)
  $raw2 = $raw.Replace("coreNodes={meta.coreNodes}", ("coreNodes={" + $expr + "}"))
  # e também corrige caso tenha espaços
  $raw2 = [Regex]::Replace($raw2, 'coreNodes=\{\s*meta\.coreNodes\s*\}', ("coreNodes={" + $expr + "}"))

  WriteText $abs $raw2
}

$v2Pages = @(
  "src\app\c\[slug]\v2\page.tsx",
  "src\app\c\[slug]\v2\debate\page.tsx",
  "src\app\c\[slug]\v2\linha\page.tsx",
  "src\app\c\[slug]\v2\linha-do-tempo\page.tsx",
  "src\app\c\[slug]\v2\mapa\page.tsx",
  "src\app\c\[slug]\v2\provas\page.tsx",
  "src\app\c\[slug]\v2\trilhas\page.tsx",
  "src\app\c\[slug]\v2\trilhas\[id]\page.tsx"
)

foreach ($p in $v2Pages) { FixCoreNodesExpr $p }

$r.Add("## Patch C") | Out-Null
$r.Add("- Pages V2: meta.coreNodes substituído por expr válido (caderno/data/meta)") | Out-Null
$r.Add("") | Out-Null

# -------------------------
# VERIFY
# -------------------------
AddLines $r (TryRun "npm run lint" {
  $npm = (Get-Command npm.cmd -ErrorAction Stop).Path
  & $npm run lint
})
AddLines $r (TryRun "npm run build" {
  $npm = (Get-Command npm.cmd -ErrorAction Stop).Path
  & $npm run build
})
AddLines $r (TryRun "Git status (post)" { git status })

WriteText $rep (($r -join "`n") + "`n")
Write-Host ("[REPORT] " + $rep)
Write-Host "[OK] Hotfix B7C3 finalizado."