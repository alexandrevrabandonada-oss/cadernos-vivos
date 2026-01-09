# cv-step-b7c-core-nodes-single-source-v0_1
$ErrorActionPreference = "Stop"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$repoRoot = (Resolve-Path ".").Path

function EnsureDir([string]$abs) {
  if (-not (Test-Path -LiteralPath $abs)) { [IO.Directory]::CreateDirectory($abs) | Out-Null }
}

function ReadText([string]$abs) {
  if (-not (Test-Path -LiteralPath $abs)) { return $null }
  return [IO.File]::ReadAllText($abs)
}

function WriteText([string]$abs, [string]$text) {
  $enc = New-Object System.Text.UTF8Encoding($false)
  EnsureDir (Split-Path -Parent $abs)
  [IO.File]::WriteAllText($abs, $text, $enc)
}

function BackupFile([string]$rel) {
  $abs = Join-Path $repoRoot $rel
  if (-not (Test-Path -LiteralPath $abs)) { return }
  $bkDir = Join-Path $repoRoot "tools\_patch_backup"
  EnsureDir $bkDir
  $name = (Split-Path -Leaf $abs)
  $dst = Join-Path $bkDir ($stamp + "-" + $name)
  Copy-Item -LiteralPath $abs -Destination $dst -Force
}

function TryRun([string]$label, [scriptblock]$sb) {
  try {
    $out = & $sb 2>&1 | Out-String
    return @("## " + $label, "", $out.TrimEnd(), "")
  } catch {
    return @("## " + $label, "", ("[ERR] " + $_.Exception.Message), "")
  }
}

function AddLines([System.Collections.Generic.List[string]]$list, [object]$block) {
  if ($null -eq $block) { return }
  foreach ($x in @($block)) { $list.Add([string]$x) | Out-Null }
}

EnsureDir (Join-Path $repoRoot "reports")
EnsureDir (Join-Path $repoRoot "tools\_patch_backup")

# -------------------------
# DIAG snapshot (pre)
# -------------------------
$rep = Join-Path $repoRoot ("reports\" + $stamp + "-cv-step-b7c-core-nodes-single-source.md")
$r = New-Object System.Collections.Generic.List[string]
$r.Add("# Tijolo B7C — CoreNodes como fonte única — " + $stamp) | Out-Null
$r.Add("") | Out-Null
$r.Add("Repo: " + $repoRoot) | Out-Null
$r.Add("") | Out-Null
AddLines $r (TryRun "Git status (pre)" { git status })

# -------------------------
# PATCH 1) types.ts (MetaV2 + CoreNodes types)
# -------------------------
$typesRel = "src\lib\v2\types.ts"
$typesAbs = Join-Path $repoRoot $typesRel
$typesRaw = ReadText $typesAbs
if ($null -eq $typesRaw) { throw ("Missing file: " + $typesRel) }

BackupFile $typesRel

if ($typesRaw -notmatch 'export type CoreNodesV2') {
  $ins = @(
    "",
    'export type CoreNodeV2 = { id: string; title?: string; hint?: string };',
    'export type CoreNodesV2 = Array<string | CoreNodeV2>;',
    ""
  ) -join "`n"

  if ($typesRaw -match '(export type UiDefault\s*=\s*["'']v1["'']\s*\|\s*["'']v2["''];\s*)') {
    $typesRaw = [Regex]::Replace($typesRaw, '(export type UiDefault\s*=\s*["'']v1["'']\s*\|\s*["'']v2["''];\s*)', ('$1' + $ins), 1)
  } else {
    $typesRaw = $ins + $typesRaw
  }
}

if ($typesRaw -notmatch 'coreNodes\?:\s*CoreNodesV2') {
  # insere dentro do bloco MetaV2 (no topo dele)
  $typesRaw2 = [Regex]::Replace(
    $typesRaw,
    '(export type MetaV2\s*=\s*{\s*)',
    ('$1' + "`n  coreNodes?: CoreNodesV2;`n"),
    1
  )
  $typesRaw = $typesRaw2
}

WriteText $typesAbs $typesRaw
$r.Add("") | Out-Null
$r.Add("## Patch: types.ts") | Out-Null
$r.Add("- OK: MetaV2.coreNodes + CoreNodesV2/CoreNodeV2") | Out-Null
$r.Add("") | Out-Null

# -------------------------
# PATCH 2) normalize.ts (normalizeMetaV2 inclui coreNodes)
# -------------------------
$normRel = "src\lib\v2\normalize.ts"
$normAbs = Join-Path $repoRoot $normRel
$normRaw = ReadText $normAbs
if ($null -eq $normRaw) { throw ("Missing file: " + $normRel) }

BackupFile $normRel

# garante import types
if ($normRaw -match 'from\s*"\.\/types"') {
  if ($normRaw -notmatch '\bCoreNodesV2\b') {
    # tenta inserir na primeira linha de import type {...} from "./types"
    $normRaw2 = [Regex]::Replace(
      $normRaw,
      '(import type\s*{\s*)([^}]+)(\s*}\s*from\s*"\.\/types";)',
      { param($m)
        $head = $m.Groups[1].Value
        $mid  = $m.Groups[2].Value
        $tail = $m.Groups[3].Value
        $mid2 = $mid.Trim()
        if ($mid2 -notmatch '\bCoreNodeV2\b') { $mid2 = $mid2 + ", CoreNodeV2" }
        if ($mid2 -notmatch '\bCoreNodesV2\b') { $mid2 = $mid2 + ", CoreNodesV2" }
        return $head + $mid2 + $tail
      },
      1
    )
    $normRaw = $normRaw2
  }
}

# helper normalizeCoreNodesV2
if ($normRaw -notmatch 'function normalizeCoreNodesV2') {
  $helper = @(
    "",
    'function normalizeCoreNodesV2(raw: unknown): CoreNodesV2 | undefined {',
    '  if (!Array.isArray(raw)) return undefined;',
    '  const out: Array<string | CoreNodeV2> = [];',
    '  for (const v of raw) {',
    '    if (typeof v === "string" && v.trim()) { out.push(v.trim()); continue; }',
    '    if (v && typeof v === "object") {',
    '      const o = v as any;',
    '      if (typeof o.id === "string" && o.id.trim()) {',
    '        const id = o.id.trim();',
    '        const title = typeof o.title === "string" ? o.title : undefined;',
    '        const hint = typeof o.hint === "string" ? o.hint : undefined;',
    '        out.push({ id, title, hint });',
    '      }',
    '    }',
    '  }',
    '  return out.length ? out.slice(0, 9) : undefined;',
    '}',
    ""
  ) -join "`n"

  # injeta antes de export function normalizeMetaV2
  $normRaw2 = [Regex]::Replace($normRaw, '(export function normalizeMetaV2\s*\()', ($helper + "`n`n" + 'export function normalizeMetaV2('), 1)
  $normRaw = $normRaw2
}

# injeta coreNodes no meta (preferência: replace exato)
if ($normRaw -match 'const meta:\s*MetaV2\s*=\s*{\s*slug,\s*title,\s*mood,\s*ui:\s*{\s*default:\s*uiDefault\s*}\s*};') {
  $normRaw = [Regex]::Replace(
    $normRaw,
    'const meta:\s*MetaV2\s*=\s*{\s*slug,\s*title,\s*mood,\s*ui:\s*{\s*default:\s*uiDefault\s*}\s*};',
    @(
      'const coreNodes = normalizeCoreNodesV2((o as any)["coreNodes"] ?? (o as any)["core"]?.["nodes"]);',
      'const meta: MetaV2 = { slug, title, mood, ui: { default: uiDefault }, coreNodes };'
    ) -join "`n",
    1
  )
} else {
  # fallback: depois da declaração do meta, seta a propriedade
  if ($normRaw -notmatch 'meta\.coreNodes\s*=') {
    $normRaw = [Regex]::Replace(
      $normRaw,
      '(const meta:\s*MetaV2\s*=\s*{[\s\S]*?};)',
      ('$1' + "`n" + 'meta.coreNodes = normalizeCoreNodesV2((o as any)["coreNodes"] ?? (o as any)["core"]?.["nodes"]);'),
      1
    )
  }
}

WriteText $normAbs $normRaw
$r.Add("## Patch: normalize.ts") | Out-Null
$r.Add("- OK: normalizeMetaV2 inclui meta.coreNodes (max 9) + helper normalizeCoreNodesV2") | Out-Null
$r.Add("") | Out-Null

# -------------------------
# PATCH 3) Cv2CoreNodes.tsx (presentational, fonte: props.coreNodes)
# -------------------------
$coreRel = "src\components\v2\Cv2CoreNodes.tsx"
$coreAbs = Join-Path $repoRoot $coreRel
$coreOld = ReadText $coreAbs
if ($null -eq $coreOld) { throw ("Missing file: " + $coreRel) }

BackupFile $coreRel

$coreNew = @(
  'import Link from "next/link";',
  'import type { CoreNodesV2 } from "@/lib/v2/types";',
  '',
  'type Props = { slug: string; title?: string; coreNodes?: CoreNodesV2 };',
  '',
  'type Resolved = { id: string; title: string; hint?: string; href: string };',
  '',
  'const DOOR_KEYS = new Set(["mapa","linha","linha-do-tempo","provas","trilhas","debate","hub"]);',
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
  '    if (v && typeof v === "object") {',
  '      const o = v as any;',
  '      const id = typeof o.id === "string" ? o.id.trim() : "";',
  '      if (!id) continue;',
  '      const title = (typeof o.title === "string" && o.title.trim()) ? o.title.trim() : id;',
  '      const hint = (typeof o.hint === "string" && o.hint.trim()) ? o.hint.trim() : undefined;',
  '      out.push({ id, title, hint, href: resolveHref(slug, id) });',
  '    }',
  '  }',
  '  // dedupe por id e limita a 9',
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
  '',
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
$r.Add("## Patch: Cv2CoreNodes.tsx") | Out-Null
$r.Add("- OK: Cv2CoreNodes agora renderiza props.coreNodes (MetaV2) e vira bloco padrão do núcleo") | Out-Null
$r.Add("") | Out-Null

# -------------------------
# PATCH 4) Render Cv2CoreNodes antes do V2Portals em todas as portas V2
# -------------------------
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

foreach ($rel in $v2Pages) {
  $abs = Join-Path $repoRoot $rel
  $raw = ReadText $abs
  if ($null -eq $raw) { continue }

  BackupFile $rel

  if ($raw -notmatch 'import Cv2CoreNodes from "@/components/v2/Cv2CoreNodes";') {
    # insere após a última import ...; do topo (primeiro bloco de imports)
    $raw = [Regex]::Replace(
      $raw,
      '(\n)(\s*const\s+|\s*export\s+|\s*type\s+|\s*interface\s+|\s*function\s+|\s*async\s+function\s+)',
      ("`nimport Cv2CoreNodes from `"`@/components/v2/Cv2CoreNodes`"`;`n`n" + '$2'),
      1
    )
    # se o replace acima falhar (caso raro), tenta inserir logo após a linha do V2Portals import
    if ($raw -notmatch 'import Cv2CoreNodes from "@/components/v2/Cv2CoreNodes";') {
      $raw = [Regex]::Replace(
        $raw,
        '(import\s+V2Portals\s+from\s+"@\/components\/v2\/V2Portals";\s*)',
        ('$1' + "`nimport Cv2CoreNodes from `"`@/components/v2/Cv2CoreNodes`"`;`n"),
        1
      )
    }
  }

  # escolhe expressão de meta (data.meta vs caderno.meta)
  $coreExpr = "caderno.meta.coreNodes"
  if ($raw -match '\bdata\.meta\b') { $coreExpr = "data.meta.coreNodes" }
  elseif ($raw -match '\bcaderno\.meta\b') { $coreExpr = "caderno.meta.coreNodes" }
  elseif ($raw -match '\bmeta\.') { $coreExpr = "meta.coreNodes" }

  # injeta bloco antes do V2Portals
  if ($raw -match '<V2Portals\b' -and $raw -notmatch 'cv2-core') {
    $raw = [Regex]::Replace(
      $raw,
      '(\s*)(<V2Portals\b)',
      ('$1' + '<Cv2CoreNodes slug={slug} coreNodes={' + $coreExpr + '} />' + "`n" + '$1$2'),
      1
    )
  }

  # Hub V2 já renderiza Cv2CoreNodes com title; garante prop coreNodes no call existente
  if ($rel -eq "src\app\c\[slug]\v2\page.tsx") {
    if ($raw -match '<Cv2CoreNodes\s+slug=\{slug\}\s+title=\{title0\}\s*\/>') {
      $raw = [Regex]::Replace(
        $raw,
        '<Cv2CoreNodes\s+slug=\{slug\}\s+title=\{title0\}\s*\/>',
        '<Cv2CoreNodes slug={slug} title={title0} coreNodes={caderno.meta.coreNodes} />',
        1
      )
    }
  }

  WriteText $abs $raw
}

$r.Add("## Patch: V2 pages") | Out-Null
$r.Add("- OK: Cv2CoreNodes aparece antes do V2Portals em todas as portas; Hub recebe coreNodes explicitamente") | Out-Null
$r.Add("") | Out-Null

# -------------------------
# PATCH 5) CSS (estilo simples Concreto Zen)
# -------------------------
$cssRel = "src\app\globals.css"
$cssAbs = Join-Path $repoRoot $cssRel
$cssRaw = ReadText $cssAbs
if ($null -eq $cssRaw) { throw ("Missing file: " + $cssRel) }

BackupFile $cssRel

if ($cssRaw -notmatch '\.cv2-core\s*{') {
  $cssAdd = @(
    "",
    "/* CV2: core nodes (nucleo) */",
    ".cv2-core {",
    "  margin-top: 14px;",
    "  padding: 12px 12px 10px;",
    "  border: 1px solid rgba(255,255,255,0.10);",
    "  border-radius: 14px;",
    "  background: rgba(255,255,255,0.06);",
    "  backdrop-filter: blur(10px);",
    "}",
    ".cv2-core__head {",
    "  display: flex;",
    "  flex-direction: column;",
    "  gap: 4px;",
    "  margin-bottom: 10px;",
    "}",
    ".cv2-core__kicker {",
    "  font-size: 11px;",
    "  letter-spacing: 0.18em;",
    "  text-transform: uppercase;",
    "  opacity: 0.75;",
    "}",
    ".cv2-core__title {",
    "  font-size: 14px;",
    "  font-weight: 800;",
    "}",
    ".cv2-core__sub {",
    "  font-size: 12px;",
    "  opacity: 0.75;",
    "}",
    ".cv2-core__pills {",
    "  display: flex;",
    "  flex-wrap: wrap;",
    "  gap: 8px;",
    "}",
    ".cv2-pill {",
    "  display: inline-flex;",
    "  align-items: center;",
    "  gap: 8px;",
    "  padding: 8px 10px;",
    "  border-radius: 999px;",
    "  border: 1px solid rgba(255,255,255,0.12);",
    "  background: rgba(0,0,0,0.18);",
    "  text-decoration: none;",
    "  font-size: 12px;",
    "  font-weight: 700;",
    "}",
    ".cv2-pill:hover {",
    "  transform: translateY(-1px);",
    "}",
    ""
  ) -join "`n"
  $cssRaw = $cssRaw + $cssAdd
  WriteText $cssAbs $cssRaw
}

$r.Add("## Patch: globals.css") | Out-Null
$r.Add("- OK: estilos cv2-core + cv2-pill") | Out-Null
$r.Add("") | Out-Null

# -------------------------
# VERIFY
# -------------------------
AddLines $r (TryRun "cv-verify.ps1 (se existir)" {
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
Write-Host "[OK] B7C finalizado."