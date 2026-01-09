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

Write-Host ("== cv-step-b6u6-v2-quicknav-corridor-v0_2 == " + $stamp)
Write-Host ("[DIAG] Repo: " + $repoRoot)

# ------------------------------------------------------------
# PATCH: rewrite V2QuickNav.tsx (corredor de portas)
# ------------------------------------------------------------
$quickRel = "src\components\v2\V2QuickNav.tsx"
$quickAbs = Join-Path $repoRoot $quickRel
if (!(Test-Path -LiteralPath $quickAbs)) { throw "[STOP] não achei src/components/v2/V2QuickNav.tsx" }
$bk1 = BackupFile $quickAbs

$tsx = @"
"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import React from "react";

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

function extractSlug(pathname: string): string | null {
  const parts = pathname.split("/").filter(Boolean);
  const i = parts.indexOf("c");
  if (i < 0) return null;
  if (i + 1 >= parts.length) return null;
  const slug = parts[i + 1] || "";
  return slug.trim().length ? slug : null;
}

function currentDoor(pathname: string): DoorKey {
  const p = pathname || "";
  if (p.includes("/v2/mapa")) return "mapa";
  if (p.includes("/v2/linha-do-tempo")) return "linha-do-tempo";
  if (p.includes("/v2/linha")) return "linha";
  if (p.includes("/v2/provas")) return "provas";
  if (p.includes("/v2/trilhas/") || p.endsWith("/v2/trilhas")) return "trilhas";
  if (p.includes("/v2/debate")) return "debate";
  return "hub";
}

export default function V2QuickNav() {
  const pathname = usePathname() || "";
  const slug = extractSlug(pathname);
  if (!slug) return null;

  const base = "/c/" + slug + "/v2";
  const active = currentDoor(pathname);

  return (
    <nav aria-label="Portas rápidas" data-cv2="quicknav">
      <div
        style={{
          display: "flex",
          gap: 8,
          alignItems: "center",
          overflowX: "auto",
          padding: "10px 12px",
          WebkitOverflowScrolling: "touch",
        }}
      >
        {DOORS.map((d, idx) => {
          const href = base + d.path;
          const isActive = active === d.key;
          return (
            <React.Fragment key={d.key}>
              <Link
                href={href}
                data-active={isActive ? "1" : "0"}
                aria-current={isActive ? "page" : undefined}
                style={{
                  display: "inline-flex",
                  alignItems: "center",
                  borderRadius: 999,
                  padding: "6px 10px",
                  border: "1px solid rgba(255,255,255,0.16)",
                  background: isActive ? "rgba(255,255,255,0.10)" : "rgba(0,0,0,0.10)",
                  whiteSpace: "nowrap",
                  fontSize: 13,
                  lineHeight: "18px",
                  textDecoration: "none",
                  color: "inherit",
                }}
              >
                {d.label}
              </Link>
              {idx < DOORS.length - 1 ? (
                <span aria-hidden="true" style={{ opacity: 0.35, padding: "0 2px" }}>
                  ›
                </span>
              ) : null}
            </React.Fragment>
          );
        })}
      </div>
    </nav>
  );
}
"@

WriteUtf8NoBom $quickAbs $tsx
Write-Host ("[PATCH] " + $quickRel)
Write-Host ("[BK]    tools\_patch_backup\" + (Split-Path -Leaf $bk1))

# ------------------------------------------------------------
# PATCH: globals.css (chips ativos + esconder scrollbar)
# ------------------------------------------------------------
$globalsRel = "src\app\globals.css"
$globalsAbs = Join-Path $repoRoot $globalsRel
if (!(Test-Path -LiteralPath $globalsAbs)) { throw "[STOP] não achei src/app/globals.css" }
$g = Get-Content -LiteralPath $globalsAbs -Raw
if ($null -eq $g) { throw "[STOP] globals.css veio null (Get-Content falhou)" }

if ($g -notmatch "CV2 QUICKNAV CORRIDOR") {
  $bk2 = BackupFile $globalsAbs

  $css = @(
    "",
    "",
    "/* ===== CV2 QUICKNAV CORRIDOR (Concreto Zen) ===== */",
    "/* CV2 QUICKNAV CORRIDOR */",
    "",
    "[data-cv2=""quicknav""] > div {",
    "  scrollbar-width: none;",
    "}",
    "[data-cv2=""quicknav""] > div::-webkit-scrollbar {",
    "  display: none;",
    "}",
    "[data-cv2=""quicknav""] a[data-active=""1""] {",
    "  background: rgba(255,255,255,0.14) !important;",
    "  border-color: rgba(255,255,255,0.34) !important;",
    "  color: rgba(255,255,255,0.95) !important;",
    "}",
    "[data-cv2=""quicknav""] a[data-active=""0""] {",
    "  color: rgba(255,255,255,0.74) !important;",
    "}",
    "",
    "/* ===== /CV2 QUICKNAV CORRIDOR ===== */",
    ""
  ) -join "`n"

  WriteUtf8NoBom $globalsAbs ($g.TrimEnd() + $css)
  Write-Host ("[PATCH] " + $globalsRel)
  Write-Host ("[BK]    tools\_patch_backup\" + (Split-Path -Leaf $bk2))
} else {
  Write-Host "[SKIP] globals.css já tinha CV2 QUICKNAV CORRIDOR"
}

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
$rep = Join-Path $repDir ($stamp + "-cv-step-b6u6-v2-quicknav-corridor.md")

$body = @(
  ("# CV B6U6 — V2 QuickNav Corredor de Portas — " + $stamp),
  "",
  ("Repo: " + $repoRoot),
  "",
  "## PATCH",
  ("- " + $quickRel),
  ("- " + $globalsRel),
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
Write-Host "[OK] B6U6 concluído (QuickNav corredor + porta ativa destacada)."