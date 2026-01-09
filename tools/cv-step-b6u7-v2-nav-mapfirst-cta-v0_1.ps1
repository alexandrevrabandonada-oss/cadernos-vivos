param()
$ErrorActionPreference = "Stop"

$stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

# ------------------------------------------------------------
# BOOTSTRAP (prefer tools/_bootstrap.ps1; fallback local)
# ------------------------------------------------------------
$boot = Join-Path $repoRoot "tools\_bootstrap.ps1"
if (Test-Path -LiteralPath $boot) {
  . $boot
} else {
  function EnsureDir([string]$p) { if (!(Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
  function BackupFile([string]$abs) {
    $bkDir = Join-Path $repoRoot "tools\_patch_backup"
    EnsureDir $bkDir
    $leaf = (Split-Path -Leaf $abs) -replace "[\\\/:\s]", "_"
    $bk = Join-Path $bkDir ($stamp + "-" + $leaf + ".bak")
    Copy-Item -LiteralPath $abs -Destination $bk -Force
    return $bk
  }
  function WriteUtf8NoBom([string]$abs, [string]$content) {
    [IO.File]::WriteAllText($abs, $content, [Text.UTF8Encoding]::new($false))
  }
}

Write-Host ("== cv-step-b6u7-v2-nav-mapfirst-cta-v0_1 == " + $stamp)
Write-Host ("[DIAG] Repo: " + $repoRoot)

# ------------------------------------------------------------
# Locate V2Nav.tsx (robusto)
# ------------------------------------------------------------
$candidates = Get-ChildItem -LiteralPath (Join-Path $repoRoot "src") -Recurse -File -Filter "V2Nav.tsx" -ErrorAction SilentlyContinue
if (-not $candidates -or $candidates.Count -eq 0) { throw "[STOP] não achei V2Nav.tsx em src/**" }
# Prefer src/components/v2/V2Nav.tsx se existir
$navAbs = ($candidates | Sort-Object FullName | Where-Object { $_.FullName -match "\\src\\components\\v2\\V2Nav\.tsx$" } | Select-Object -First 1).FullName
if (-not $navAbs) { $navAbs = ($candidates | Sort-Object FullName | Select-Object -First 1).FullName }
$navRel = $navAbs.Substring($repoRoot.Length).TrimStart("\","/")

$bk1 = BackupFile $navAbs

# ------------------------------------------------------------
# Rewrite V2Nav.tsx (map-first CTA + tolerante a props)
# ------------------------------------------------------------
$tsx = @"
import Link from "next/link";

type Props = {
  slug: string;
  active?: string;
  current?: string;
  title?: string;
};

type DoorKey =
  | "hub"
  | "mapa"
  | "linha"
  | "linha-do-tempo"
  | "provas"
  | "trilhas"
  | "debate";

type Door = { key: DoorKey; label: string; path: string };

const DOORS: Door[] = [
  { key: "hub", label: "Hub", path: "" },
  { key: "mapa", label: "Mapa", path: "/mapa" },
  { key: "linha", label: "Linha", path: "/linha" },
  { key: "linha-do-tempo", label: "Linha do tempo", path: "/linha-do-tempo" },
  { key: "provas", label: "Provas", path: "/provas" },
  { key: "trilhas", label: "Trilhas", path: "/trilhas" },
  { key: "debate", label: "Debate", path: "/debate" },
];

function normKey(v: string | undefined): DoorKey {
  const x = (v || "").trim();
  if (x === "mapa") return "mapa";
  if (x === "linha") return "linha";
  if (x === "linha-do-tempo" || x === "linha_do_tempo" || x === "timeline") return "linha-do-tempo";
  if (x === "provas") return "provas";
  if (x === "trilhas") return "trilhas";
  if (x === "debate") return "debate";
  return "hub";
}

export default function V2Nav(props: Props) {
  const active = normKey(props.active || props.current);
  const base = "/c/" + props.slug + "/v2";

  const cta =
    active === "mapa"
      ? { label: "Voltar ao Hub", href: base, kind: "hub" as const }
      : { label: "Comece pelo Mapa →", href: base + "/mapa", kind: "mapa" as const };

  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        gap: 12,
        justifyContent: "space-between",
        flexWrap: "wrap",
      }}
    >
      <nav aria-label="Navegação V2">
        <div style={{ display: "flex", gap: 10, alignItems: "center", flexWrap: "wrap" }}>
          {DOORS.map((d) => {
            const href = base + d.path;
            const isActive = active === d.key;
            const isMapa = d.key === "mapa";
            return (
              <Link
                key={d.key}
                href={href}
                aria-current={isActive ? "page" : undefined}
                style={{
                  display: "inline-flex",
                  alignItems: "center",
                  gap: 8,
                  borderRadius: 999,
                  padding: "8px 12px",
                  border: "1px solid rgba(255,255,255,0.16)",
                  background: isActive ? "rgba(255,255,255,0.12)" : "rgba(0,0,0,0.10)",
                  whiteSpace: "nowrap",
                  fontSize: 14,
                  lineHeight: "18px",
                  textDecoration: "none",
                  color: "inherit",
                }}
              >
                <span style={{ fontWeight: isActive ? 800 : 650 }}>{d.label}</span>
                {isMapa && active !== "mapa" ? (
                  <span
                    style={{
                      fontSize: 12,
                      padding: "2px 8px",
                      borderRadius: 999,
                      border: "1px solid rgba(255,255,255,0.22)",
                      background: "rgba(255,255,255,0.08)",
                      opacity: 0.9,
                    }}
                  >
                    comece aqui
                  </span>
                ) : null}
              </Link>
            );
          })}
        </div>
      </nav>

      <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
        <Link
          href={cta.href}
          style={{
            display: "inline-flex",
            alignItems: "center",
            borderRadius: 999,
            padding: "8px 12px",
            border: "1px solid rgba(255,255,255,0.22)",
            background: cta.kind === "mapa" ? "rgba(255,255,255,0.10)" : "rgba(0,0,0,0.12)",
            textDecoration: "none",
            color: "inherit",
            fontSize: 13,
            fontWeight: 750,
            whiteSpace: "nowrap",
          }}
        >
          {cta.label}
        </Link>
      </div>
    </div>
  );
}
"@

WriteUtf8NoBom $navAbs $tsx
Write-Host ("[PATCH] " + $navRel)
Write-Host ("[BK]    tools\_patch_backup\" + (Split-Path -Leaf $bk1))

# ------------------------------------------------------------
# VERIFY
# ------------------------------------------------------------
$npmCmd = (Get-Command npm.cmd -ErrorAction Stop).Path

Write-Host "[RUN] npm run lint"
$lintOut = (& $npmCmd @("run","lint") 2>&1 | Out-String)
$lintExit = $LASTEXITCODE
if ($lintExit -ne 0) { Write-Host $lintOut; throw ("[STOP] lint falhou (exit=" + $lintExit + ")") }

Write-Host "[RUN] npm run build"
$buildOut = (& $npmCmd @("run","build") 2>&1 | Out-String)
$buildExit = $LASTEXITCODE
if ($buildExit -ne 0) { Write-Host $buildOut; throw ("[STOP] build falhou (exit=" + $buildExit + ")") }

# ------------------------------------------------------------
# REPORT
# ------------------------------------------------------------
$repDir = Join-Path $repoRoot "reports"
EnsureDir $repDir
$rep = Join-Path $repDir ($stamp + "-cv-step-b6u7-v2-nav-mapfirst-cta.md")

$body = @(
  ("# CV B6U7 — V2 Nav Map-first CTA — " + $stamp),
  "",
  ("Repo: " + $repoRoot),
  "",
  "## PATCH",
  ("- " + $navRel),
  "",
  "## VERIFY",
  ("- lint exit: " + $lintExit),
  ("- build exit: " + $buildExit),
  "",
  "--- LINT OUTPUT START ---",
  $lintOut.TrimEnd(),
  "--- LINT OUTPUT END ---",
  "",
  "--- BUILD OUTPUT START ---",
  $buildOut.TrimEnd(),
  "--- BUILD OUTPUT END ---"
) -join "`n"

WriteUtf8NoBom $rep $body
Write-Host ("[REPORT] reports\" + (Split-Path -Leaf $rep))
Write-Host "[OK] B6U7 concluído (CTA map-first no topo + props tolerantes)."