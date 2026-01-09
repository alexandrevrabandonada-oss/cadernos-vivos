# cv-step-b7h-orientation-everywhere-v0_1
$ErrorActionPreference = "Stop"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$repoRoot = (Resolve-Path ".").Path
$nl = [Environment]::NewLine

function EnsureDir([string]$abs) { if (-not (Test-Path -LiteralPath $abs)) { [IO.Directory]::CreateDirectory($abs) | Out-Null } }
function ReadText([string]$abs) { if (-not (Test-Path -LiteralPath $abs)) { return $null }; return [IO.File]::ReadAllText($abs) }
function WriteText([string]$abs, [string]$text) { $enc = New-Object System.Text.UTF8Encoding($false); EnsureDir (Split-Path -Parent $abs); [IO.File]::WriteAllText($abs, $text, $enc) }
function BackupFile([string]$rel) {
  $abs = Join-Path $repoRoot $rel
  if (-not (Test-Path -LiteralPath $abs)) { return }
  $bkDir = Join-Path $repoRoot "tools\_patch_backup"
  EnsureDir $bkDir
  $dst = Join-Path $bkDir ($stamp + "-" + (Split-Path -Leaf $abs) + ".bak")
  Copy-Item -LiteralPath $abs -Destination $dst -Force
}
function TryRun([string]$label, [scriptblock]$sb) {
  try { $out = & $sb 2>&1 | Out-String; return @("## " + $label, "", $out.TrimEnd(), "") }
  catch { return @("## " + $label, "", ("ERR: " + $_.Exception.Message), "") }
}
function AddLines([System.Collections.Generic.List[string]]$list, [object]$block) {
  if ($null -eq $block) { return }
  foreach ($x in @($block)) { $list.Add([string]$x) | Out-Null }
}

EnsureDir (Join-Path $repoRoot "reports")
EnsureDir (Join-Path $repoRoot "tools\_patch_backup")

$rep = Join-Path $repoRoot ("reports\" + $stamp + "-cv-step-b7h-orientation-everywhere.md")
$r = New-Object System.Collections.Generic.List[string]
$r.Add("# Tijolo B7H — Orientação Everywhere (V2) — " + $stamp) | Out-Null
$r.Add("") | Out-Null
$r.Add("Repo: " + $repoRoot) | Out-Null
$r.Add("") | Out-Null

AddLines $r (TryRun "Git status (pre)" { git status })

# ---------------------------------------------------------
# Patch A — novo componente Cv2DoorGuide (server component)
# ---------------------------------------------------------
$guideRel = "src\components\v2\Cv2DoorGuide.tsx"
$guideAbs = Join-Path $repoRoot $guideRel
BackupFile $guideRel

$guide = @(
  'import Link from "next/link";',
  'import type { CoreNodesV2 } from "@/lib/v2/types";',
  'import { coreNodesToDoorOrder, doorById } from "@/lib/v2/doors";',
  '',
  'type MetaLike = { coreNodes?: CoreNodesV2 };',
  '',
  'const ALL = ["mapa", "linha", "linha-do-tempo", "provas", "trilhas", "debate"] as const;',
  'type DoorId = typeof ALL[number];',
  '',
  'type Props = {',
  '  slug: string;',
  '  active: string;',
  '  coreNodes?: CoreNodesV2;',
  '  meta?: MetaLike;',
  '  relatedCount?: number;',
  '};',
  '',
  'function normalizeDoorOrder(order: string[]): DoorId[] {',
  '  const out: DoorId[] = [];',
  '  for (const raw of order) {',
  '    const id = raw as DoorId;',
  '    if ((ALL as readonly string[]).includes(id) && !out.includes(id)) out.push(id);',
  '  }',
  '  if (!out.includes("mapa")) out.unshift("mapa");',
  '  for (const id of ALL) { if (!out.includes(id)) out.push(id); }',
  '  return out;',
  '}',
  '',
  'function safeId(active: string): DoorId {',
  '  const a = active as DoorId;',
  '  if ((ALL as readonly string[]).includes(a)) return a;',
  '  return "mapa";',
  '}',
  '',
  'function labelOf(id: DoorId): string {',
  '  const d = doorById(id);',
  '  return (d.label ? d.label : (d.title ? d.title : id));',
  '}',
  '',
  'function nextAfter(ids: DoorId[], active: DoorId): DoorId {',
  '  const i = ids.indexOf(active);',
  '  if (i >= 0 && i + 1 < ids.length) return ids[i + 1];',
  '  if (ids.length > 0) return ids[0];',
  '  return "mapa";',
  '}',
  '',
  'function pickRelated(ids: DoorId[], active: DoorId, count: number): DoorId[] {',
  '  const out: DoorId[] = [];',
  '  // regra: sempre tenta pôr "mapa" como âncora (se não for a ativa)',
  '  if (active !== "mapa") out.push("mapa");',
  '  // depois pega os próximos na ordem do núcleo',
  '  const start = Math.max(0, ids.indexOf(active));',
  '  for (let step = 1; step < ids.length && out.length < count; step++) {',
  '    const id = ids[(start + step) % ids.length];',
  '    if (id !== active && !out.includes(id)) out.push(id);',
  '  }',
  '  // completa com o resto',
  '  for (const id of ids) {',
  '    if (out.length >= count) break;',
  '    if (id !== active && !out.includes(id)) out.push(id);',
  '  }',
  '  return out.slice(0, count);',
  '}',
  '',
  'export default function Cv2DoorGuide(props: Props) {',
  '  const cn = props.coreNodes ?? props.meta?.coreNodes;',
  '  const ids = normalizeDoorOrder(coreNodesToDoorOrder(cn));',
  '  const active = safeId(props.active);',
  '  const next = nextAfter(ids, active);',
  '  const related = pickRelated(ids, active, props.relatedCount ?? 4);',
  '',
  '  const mapHref = doorById("mapa").href(props.slug);',
  '  const nextHref = doorById(next).href(props.slug);',
  '',
  '  return (',
  '    <section className="cv2-doorGuide" aria-label="Orientação do universo">',
  '      <div className="cv2-doorGuide__row">',
  '        <div className="cv2-doorGuide__here">',
  '          <div className="cv2-doorGuide__kicker">Você está em</div>',
  '          <div className="cv2-doorGuide__label">{labelOf(active)}</div>',
  '        </div>',
  '        <div className="cv2-doorGuide__actions">',
  '          <Link className="cv2-doorGuide__btn is-primary" href={mapHref} title="Voltar para o mapa">',
  '            Voltar pro Mapa',
  '          </Link>',
  '          <Link className="cv2-doorGuide__btn" href={nextHref} title="Próxima porta">',
  '            Próxima: {labelOf(next)}',
  '          </Link>',
  '        </div>',
  '      </div>',
  '',
  '      <div className="cv2-doorGuide__related" role="navigation" aria-label="Relacionados">',
  '        {related.map((id) => (',
  '          <Link key={id} className="cv2-doorGuide__pill" href={doorById(id).href(props.slug)}>',
  '            {labelOf(id)}',
  '          </Link>',
  '        ))}',
  '      </div>',
  '    </section>',
  '  );',
  '}',
  ''
) -join $nl

WriteText $guideAbs ($guide + $nl)
$r.Add("## Patch A") | Out-Null
$r.Add("- wrote: " + $guideRel) | Out-Null
$r.Add("") | Out-Null

# ---------------------------------------------------------
# Patch B — CSS (globals) para o microbloco (mínimo e seguro)
# ---------------------------------------------------------
$cssRel = "src\app\globals.css"
$cssAbs = Join-Path $repoRoot $cssRel
if (Test-Path -LiteralPath $cssAbs) {
  $rawCss = ReadText $cssAbs
  if ($null -ne $rawCss -and $rawCss -notmatch "cv2-doorGuide") {
    BackupFile $cssRel
    $cssBlock = @(
      '',
      '/* ============================= */',
      '/* CV2 — Door Guide (orientation) */',
      '/* ============================= */',
      '.cv2-doorGuide{border:1px solid rgba(255,255,255,.10);border-radius:18px;padding:14px 14px 12px;background:rgba(0,0,0,.24);backdrop-filter:saturate(120%) blur(10px);}',
      '.cv2-doorGuide__row{display:flex;flex-wrap:wrap;gap:10px;align-items:flex-end;justify-content:space-between;}',
      '.cv2-doorGuide__kicker{font-size:12px;letter-spacing:.08em;text-transform:uppercase;opacity:.7;}',
      '.cv2-doorGuide__label{font-size:16px;font-weight:800;letter-spacing:.01em;}',
      '.cv2-doorGuide__actions{display:flex;gap:10px;flex-wrap:wrap;}',
      '.cv2-doorGuide__btn{display:inline-flex;align-items:center;gap:8px;padding:10px 12px;border-radius:999px;border:1px solid rgba(255,255,255,.14);text-decoration:none;background:rgba(255,255,255,.03);}',
      '.cv2-doorGuide__btn:hover{border-color:rgba(255,255,255,.24);background:rgba(255,255,255,.05);}',
      '.cv2-doorGuide__btn.is-primary{border-color:rgba(255,220,120,.35);background:rgba(255,220,120,.08);}',
      '.cv2-doorGuide__related{display:flex;gap:8px;flex-wrap:wrap;margin-top:10px;}',
      '.cv2-doorGuide__pill{display:inline-flex;align-items:center;padding:8px 10px;border-radius:999px;border:1px solid rgba(255,255,255,.12);text-decoration:none;font-size:12px;opacity:.9;background:rgba(255,255,255,.02);}',
      '.cv2-doorGuide__pill:hover{border-color:rgba(255,255,255,.22);background:rgba(255,255,255,.04);}',
      ''
    ) -join $nl
    WriteText $cssAbs ($rawCss.TrimEnd() + $cssBlock + $nl)
    $r.Add("## Patch B") | Out-Null
    $r.Add("- globals.css: added cv2-doorGuide styles") | Out-Null
    $r.Add("") | Out-Null
  } else {
    $r.Add("## Patch B") | Out-Null
    $r.Add("- skip: globals.css já tem cv2-doorGuide (ou ausente)") | Out-Null
    $r.Add("") | Out-Null
  }
}

# ---------------------------------------------------------
# Patch C — inserir o guia em cada porta V2 (best-effort)
# ---------------------------------------------------------
$targets = @(
  @{ rel = "src\app\c\[slug]\v2\mapa\page.tsx"; door = "mapa" },
  @{ rel = "src\app\c\[slug]\v2\linha\page.tsx"; door = "linha" },
  @{ rel = "src\app\c\[slug]\v2\linha-do-tempo\page.tsx"; door = "linha-do-tempo" },
  @{ rel = "src\app\c\[slug]\v2\provas\page.tsx"; door = "provas" },
  @{ rel = "src\app\c\[slug]\v2\trilhas\page.tsx"; door = "trilhas" },
  @{ rel = "src\app\c\[slug]\v2\debate\page.tsx"; door = "debate" },
  @{ rel = "src\app\c\[slug]\v2\trilhas\[id]\page.tsx"; door = "trilhas" }
)

function GuessMetaExpr([string]$raw) {
  if ($raw -match "data\.meta") { return "data.meta" }
  if ($raw -match "caderno\.meta") { return "caderno.meta" }
  if ($raw -match "doc\.meta") { return "doc.meta" }
  # só se existir como objeto (evita falsos positivos em strings)
  if ($raw -match "const\s+meta\s*=" -or $raw -match "let\s+meta\s*=") { return "meta" }
  return $null
}

function GuessSlugExprFromV2NavLine([string]$line) {
  $m = [regex]::Match($line, "slug=\{([^}]+)\}")
  if ($m.Success) { return $m.Groups[1].Value }
  return "slug"
}

foreach ($t in $targets) {
  $rel = $t.rel
  $door = $t.door
  $abs = Join-Path $repoRoot $rel
  if (-not (Test-Path -LiteralPath $abs)) {
    $r.Add("## Patch C") | Out-Null
    $r.Add("- skip missing: " + $rel) | Out-Null
    $r.Add("") | Out-Null
    continue
  }

  $raw = ReadText $abs
  if ($null -eq $raw) { continue }

  if ($raw -match "Cv2DoorGuide") {
    $r.Add("## Patch C") | Out-Null
    $r.Add("- skip (já tem Cv2DoorGuide): " + $rel) | Out-Null
    $r.Add("") | Out-Null
    continue
  }

  BackupFile $rel

  $lines = $raw -split "`n"

  # inserir import
  $hasImport = $raw -match "from\s+`"@/components/v2/Cv2DoorGuide`""
  if (-not $hasImport) {
    $lastImport = -1
    for ($i=0; $i -lt $lines.Length; $i++) {
      if ($lines[$i] -match "^\s*import\s+") { $lastImport = $i }
    }
    if ($lastImport -ge 0) {
      $lines = $lines[0..$lastImport] + @('import Cv2DoorGuide from "@/components/v2/Cv2DoorGuide";') + $lines[($lastImport+1)..($lines.Length-1)]
    } else {
      $lines = @('import Cv2DoorGuide from "@/components/v2/Cv2DoorGuide";') + $lines
    }
  }

  # achar V2Nav pra posicionar o guide logo depois
  $idxNav = -1
  for ($i=0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match "<V2Nav") { $idxNav = $i; break }
  }

  $metaExpr = GuessMetaExpr $raw
  $inserted = $false

  if ($idxNav -ge 0) {
    $indent = ([regex]::Match($lines[$idxNav], "^\s*")).Value
    $slugExpr = GuessSlugExprFromV2NavLine $lines[$idxNav]
    $metaPart = ""
    if ($metaExpr) { $metaPart = " meta={" + $metaExpr + "}" }

    $ins = $indent + "<Cv2DoorGuide slug={" + $slugExpr + "} active=""" + $door + """" + $metaPart + " />"
    $lines = $lines[0..$idxNav] + @($ins) + $lines[($idxNav+1)..($lines.Length-1)]
    $inserted = $true
  }

  if (-not $inserted) {
    $r.Add("## Patch C") | Out-Null
    $r.Add("- warn: não achei <V2Nav> para inserir o guide em " + $rel) | Out-Null
    $r.Add("") | Out-Null
  } else {
    $r.Add("## Patch C") | Out-Null
    $r.Add("- inserted Cv2DoorGuide (" + $door + "): " + $rel) | Out-Null
    $r.Add("") | Out-Null
  }

  WriteText $abs ((($lines -join "`n").TrimEnd()) + "`n")
}

# ---------------------------------------------------------
# VERIFY
# ---------------------------------------------------------
AddLines $r (TryRun "npm run lint" {
  $npm = (Get-Command npm.cmd -ErrorAction Stop).Path
  & $npm run lint
})
AddLines $r (TryRun "npm run build" {
  $npm = (Get-Command npm.cmd -ErrorAction Stop).Path
  & $npm run build
})
AddLines $r (TryRun "Git status (post)" { git status })

WriteText $rep ([string]::Join($nl, $r.ToArray()) + $nl)
Write-Host ("[REPORT] " + $rep)
Write-Host "[OK] B7H finalizado."