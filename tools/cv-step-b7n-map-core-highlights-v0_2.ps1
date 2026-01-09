# cv-step-b7n-map-core-highlights-v0_2
# Map: adicionar "Destaques do Núcleo" no painel do Mapa V2
# Fix: usar -LiteralPath para caminhos com [slug]

param()

$ErrorActionPreference = "Stop"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Write-Host ("== CV B7N MAP CORE HIGHLIGHTS v0_2 == " + $stamp)

$root = (Resolve-Path ".").Path

function EnsureDir([string]$p){ if(-not (Test-Path -LiteralPath $p)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }

function WriteUtf8NoBom([string]$path, [string]$content){
  EnsureDir (Split-Path -Parent $path)
  $enc = New-Object System.Text.UTF8Encoding($false)
  [IO.File]::WriteAllText($path, $content, $enc)
}

function BackupFile([string]$absPath){
  if(Test-Path -LiteralPath $absPath){
    $bdir = Join-Path $root ("tools\_patch_backup\" + $stamp)
    EnsureDir $bdir
    $dst = Join-Path $bdir ([IO.Path]::GetFileName($absPath))
    Copy-Item -LiteralPath $absPath -Destination $dst -Force
  }
}

function FindNpmExe {
  $c = Get-Command "npm.cmd" -ErrorAction SilentlyContinue
  if ($c -and $c.Path) { return $c.Path }
  $c = Get-Command "npm" -ErrorAction SilentlyContinue
  if ($c -and $c.Source) { return $c.Source }
  throw "npm not found in PATH"
}

function Run([string]$cmd, [string[]]$cmdArgs){
  $argLine = ""
  if ($cmdArgs -and $cmdArgs.Count -gt 0) { $argLine = ($cmdArgs -join " ") }
  Write-Host ("[RUN] " + $cmd + " " + $argLine)
  & $cmd @cmdArgs
  if ($LASTEXITCODE -ne 0) { throw ("Command failed: " + $cmd + " " + $argLine) }
}
}

# Paths (IMPORTANT: [slug] exige LiteralPath)
$compRel = "src\components\v2\Cv2CoreHighlights.tsx"
$pageRel = "src\app\c\[slug]\v2\mapa\page.tsx"
$cssRel  = "src\app\globals.css"

$comp = Join-Path $root $compRel
$page = Join-Path $root $pageRel
$css  = Join-Path $root $cssRel

# Guards
if (-not (Test-Path -LiteralPath $page)) { throw ("Missing map page: " + $pageRel) }
if (-not (Test-Path -LiteralPath $css))  { throw ("Missing globals: " + $cssRel) }

# PATCH 1) Component file
BackupFile $comp

$ts = @()
$ts += 'import Link from "next/link";'
$ts += ''
$ts += 'type CoreCard = {'
$ts += '  id: string;'
$ts += '  label: string;'
$ts += '  href: string;'
$ts += '  hint?: string;'
$ts += '};'
$ts += ''
$ts += 'function isRecord(v: unknown): v is Record<string, unknown> {'
$ts += '  return !!v && typeof v === "object" && !Array.isArray(v);'
$ts += '}'
$ts += ''
$ts += 'function asStr(v: unknown): string | null {'
$ts += '  return typeof v === "string" ? v : null;'
$ts += '}'
$ts += ''
$ts += 'function pickStr(o: Record<string, unknown>, keys: string[]): string | null {'
$ts += '  for (const k of keys) {'
$ts += '    const s = asStr(o[k]);'
$ts += '    if (s && s.trim()) return s.trim();'
$ts += '  }'
$ts += '  return null;'
$ts += '}'
$ts += ''
$ts += 'function routeFromId(idRaw: string): string {'
$ts += '  const id = idRaw.toLowerCase().trim();'
$ts += '  const map: Record<string, string> = {'
$ts += '    hub: "",'
$ts += '    mapa: "mapa",'
$ts += '    map: "mapa",'
$ts += '    linha: "linha",'
$ts += '    line: "linha",'
$ts += '    provas: "provas",'
$ts += '    evidencias: "provas",'
$ts += '    trilhas: "trilhas",'
$ts += '    trilha: "trilhas",'
$ts += '    debate: "debate",'
$ts += '    tempo: "linha-do-tempo",'
$ts += '    "linha-do-tempo": "linha-do-tempo",'
$ts += '    timeline: "linha-do-tempo",'
$ts += '  };'
$ts += '  return map[id] ?? id;'
$ts += '}'
$ts += ''
$ts += 'function normalizeCoreCards(meta: unknown, slug: string): CoreCard[] {'
$ts += '  const m = isRecord(meta) ? meta : {};'
$ts += '  const raw = m["coreNodes"];'
$ts += '  const list: unknown[] = Array.isArray(raw) ? raw : [];'
$ts += ''
$ts += '  const out: CoreCard[] = [];'
$ts += '  for (const it of list) {'
$ts += '    if (typeof it === "string") {'
$ts += '      const id = it;'
$ts += '      const seg = routeFromId(id);'
$ts += '      const href = seg ? `/c/${slug}/v2/${seg}` : `/c/${slug}/v2`;'
$ts += '      out.push({ id, label: id, href });'
$ts += '      continue;'
$ts += '    }'
$ts += '    if (!isRecord(it)) continue;'
$ts += '    const id = pickStr(it, ["id","key","door","slug","name","title","label"]) ?? "node";'
$ts += '    const label = pickStr(it, ["label","title","name"]) ?? id;'
$ts += '    const hint = pickStr(it, ["hint","summary","desc","description","oneLiner"]) ?? undefined;'
$ts += '    const seg = routeFromId(pickStr(it, ["door","key","id","slug"]) ?? id);'
$ts += '    const href = seg ? `/c/${slug}/v2/${seg}` : `/c/${slug}/v2`;'
$ts += '    out.push({ id, label, href, hint });'
$ts += '  }'
$ts += ''
$ts += '  if (out.length === 0) {'
$ts += '    const base: Array<{id: string; label: string; seg: string}> = ['
$ts += '      { id: "mapa", label: "Mapa", seg: "mapa" },'
$ts += '      { id: "linha", label: "Linha", seg: "linha" },'
$ts += '      { id: "provas", label: "Provas", seg: "provas" },'
$ts += '      { id: "debate", label: "Debate", seg: "debate" },'
$ts += '      { id: "trilhas", label: "Trilhas", seg: "trilhas" },'
$ts += '      { id: "tempo", label: "Linha do tempo", seg: "linha-do-tempo" },'
$ts += '    ];'
$ts += '    for (const b of base) out.push({ id: b.id, label: b.label, href: `/c/${slug}/v2/${b.seg}` });'
$ts += '  }'
$ts += ''
$ts += '  const seen = new Set<string>();'
$ts += '  const uniq: CoreCard[] = [];'
$ts += '  for (const c of out) {'
$ts += '    if (seen.has(c.href)) continue;'
$ts += '    seen.add(c.href);'
$ts += '    uniq.push(c);'
$ts += '  }'
$ts += '  return uniq.slice(0, 9);'
$ts += '}'
$ts += ''
$ts += 'export function Cv2CoreHighlights(props: { slug: string; meta: unknown; current?: string }) {'
$ts += '  const cards = normalizeCoreCards(props.meta, props.slug);'
$ts += '  const current = (props.current ?? "").toLowerCase().trim();'
$ts += '  return ('
$ts += '    <section className="cv2-core-highlights" data-cv2-core-highlights="1">'
$ts += '      <div className="cv2-core-highlights__head">'
$ts += '        <div className="cv2-core-highlights__title">Destaques do Núcleo</div>'
$ts += '        <div className="cv2-core-highlights__sub">Portas principais do universo — escolha uma rota.</div>'
$ts += '      </div>'
$ts += '      <div className="cv2-core-highlights__grid">'
$ts += '        {cards.map((c) => {'
$ts += '          const idNorm = routeFromId(c.id);'
$ts += '          const active = idNorm === current || c.id.toLowerCase() === current;'
$ts += '          return ('
$ts += '            <Link key={c.href} href={c.href} className={"cv2-core-highlights__card" + (active ? " is-active" : "")}>'
$ts += '              <div className="cv2-core-highlights__left">'
$ts += '                <div className="cv2-core-highlights__label">{c.label}</div>'
$ts += '                {c.hint ? <div className="cv2-core-highlights__hint">{c.hint}</div> : null}'
$ts += '              </div>'
$ts += '              <div className="cv2-core-highlights__go">Entrar</div>'
$ts += '            </Link>'
$ts += '          );'
$ts += '        })}'
$ts += '      </div>'
$ts += '    </section>'
$ts += '  );'
$ts += '}'
$ts += ''

WriteUtf8NoBom $comp ($ts -join "`n")
Write-Host ("[PATCH] wrote -> " + $compRel)

# PATCH 2) CSS append
BackupFile $css
$cssRaw = Get-Content -LiteralPath $css -Raw
$cssMarker = "/* cv2-core-highlights */"
if ($cssRaw -notmatch [regex]::Escape($cssMarker)) {
  $block = @()
  $block += ""
  $block += $cssMarker
  $block += ".cv2-core-highlights{margin-top:12px}"
  $block += ".cv2-core-highlights__head{margin:0 0 8px 0}"
  $block += ".cv2-core-highlights__title{font-weight:700;letter-spacing:.02em}"
  $block += ".cv2-core-highlights__sub{opacity:.75;font-size:12px;margin-top:2px}"
  $block += ".cv2-core-highlights__grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}"
  $block += "@media (max-width: 920px){.cv2-core-highlights__grid{grid-template-columns:1fr}}"
  $block += ".cv2-core-highlights__card{display:flex;align-items:center;justify-content:space-between;padding:12px 14px;border-radius:14px;border:1px solid rgba(255,255,255,.10);background:rgba(255,255,255,.04);text-decoration:none}"
  $block += ".cv2-core-highlights__card:hover{border-color:rgba(255,255,255,.18);background:rgba(255,255,255,.06)}"
  $block += ".cv2-core-highlights__card.is-active{border-color:rgba(255,217,0,.35);background:rgba(255,217,0,.06)}"
  $block += ".cv2-core-highlights__label{font-weight:650}"
  $block += ".cv2-core-highlights__hint{opacity:.72;font-size:12px;margin-top:2px;line-height:1.25}"
  $block += ".cv2-core-highlights__go{opacity:.85;font-size:12px;border:1px solid rgba(255,255,255,.14);padding:6px 10px;border-radius:999px}"
  $block += ""
  $cssRaw = $cssRaw + ($block -join "`n")
  WriteUtf8NoBom $css $cssRaw
  Write-Host ("[PATCH] appended css -> " + $cssRel)
} else {
  Write-Host "[OK] css already has core highlights"
}

# PATCH 3) Map page insert before portals curated
BackupFile $page
$pageRaw = Get-Content -LiteralPath $page -Raw

if ($pageRaw -match "Cv2CoreHighlights") {
  Write-Host "[OK] Map page already references Cv2CoreHighlights"
} elseif ($pageRaw -match "<Cv2PortalsCurated") {
  $slugExpr = "slug"
  $metaExpr = "meta"

  $portIx = $pageRaw.IndexOf("Cv2PortalsCurated")
  if ($portIx -ge 0) {
    $chunkStart = [Math]::Max(0, $portIx - 600)
    $chunkEnd = [Math]::Min($pageRaw.Length, $portIx + 1100)
    $chunk = $pageRaw.Substring($chunkStart, $chunkEnd - $chunkStart)

    $sm = [regex]::Match($chunk, "slug\s*=\s*{\s*([^}]+)\s*}")
    if ($sm.Success) { $slugExpr = $sm.Groups[1].Value.Trim() }

    $mm = [regex]::Match($chunk, "meta\s*=\s*{\s*([^}]+)\s*}")
    if ($mm.Success) { $metaExpr = $mm.Groups[1].Value.Trim() }
  }

  $marker = "{/* cv2-core-highlights */}"
  if ($pageRaw -notmatch [regex]::Escape($marker)) {
    $needle = "<Cv2PortalsCurated"
    $ix = $pageRaw.IndexOf($needle)
    if ($ix -ge 0) {
      $ins = @()
      $ins += $marker
      $ins += ("<Cv2CoreHighlights slug={" + $slugExpr + "} meta={" + $metaExpr + "} current=""mapa"" />")
      $ins += ""
      $pageRaw = $pageRaw.Insert($ix, ($ins -join "`n"))

      $importLine = 'import { Cv2CoreHighlights } from "@/components/v2/Cv2CoreHighlights";'
      if ($pageRaw -notmatch [regex]::Escape($importLine)) {
        $imp = [regex]::Matches($pageRaw, "(?m)^\s*import\s.+?;\s*$")
        if ($imp.Count -gt 0) {
          $last = $imp[$imp.Count-1]
          $insertAt = $last.Index + $last.Length
          $pageRaw = $pageRaw.Insert($insertAt, "`n" + $importLine)
        } else {
          $pageRaw = $importLine + "`n" + $pageRaw
        }
      }

      WriteUtf8NoBom $page $pageRaw
      Write-Host ("[PATCH] inserted highlights -> " + $pageRel)
    } else {
      Write-Host "[WARN] Could not locate <Cv2PortalsCurated ...> start tag."
    }
  } else {
    Write-Host "[OK] marker already present"
  }
} else {
  Write-Host "[WARN] Map page has no <Cv2PortalsCurated ...> — skipping insertion to avoid unused import."
}

# VERIFY
$npm = FindNpmExe
Run $npm "run" "lint"
Run $npm "run" "build"

# REPORT
EnsureDir (Join-Path $root "reports")
$reportPath = Join-Path $root ("reports\" + $stamp + "-cv-step-b7n-map-core-highlights-v0_2.md")
$rep = @()
$rep += ("# Step B7N v0_2 — Map: Destaques do Núcleo — " + $stamp)
$rep += ""
$rep += ("Repo: " + $root)
$rep += ""
$rep += "## Mudanças"
$rep += ("- + " + $compRel)
$rep += ("- ~ " + $pageRel)
$rep += ("- ~ " + $cssRel)
$rep += ""
$rep += "## Verify"
$rep += "- npm run lint"
$rep += "- npm run build"
$rep += ""
WriteUtf8NoBom $reportPath ($rep -join "`n")
Write-Host ("[OK] report -> " + $reportPath)

Write-Host "DONE."