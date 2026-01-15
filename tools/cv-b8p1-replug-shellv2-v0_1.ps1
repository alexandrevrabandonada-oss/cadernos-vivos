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
function BackupFile([string]$path,[string]$backupDir){
  if(Test-Path -LiteralPath $path){
    EnsureDir $backupDir
    $name = Split-Path -Leaf $path
    Copy-Item -Force -LiteralPath $path -Destination (Join-Path $backupDir $name)
    return $true
  }
  return $false
}
function NowStamp(){ (Get-Date).ToString("yyyyMMdd-HHmmss") }

$repoRoot   = (Resolve-Path ".").Path
$toolsDir   = Join-Path $repoRoot "tools"
$reportsDir = Join-Path $repoRoot "reports"
EnsureDir $toolsDir
EnsureDir $reportsDir

$stamp = NowStamp
$reportPath = Join-Path $reportsDir ("{0}-cv-b8p1-replug-shellv2.md" -f $stamp)
WriteUtf8NoBom $reportPath ("# CV B8P1 — Replug ShellV2 (Nav + DoorGuide + Portals)`n`n- Data: **$stamp**`n- Repo: $repoRoot`n`n")

function Log([string]$s){ AppendUtf8NoBom $reportPath ($s + "`n") }
function H2([string]$t){ Log ""; Log ("## " + $t); Log "" }

function RunPwsh([string]$title, [string]$file){
  H2 $title
  if(-not (Test-Path -LiteralPath $file)){
    Log ("- arquivo não encontrado: " + $file)
    return 1
  }
  $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
  Log ("[RUN] " + $file)
  Log "~~~"
  $out = & $pwsh -NoProfile -ExecutionPolicy Bypass -File $file 2>&1
  $code = $LASTEXITCODE
  if($null -ne $out){
    foreach($l in $out){ Log ([string]$l) }
  }
  Log "~~~"
  Log ("exit: " + $code)
  Log ""
  return $code
}

H2 "DIAG"

$compDir = Join-Path $repoRoot "src\components\v2"
$shellPath = Join-Path $compDir "ShellV2.tsx"
$navPath   = Join-Path $compDir "Cv2V2Nav.tsx"
$guidePath = Join-Path $compDir "Cv2DoorGuide.tsx"
$portalsPath = Join-Path $compDir "Cv2PortalsCurated.tsx"

Log ("- components/v2 dir exists: " + (Test-Path -LiteralPath $compDir))
Log ("- ShellV2.tsx exists: " + (Test-Path -LiteralPath $shellPath))
Log ("- Cv2V2Nav.tsx exists: " + (Test-Path -LiteralPath $navPath))
Log ("- Cv2DoorGuide.tsx exists: " + (Test-Path -LiteralPath $guidePath))
Log ("- Cv2PortalsCurated.tsx exists: " + (Test-Path -LiteralPath $portalsPath))
Log ""

if(-not (Test-Path -LiteralPath $shellPath)){ throw "ShellV2.tsx não encontrado (src/components/v2)." }
if(-not (Test-Path -LiteralPath $navPath)){ throw "Cv2V2Nav.tsx não encontrado (src/components/v2)." }
if(-not (Test-Path -LiteralPath $guidePath)){ throw "Cv2DoorGuide.tsx não encontrado (src/components/v2)." }

H2 "PATCH"

$backupDir = Join-Path $toolsDir ("_patch_backup\b8p1-replug-shellv2-{0}" -f $stamp)
EnsureDir $backupDir

BackupFile $shellPath $backupDir | Out-Null
BackupFile $navPath $backupDir   | Out-Null
BackupFile $guidePath $backupDir | Out-Null

Log ("- backups em: " + $backupDir)
Log ""

# ---- Write Cv2V2Nav.tsx (encode slug + aria-current)
$navLines = @(
  'import Link from "next/link";',
  '',
  'export type Cv2DoorId = "hub" | "mapa" | "linha" | "linha-do-tempo" | "provas" | "trilhas" | "debate";',
  '',
  'export default function Cv2V2Nav(props: { slug: string; active: Cv2DoorId }) {',
  '  const s = encodeURIComponent(props.slug);',
  '  const base = "/c/" + s + "/v2";',
  '  const items: { id: Cv2DoorId; label: string; href: string }[] = [',
  '    { id: "hub", label: "Hub", href: base },',
  '    { id: "mapa", label: "Mapa", href: base + "/mapa" },',
  '    { id: "linha", label: "Linha", href: base + "/linha" },',
  '    { id: "linha-do-tempo", label: "Linha do tempo", href: base + "/linha-do-tempo" },',
  '    { id: "provas", label: "Provas", href: base + "/provas" },',
  '    { id: "trilhas", label: "Trilhas", href: base + "/trilhas" },',
  '    { id: "debate", label: "Debate", href: base + "/debate" },',
  '  ];',
  '',
  '  return (',
  '    <nav className="cv2-doors" aria-label="Portas do universo" data-cv2="doors-nav">',
  '      {items.map((it) => {',
  '        const on = it.id === props.active;',
  '        return (',
  '          <Link',
  '            key={it.id}',
  '            href={it.href}',
  '            className={on ? "cv2-door cv2-door--active" : "cv2-door"}',
  '            aria-current={on ? "page" : undefined}',
  '          >',
  '            {it.label}',
  '          </Link>',
  '        );',
  '      })}',
  '    </nav>',
  '  );',
  '}'
)
WriteUtf8NoBom $navPath (($navLines -join "`r`n") + "`r`n")
Log ("- wrote: " + $navPath)

# ---- Write Cv2DoorGuide.tsx (import type Cv2DoorId + encode slug)
$guideLines = @(
  'import Link from "next/link";',
  'import type { Cv2DoorId } from "@/components/v2/Cv2V2Nav";',
  '',
  'type Props = {',
  '  slug: string;',
  '  active: Cv2DoorId;',
  '  className?: string;',
  '};',
  '',
  'const ORDER: Cv2DoorId[] = ["hub", "mapa", "linha", "linha-do-tempo", "provas", "trilhas", "debate"];',
  '',
  'function labelOf(id: Cv2DoorId): string {',
  '  switch (id) {',
  '    case "hub": return "Hub";',
  '    case "mapa": return "Mapa";',
  '    case "linha": return "Linha";',
  '    case "linha-do-tempo": return "Linha do tempo";',
  '    case "provas": return "Provas";',
  '    case "trilhas": return "Trilhas";',
  '    case "debate": return "Debate";',
  '    default: return id;',
  '  }',
  '}',
  '',
  'function nextOf(active: Cv2DoorId): Cv2DoorId {',
  '  const i = ORDER.indexOf(active);',
  '  if (i >= 0 && i + 1 < ORDER.length) return ORDER[i + 1];',
  '  if (ORDER.length > 0) return ORDER[0];',
  '  return "mapa";',
  '}',
  '',
  'function prevOf(active: Cv2DoorId): Cv2DoorId {',
  '  const i = ORDER.indexOf(active);',
  '  if (i > 0) return ORDER[i - 1];',
  '  if (ORDER.length > 0) return ORDER[ORDER.length - 1];',
  '  return "hub";',
  '}',
  '',
  'function hrefFor(slug: string, id: Cv2DoorId): string {',
  '  const s = encodeURIComponent(slug);',
  '  const base = "/c/" + s + "/v2";',
  '  if (id === "hub") return base;',
  '  return base + "/" + id;',
  '}',
  '',
  'export default function Cv2DoorGuide({ slug, active, className }: Props) {',
  '  const prev = prevOf(active);',
  '  const next = nextOf(active);',
  '',
  '  return (',
  '    <section data-cv2="door-guide" className={className} style={{ marginTop: 12 }}>',
  '      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 10 }}>',
  '        <div>',
  '          <div style={{ fontSize: 12, opacity: 0.7 }}>Você está em</div>',
  '          <div style={{ fontSize: 14, fontWeight: 700 }}>{labelOf(active)}</div>',
  '        </div>',
  '        <div style={{ display: "flex", gap: 8 }}>',
  '          <Link className="cv2-btn" href={hrefFor(slug, prev)} aria-label={"Voltar: " + labelOf(prev)}>',
  '            Voltar',
  '          </Link>',
  '          <Link className="cv2-btn cv2-btn--accent" href={hrefFor(slug, next)} aria-label={"Próxima: " + labelOf(next)}>',
  '            Próxima porta',
  '          </Link>',
  '        </div>',
  '      </div>',
  '    </section>',
  '  );',
  '}'
)
WriteUtf8NoBom $guidePath (($guideLines -join "`r`n") + "`r`n")
Log ("- wrote: " + $guidePath)

# ---- Write ShellV2.tsx (canonical frame)
$shellLines = @(
  'import Link from "next/link";',
  'import Cv2V2Nav, { type Cv2DoorId } from "@/components/v2/Cv2V2Nav";',
  'import Cv2DoorGuide from "@/components/v2/Cv2DoorGuide";',
  'import Cv2PortalsCurated from "@/components/v2/Cv2PortalsCurated";',
  'import type { CoreNodesV2 } from "@/lib/v2/types";',
  '',
  'export type ShellV2Props = {',
  '  slug: string;',
  '  active: Cv2DoorId;',
  '  title?: string;',
  '  subtitle?: string;',
  '  current?: string;',
  '  coreNodes?: CoreNodesV2;',
  '  showPortals?: boolean;',
  '  children: React.ReactNode;',
  '};',
  '',
  'export function ShellV2(props: ShellV2Props) {',
  '  const slug = props.slug;',
  '  const s = encodeURIComponent(slug);',
  '  const active = props.active;',
  '',
  '  return (',
  '    <div className="min-h-screen w-full bg-neutral-950 text-neutral-50" data-cv2="shell-v2">',
  '      <header className="sticky top-0 z-40 border-b border-neutral-800 bg-neutral-950/85 backdrop-blur">',
  '        <div className="mx-auto max-w-5xl px-4 py-3">',
  '          <div className="flex items-center justify-between gap-3">',
  '            <div className="flex items-center gap-3">',
  '              <Link href={"/c/" + s + "/v2"} className="text-sm font-semibold tracking-wide hover:opacity-90">',
  '                ⟵ Voltar ao Hub',
  '              </Link>',
  '              <span className="text-xs text-neutral-400">/</span>',
  '              <span className="text-xs text-neutral-300">Concreto Zen · V2</span>',
  '            </div>',
  '            <div className="text-xs text-neutral-400">#{active}</div>',
  '          </div>',
  '',
  '          <div className="mt-3">',
  '            <Cv2V2Nav slug={slug} active={active} />',
  '            <Cv2DoorGuide slug={slug} active={active} />',
  '          </div>',
  '',
  '          {(props.title || props.subtitle) ? (',
  '            <div className="mt-4">',
  '              {props.title ? <h1 className="text-xl font-extrabold tracking-tight">{props.title}</h1> : null}',
  '              {props.subtitle ? <p className="mt-1 text-sm text-neutral-300">{props.subtitle}</p> : null}',
  '            </div>',
  '          ) : null}',
  '        </div>',
  '      </header>',
  '',
  '      <main className="mx-auto max-w-5xl px-4 py-8">',
  '        {props.children}',
  '        {(props.showPortals === false) ? null : (',
  '          <div className="mt-10">',
  '            <Cv2PortalsCurated slug={slug} active={active} current={props.current} coreNodes={props.coreNodes} />',
  '          </div>',
  '        )}',
  '      </main>',
  '',
  '      <footer className="border-t border-neutral-800 bg-neutral-950">',
  '        <div className="mx-auto max-w-5xl px-4 py-6 text-xs text-neutral-500">',
  '          <div className="flex flex-wrap items-center justify-between gap-2">',
  '            <span>V2 · Concreto Zen · orientação constante</span>',
  '            <span>Escutar • Cuidar • Organizar</span>',
  '          </div>',
  '        </div>',
  '      </footer>',
  '    </div>',
  '  );',
  '}',
  '',
  'export default ShellV2;'
)
WriteUtf8NoBom $shellPath (($shellLines -join "`r`n") + "`r`n")
Log ("- wrote: " + $shellPath)

H2 "VERIFY (runner canônico)"
$runnerPath = Join-Path $toolsDir "cv-runner.ps1"
$exit = RunPwsh "tools/cv-runner.ps1" $runnerPath
if($exit -ne 0){ throw ("Runner failed (exit " + $exit + "). Veja: " + $reportPath) }

H2 "DONE"
Log "Se o runner ficou verde, agora todas as páginas que usam ShellV2 já ganham:"
Log "- Nav (Cv2V2Nav) + DoorGuide + Portais (curated) consistentes."
Log "- Linha do tempo incluída como porta oficial."
Log ""

Write-Host ("[REPORT] " + $reportPath)
if($OpenReport){
  try { Start-Process $reportPath | Out-Null } catch {}
}