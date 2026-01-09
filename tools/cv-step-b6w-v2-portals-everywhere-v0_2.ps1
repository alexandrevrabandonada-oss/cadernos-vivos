# cv-step-b6w-v2-portals-everywhere-v0_2
$ErrorActionPreference = "Stop"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Write-Host ("== cv-step-b6w-v2-portals-everywhere-v0_2 == " + $stamp)

$repoRoot = (Resolve-Path ".").Path

# ------------------------------------------------------------
# bootstrap
# ------------------------------------------------------------
$boot = Join-Path $repoRoot "tools\_bootstrap.ps1"
if (Test-Path -LiteralPath $boot) {
  . $boot
} else {
  function EnsureDir([string]$p) { [IO.Directory]::CreateDirectory($p) | Out-Null }
  function WriteUtf8NoBom([string]$p, [string]$content) {
    $enc = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($p, $content, $enc)
  }
  function BackupFile([string]$p) {
    $bkDir = Join-Path $repoRoot "tools\_patch_backup"
    EnsureDir $bkDir
    $leaf = Split-Path -Leaf $p
    $dest = Join-Path $bkDir ($stamp + "-" + $leaf + ".bak")
    Copy-Item -LiteralPath $p -Destination $dest -Force
    return $dest
  }
}

function RunNpm([string[]]$npmArgs) {
  $npm = (Get-Command npm.cmd -ErrorAction Stop).Path
  $out = (& $npm @npmArgs 2>&1 | Out-String)
  return @{ out=$out; code=$LASTEXITCODE }
}

Write-Host ("[DIAG] Repo: " + $repoRoot)

# ------------------------------------------------------------
# paths
# ------------------------------------------------------------
$globalsAbs = Join-Path $repoRoot "src\app\globals.css"
if (-not (Test-Path -LiteralPath $globalsAbs)) { throw ("[STOP] não achei: " + $globalsAbs) }

$v2Root = Join-Path $repoRoot "src\app\c\[slug]\v2"
if (-not (Test-Path -LiteralPath $v2Root)) { throw ("[STOP] não achei: " + $v2Root) }

$portalsAbs = Join-Path $repoRoot "src\components\v2\V2Portals.tsx"
EnsureDir (Split-Path -Parent $portalsAbs)

# ------------------------------------------------------------
# PATCH: V2Portals (tolerante: slug opcional; active/current alias)
# ------------------------------------------------------------
if (Test-Path -LiteralPath $portalsAbs) {
  $bkP = BackupFile $portalsAbs
  Write-Host ("[BK]    tools/_patch_backup/" + (Split-Path -Leaf $bkP))
}

$portalsTs = @"
import Link from "next/link";

type DoorId = "hub" | "mapa" | "linha" | "linha-do-tempo" | "provas" | "trilhas" | "debate";

type Props = {
  slug?: string;
  /** use este */
  active?: DoorId | string;
  /** alias (legacy) */
  current?: DoorId | string;
  title?: string;
};

type Door = { id: DoorId; label: string; href: (slug: string) => string; hint: string };

const DOORS: Door[] = [
  { id: "hub", label: "Hub", href: (slug) => ("/c/" + slug + "/v2"), hint: "Núcleo do universo." },
  { id: "mapa", label: "Mapa", href: (slug) => ("/c/" + slug + "/v2/mapa"), hint: "Lugares, conexões e portas." },
  { id: "linha", label: "Linha", href: (slug) => ("/c/" + slug + "/v2/linha"), hint: "Nós do universo: temas e tensões." },
  { id: "linha-do-tempo", label: "Linha do tempo", href: (slug) => ("/c/" + slug + "/v2/linha-do-tempo"), hint: "Sequência e viradas." },
  { id: "provas", label: "Provas", href: (slug) => ("/c/" + slug + "/v2/provas"), hint: "Fontes, links e rastros." },
  { id: "trilhas", label: "Trilhas", href: (slug) => ("/c/" + slug + "/v2/trilhas"), hint: "Caminhos guiados." },
  { id: "debate", label: "Debate", href: (slug) => ("/c/" + slug + "/v2/debate"), hint: "Conversa em camadas." },
];

const ORDER: DoorId[] = ["mapa","linha","linha-do-tempo","provas","trilhas","debate"];

function normDoor(x: string | undefined): DoorId {
  const v = (x || "").trim().toLowerCase();
  if (v === "hub") return "hub";
  if (v === "mapa") return "mapa";
  if (v === "linha") return "linha";
  if (v === "linha-do-tempo" || v === "linhadotempo") return "linha-do-tempo";
  if (v === "provas") return "provas";
  if (v === "trilhas") return "trilhas";
  if (v === "debate") return "debate";
  return "hub";
}

function nextDoors(current: DoorId): DoorId[] {
  if (current === "hub") return ["mapa","linha","provas"];
  const i = ORDER.indexOf(current);
  if (i < 0) return ["mapa","linha","provas"];
  const a = ORDER[(i + 1) % ORDER.length];
  const b = ORDER[(i + 2) % ORDER.length];
  const c = ORDER[(i + 3) % ORDER.length];
  return [a,b,c];
}

export default function V2Portals(props: Props) {
  const slug = (props.slug || "").trim();
  if (!slug) return null;

  const current = normDoor((props.active as string) || (props.current as string));
  const next = nextDoors(current);
  const pick = (id: DoorId) => DOORS.find(d => d.id === id)!;

  return (
    <section className="cv2-portals" aria-label="Portais">
      <div className="cv2-portals__top">
        <div className="cv2-portals__title">
          <div className="cv2-portals__kicker">Portais</div>
          <div className="cv2-portals__h">Próximas portas</div>
          <div className="cv2-portals__p">Mapa primeiro. Depois Linha → Provas → Trilhas → Debate.</div>
        </div>

        <div className="cv2-portals__chiprow">
          <Link className="cv2-chip" href={pick("hub").href(slug)}>Voltar ao Hub</Link>
          <Link className="cv2-chip cv2-chip--accent" href={pick("mapa").href(slug)}>Começar pelo Mapa →</Link>
        </div>
      </div>

      <div className="cv2-portals__grid">
        {next.map((id) => {
          const d = pick(id);
          const isCur = current === id;
          return (
            <Link key={id} href={d.href(slug)} className={"cv2-portal" + (isCur ? " cv2-portal--current" : "")}>
              <div className="cv2-portal__row">
                <div className="cv2-portal__label">{d.label}</div>
                <div className="cv2-portal__btn">abrir</div>
              </div>
              <div className="cv2-portal__hint">{d.hint}</div>
            </Link>
          );
        })}
      </div>

      <div className="cv2-portals__foot">Você está em <b>{pick(current).label}</b>. Use os portais para navegar sem se perder.</div>
    </section>
  );
}
"@

WriteUtf8NoBom $portalsAbs $portalsTs
Write-Host ("[PATCH] " + ($portalsAbs.Substring($repoRoot.Length+1).Replace("\","/")))

# ------------------------------------------------------------
# PATCH: globals.css append (HERE-STRING com @media seguro)
# ------------------------------------------------------------
$cssMarker = "/* CV2_PORTALS v0_2 */"
$g = Get-Content -LiteralPath $globalsAbs -Raw
if (-not $g) { throw "[STOP] globals.css vazio (Get-Content -Raw retornou null)" }

if ($g -notmatch [regex]::Escape($cssMarker)) {
  $bkG = BackupFile $globalsAbs
  Write-Host ("[BK]    tools/_patch_backup/" + (Split-Path -Leaf $bkG))

  $css = @"
$cssMarker
.cv2-portals {
  margin: 18px 0 0;
  padding: 14px;
  border: 1px solid rgba(255,255,255,0.12);
  border-radius: 14px;
  background: rgba(0,0,0,0.18);
}
.cv2-portals__top {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 12px;
}
.cv2-portals__kicker {
  font-size: 11px;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  opacity: 0.7;
}
.cv2-portals__h {
  font-size: 16px;
  font-weight: 700;
  margin-top: 2px;
}
.cv2-portals__p {
  font-size: 12px;
  opacity: 0.75;
  margin-top: 3px;
}
.cv2-portals__chiprow {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
  justify-content: flex-end;
}
.cv2-chip {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 7px 10px;
  border-radius: 999px;
  border: 1px solid rgba(255,255,255,0.16);
  background: rgba(0,0,0,0.15);
  font-size: 12px;
  text-decoration: none;
}
.cv2-chip:hover { border-color: rgba(255,255,255,0.28); }
.cv2-chip--accent {
  border-color: rgba(247,198,0,0.55);
  box-shadow: 0 0 0 2px rgba(247,198,0,0.10) inset;
}
.cv2-portals__grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 10px;
}
.cv2-portal {
  display: block;
  padding: 12px;
  border-radius: 12px;
  border: 1px solid rgba(255,255,255,0.14);
  background: rgba(0,0,0,0.12);
  text-decoration: none;
}
.cv2-portal:hover { border-color: rgba(255,255,255,0.26); }
.cv2-portal--current {
  border-color: rgba(247,198,0,0.65);
  box-shadow: 0 0 0 2px rgba(247,198,0,0.12) inset;
}
.cv2-portal__row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}
.cv2-portal__label { font-weight: 700; font-size: 13px; }
.cv2-portal__btn {
  font-size: 11px;
  opacity: 0.7;
  padding: 3px 8px;
  border-radius: 999px;
  border: 1px solid rgba(255,255,255,0.16);
}
.cv2-portal__hint { margin-top: 6px; font-size: 12px; opacity: 0.75; }
.cv2-portals__foot { margin-top: 10px; font-size: 12px; opacity: 0.8; }

@media (max-width: 900px) {
  .cv2-portals__top { flex-direction: column; align-items: flex-start; }
  .cv2-portals__chiprow { justify-content: flex-start; }
  .cv2-portals__grid { grid-template-columns: 1fr; }
}
"@

  WriteUtf8NoBom $globalsAbs ($g.TrimEnd() + "`n`n" + $css.TrimEnd() + "`n")
  Write-Host "[PATCH] src/app/globals.css (append CV2_PORTALS v0_2)"
} else {
  Write-Host "[SKIP] globals.css já tem CV2_PORTALS v0_2"
}

# ------------------------------------------------------------
# PATCH: inject into V2 pages (idempotente)
# ------------------------------------------------------------
function DoorFromAbs([string]$abs) {
  $p = $abs.Replace("\","/").ToLowerInvariant()
  if ($p -match "/v2/page\.tsx$") { return "hub" }
  if ($p -match "/v2/mapa/page\.tsx$") { return "mapa" }
  if ($p -match "/v2/linha/page\.tsx$") { return "linha" }
  if ($p -match "/v2/linha-do-tempo/page\.tsx$") { return "linha-do-tempo" }
  if ($p -match "/v2/provas/page\.tsx$") { return "provas" }
  if ($p -match "/v2/trilhas/page\.tsx$") { return "trilhas" }
  if ($p -match "/v2/debate/page\.tsx$") { return "debate" }
  return $null
}

$pages = @(Get-ChildItem -LiteralPath $v2Root -Recurse -File -Filter "page.tsx")
Write-Host ("[DIAG] páginas V2: " + $pages.Count)

$import = 'import V2Portals from "@/components/v2/V2Portals";'
$patched = @()

foreach ($f in $pages) {
  # pula trilhas/[id]
  if ($f.FullName -match "\\v2\\trilhas\\\[id\\]\\page\.tsx$") { continue }

  $door = DoorFromAbs $f.FullName
  if (-not $door) { continue }

  $abs = $f.FullName
  $rel = $abs.Substring($repoRoot.Length+1).Replace("\","/")

  $raw = Get-Content -LiteralPath $abs -Raw
  if (-not $raw) { throw ("[STOP] arquivo vazio: " + $rel) }

  # se já tem, só garante props mínimas
  if ($raw -match "<V2Portals\b") {
    # corrige casos sem slug: <V2Portals active="x" />
    $raw2 = [regex]::Replace($raw, "<V2Portals\s+active=""([^""]+)""\s*/>", "<V2Portals slug={slug} active=""`$1"" />")
    $raw2 = [regex]::Replace($raw2, "<V2Portals\s+current=""([^""]+)""\s*/>", "<V2Portals slug={slug} active=""`$1"" />")
    if ($raw2 -ne $raw) {
      $bk = BackupFile $abs
      Write-Host ("[BK]    tools/_patch_backup/" + (Split-Path -Leaf $bk))
      WriteUtf8NoBom $abs $raw2
      Write-Host ("[PATCH] " + $rel + " (fix props V2Portals)")
      $patched += $rel
    } else {
      Write-Host ("[SKIP] já tem V2Portals: " + $rel)
    }
    continue
  }

  # precisa ter slug na página para injetar com segurança
  if ($raw -notmatch "\bconst\s+slug\b" -and $raw -notmatch "\bslug\b") {
    Write-Host ("[WARN] sem slug aparente, pulei: " + $rel)
    continue
  }

  $bk = BackupFile $abs
  Write-Host ("[BK]    tools/_patch_backup/" + (Split-Path -Leaf $bk))

  # import
  if ($raw -notmatch [regex]::Escape($import)) {
    $lines = $raw -split "`r?`n"
    $lastImport = -1
    for ($i=0; $i -lt $lines.Length; $i++) { if ($lines[$i] -match "^\s*import\s+") { $lastImport = $i } }
    if ($lastImport -ge 0) {
      $lines = @($lines[0..$lastImport] + @($import) + $lines[($lastImport+1)..($lines.Length-1)])
      $raw = ($lines -join "`n")
    } else {
      $raw = $import + "`n" + $raw
    }
    Write-Host ("[PATCH] import V2Portals -> " + $rel)
  }

  $inject = @"
      {/* CV2_PORTALS */}
      <V2Portals slug={slug} active="$door" />

"@

  $idx = $raw.IndexOf("</main>", [System.StringComparison]::OrdinalIgnoreCase)
  if ($idx -gt 0) {
    $raw = $raw.Substring(0,$idx) + $inject + $raw.Substring($idx)
  } else {
    $idx2 = $raw.LastIndexOf("</div>", [System.StringComparison]::OrdinalIgnoreCase)
    if ($idx2 -gt 0) {
      $raw = $raw.Substring(0,$idx2) + $inject + $raw.Substring($idx2)
    } else {
      throw ("[STOP] não achei </main> nem </div> para injetar em: " + $rel)
    }
  }

  WriteUtf8NoBom $abs $raw
  Write-Host ("[PATCH] " + $rel + " (inject V2Portals door=" + $door + ")")
  $patched += $rel
}

# ------------------------------------------------------------
# VERIFY
# ------------------------------------------------------------
$verify = Join-Path $repoRoot "tools\cv-verify.ps1"
if (Test-Path -LiteralPath $verify) {
  Write-Host ("[RUN] " + $verify)
  & $verify
  if ($LASTEXITCODE -ne 0) { throw ("[STOP] cv-verify falhou (exit=" + $LASTEXITCODE + ")") }
}

Write-Host "[RUN] npm run lint"
$r1 = RunNpm @("run","lint")
if ($r1.code -ne 0) { Write-Host $r1.out; throw ("[STOP] lint falhou (exit=" + $r1.code + ")") }

Write-Host "[RUN] npm run build"
$r2 = RunNpm @("run","build")
if ($r2.code -ne 0) { Write-Host $r2.out; throw ("[STOP] build falhou (exit=" + $r2.code + ")") }

# ------------------------------------------------------------
# REPORT
# ------------------------------------------------------------
$repDir = Join-Path $repoRoot "reports"
EnsureDir $repDir
$rep = Join-Path $repDir ($stamp + "-cv-step-b6w-v2-portals-everywhere-v0_2.md")

$body = @(
("# CV B6W v0_2 — V2 Portais Everywhere — " + $stamp),
"",
("Repo: " + $repoRoot),
"",
"## PATCH",
"- src/components/v2/V2Portals.tsx (tolerante a active/current; slug opcional)",
"- src/app/globals.css (CV2_PORTALS v0_2 com @media via here-string)",
("- páginas alteradas: " + $patched.Count),
($patched | ForEach-Object { "  - " + $_ }),
"",
"## VERIFY",
("- lint: " + $r1.code),
("- build: " + $r2.code)
) -join "`n"

WriteUtf8NoBom $rep $body
Write-Host ("[REPORT] reports/" + (Split-Path -Leaf $rep))
Write-Host "[OK] B6W v0_2 concluído."
