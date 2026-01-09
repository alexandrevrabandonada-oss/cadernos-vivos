# cv-hotfix-b7c2-core-nodes-lint-build-v0_1
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

$rep = Join-Path $repoRoot ("reports\" + $stamp + "-cv-hotfix-b7c2-core-nodes-lint-build.md")
$r = New-Object System.Collections.Generic.List[string]
$r.Add("# Hotfix B7C2 — CoreNodes (imports + no-any) — " + $stamp) | Out-Null
$r.Add("") | Out-Null
$r.Add("Repo: " + $repoRoot) | Out-Null
$r.Add("") | Out-Null
AddLines $r (TryRun "Git status (pre)" { git status })

# -------------------------
# PATCH A) Reescrever Cv2CoreNodes.tsx sem any
# -------------------------
$coreRel = "src\components\v2\Cv2CoreNodes.tsx"
$coreAbs = Join-Path $repoRoot $coreRel
if (-not (Test-Path -LiteralPath $coreAbs)) { throw ("Missing file: " + $coreRel) }
BackupFile $coreRel

$coreNew = @(
  'import Link from "next/link";',
  'import type { CoreNodesV2 } from "@/lib/v2/types";',
  '',
  'type Props = { slug: string; title?: string; coreNodes?: CoreNodesV2 };',
  'type Resolved = { id: string; title: string; hint?: string; href: string };',
  '',
  'const DOOR_KEYS = new Set(["mapa","linha","linha-do-tempo","provas","trilhas","debate","hub"]);',
  '',
  'function isRecord(v: unknown): v is Record<string, unknown> {',
  '  return !!v && typeof v === "object";',
  '}',
  '',
  'function resolveHref(slug: string, id: string): string {',
  '  const s = encodeURIComponent(slug);',
  '  if (id === "hub") return "/c/" + s + "/v2";',
  '  if (DOOR_KEYS.has(id)) return "/c/" + s + "/v2/" + encodeURIComponent(id);',
  '  return "/c/" + s + "/v2/mapa?focus=" + encodeURIComponent(id);',
  '}',
  '',
  'function resolveCoreNodes(slug: string, coreNodes?: CoreNodesV2): Resolved[] {',
  '  if (!coreNodes || !coreNodes.length) return [];',
  '  const out: Resolved[] = [];',
  '  for (const v of coreNodes) {',
  '    if (typeof v === "string") {',
  '      const id = v.trim();',
  '      if (!id) continue;',
  '      out.push({ id, title: id, href: resolveHref(slug, id) });',
  '      continue;',
  '    }',
  '    if (isRecord(v)) {',
  '      const id = typeof v["id"] === "string" ? (v["id"] as string).trim() : "";',
  '      if (!id) continue;',
  '      const title = (typeof v["title"] === "string" && (v["title"] as string).trim()) ? (v["title"] as string).trim() : id;',
  '      const hint = (typeof v["hint"] === "string" && (v["hint"] as string).trim()) ? (v["hint"] as string).trim() : undefined;',
  '      out.push({ id, title, hint, href: resolveHref(slug, id) });',
  '    }',
  '  }',
  '  const seen = new Set<string>();',
  '  const dedup: Resolved[] = [];',
  '  for (const n of out) {',
  '    if (seen.has(n.id)) continue;',
  '    seen.add(n.id);',
  '    dedup.push(n);',
  '    if (dedup.length >= 9) break;',
  '  }',
  '  return dedup;',
  '}',
  '',
  'export default function Cv2CoreNodes(props: Props) {',
  '  const nodes = resolveCoreNodes(props.slug, props.coreNodes);',
  '  if (!nodes.length) return null;',
  '  return (',
  '    <section className="cv2-core" aria-label="Núcleo do caderno">',
  '      <div className="cv2-core__head">',
  '        <div className="cv2-core__kicker">Núcleo</div>',
  '        <div className="cv2-core__title">{props.title ? props.title : "5–9 nós centrais"}</div>',
  '        <div className="cv2-core__sub">Portas e nós-chave — comece pelo mapa e atravesse o universo.</div>',
  '      </div>',
  '      <div className="cv2-core__pills">',
  '        {nodes.map((n) => (',
  '          <Link key={n.id} className="cv2-pill" href={n.href} title={n.hint ? n.hint : n.id}>',
  '            {n.title}',
  '          </Link>',
  '        ))}',
  '      </div>',
  '    </section>',
  '  );',
  '}'
) -join "`n"

WriteText $coreAbs ($coreNew + "`n")
$r.Add("") | Out-Null
$r.Add("## Patch A") | Out-Null
$r.Add("- Cv2CoreNodes.tsx reescrito sem any") | Out-Null
$r.Add("") | Out-Null

# -------------------------
# PATCH B) normalize.ts: remover any no helper e na extração coreNodes
# -------------------------
$normRel = "src\lib\v2\normalize.ts"
$normAbs = Join-Path $repoRoot $normRel
$normRaw = ReadText $normAbs
if ($null -eq $normRaw) { throw ("Missing file: " + $normRel) }
BackupFile $normRel

# substitui o bloco inteiro do normalizeCoreNodesV2 por uma versão sem any + helper extractCoreNodesRaw
$pattern = '(?s)function normalizeCoreNodesV2\(raw: unknown\): CoreNodesV2 \| undefined\s*\{.*?\n\}\s*'
if ($normRaw -match $pattern) {
  $replacement = @(
    'function isRecord(v: unknown): v is Record<string, unknown> {',
    '  return !!v && typeof v === "object";',
    '}',
    '',
    'function extractCoreNodesRaw(o: unknown): unknown {',
    '  if (!isRecord(o)) return undefined;',
    '  const direct = o["coreNodes"];',
    '  if (Array.isArray(direct)) return direct;',
    '  const core = o["core"];',
    '  if (isRecord(core)) {',
    '    const nodes = core["nodes"];',
    '    if (Array.isArray(nodes)) return nodes;',
    '  }',
    '  return undefined;',
    '}',
    '',
    'function normalizeCoreNodesV2(raw: unknown): CoreNodesV2 | undefined {',
    '  if (!Array.isArray(raw)) return undefined;',
    '  const out: Array<string | CoreNodeV2> = [];',
    '  for (const v of raw) {',
    '    if (typeof v === "string" && v.trim()) { out.push(v.trim()); continue; }',
    '    if (isRecord(v)) {',
    '      const id = typeof v["id"] === "string" ? (v["id"] as string).trim() : "";',
    '      if (!id) continue;',
    '      const title = typeof v["title"] === "string" ? (v["title"] as string) : undefined;',
    '      const hint = typeof v["hint"] === "string" ? (v["hint"] as string) : undefined;',
    '      out.push({ id, title, hint });',
    '    }',
    '  }',
    '  return out.length ? out.slice(0, 9) : undefined;',
    '}',
    ''
  ) -join "`n"
  $normRaw = [Regex]::Replace($normRaw, $pattern, ($replacement + "`n"), 1)
}

# troca as ocorrências do (o as any)["coreNodes"] ...
$normRaw = $normRaw.Replace('normalizeCoreNodesV2((o as any)["coreNodes"] ?? (o as any)["core"]?.["nodes"])', 'normalizeCoreNodesV2(extractCoreNodesRaw(o))')
$normRaw = $normRaw.Replace('meta.coreNodes = normalizeCoreNodesV2((o as any)["coreNodes"] ?? (o as any)["core"]?.["nodes"]);', 'meta.coreNodes = normalizeCoreNodesV2(extractCoreNodesRaw(o));')

WriteText $normAbs $normRaw
$r.Add("## Patch B") | Out-Null
$r.Add("- normalize.ts: helper coreNodes sem any + extractCoreNodesRaw") | Out-Null
$r.Add("") | Out-Null

# -------------------------
# PATCH C) Pages V2: remover imports Cv2CoreNodes fora do topo + inserir import no bloco de imports + garantir uso antes do V2Portals
# -------------------------
function FixV2Page([string]$rel) {
  $abs = Join-Path $repoRoot $rel
  $raw = ReadText $abs
  if ($null -eq $raw) { return }

  BackupFile $rel

  # 1) remove TODAS as linhas de import Cv2CoreNodes espalhadas
  $raw = [Regex]::Replace($raw, '(?m)^\s*import\s+Cv2CoreNodes\s+from\s+"@\/components\/v2\/Cv2CoreNodes";\s*\r?\n', '')

  # 2) remove qualquer bloco Cv2CoreNodes antigo (pra não duplicar)
  $raw = [Regex]::Replace($raw, '(?m)^\s*<Cv2CoreNodes\b[^>]*\/>\s*\r?\n', '')

  # 3) se não tem V2Portals, não injeta nada (evita import inútil)
  if ($raw -notmatch '<V2Portals\b') {
    WriteText $abs $raw
    return
  }

  # 4) define expr de coreNodes
  $expr = 'caderno.meta.coreNodes'
  if ($raw -match '\bdata\.meta\b') { $expr = 'data.meta.coreNodes' }
  elseif ($raw -match '\bcaderno\.meta\b') { $expr = 'caderno.meta.coreNodes' }
  elseif ($raw -match '\bmeta\.') { $expr = 'meta.coreNodes' }

  # 5) injeta uso ANTES do V2Portals
  $inject = '<Cv2CoreNodes slug={slug} coreNodes={' + $expr + '} />'
  $raw = [Regex]::Replace($raw, '(\s*)(<V2Portals\b)', ('$1' + $inject + "`n" + '$1$2'), 1)

  # 6) injeta import no topo (após diretiva e bloco de imports)
  $lines = $raw -split "`r?`n"
  $directive = -1
  if ($lines.Length -gt 0 -and ($lines[0] -match '^(?:"use client"|"use server"|''use client''|''use server'');\s*$')) { $directive = 0 }

  $start = 0
  if ($directive -eq 0) { $start = 1 }

  $lastImport = -1
  for ($i = $start; $i -lt $lines.Length; $i++) {
    $t = $lines[$i].Trim()
    if ($t -match '^import\s') { $lastImport = $i; continue }
    if ($lastImport -ge 0) {
      if ($t -ne '') { break } # encerra bloco de imports
      continue
    } else {
      if ($t -ne '') { break } # ainda nem começou import block
    }
  }

  $importLine = 'import Cv2CoreNodes from "@/components/v2/Cv2CoreNodes";'
  $out = New-Object System.Collections.Generic.List[string]
  for ($i = 0; $i -lt $lines.Length; $i++) {
    $out.Add($lines[$i]) | Out-Null
    if ($lastImport -ge 0 -and $i -eq $lastImport) {
      $out.Add($importLine) | Out-Null
    }
    if ($lastImport -lt 0 -and $i -eq $start) {
      # sem imports detectados; coloca logo após diretiva (se houver) ou no começo
      if ($start -eq 1 -and $i -eq 1) { $out.Insert(1, $importLine) | Out-Null }
    }
  }

  # fallback se sem imports e sem diretiva
  if ($lastImport -lt 0 -and $start -eq 0) {
    $out = New-Object System.Collections.Generic.List[string]
    $out.Add($importLine) | Out-Null
    foreach ($ln in $lines) { $out.Add($ln) | Out-Null }
  }

  # remove duplicatas acidentais no topo (segurança)
  $text = ($out -join "`n")
  $text = [Regex]::Replace($text, '(?m)^(import\s+Cv2CoreNodes\s+from\s+"@\/components\/v2\/Cv2CoreNodes";\s*\r?\n){2,}', "import Cv2CoreNodes from `"@/components/v2/Cv2CoreNodes`";`n")

  WriteText $abs ($text + "`n")
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

foreach ($p in $v2Pages) { FixV2Page $p }

$r.Add("## Patch C") | Out-Null
$r.Add("- Pages V2: imports Cv2CoreNodes limpos + uso garantido antes do V2Portals") | Out-Null
$r.Add("") | Out-Null

# -------------------------
# VERIFY
# -------------------------
AddLines $r (TryRun "cv-verify.ps1" {
  $v = Join-Path $repoRoot "tools\cv-verify.ps1"
  if (Test-Path -LiteralPath $v) { pwsh -NoProfile -ExecutionPolicy Bypass -File $v } else { "sem tools/cv-verify.ps1" }
})
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
Write-Host "[OK] Hotfix B7C2 finalizado."