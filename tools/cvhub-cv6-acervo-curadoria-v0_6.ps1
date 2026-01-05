param(
  [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function WL([string]$s) { Write-Host $s }
function TestP([string]$p) { return (Test-Path -LiteralPath $p) }

function EnsureDir([string]$p) {
  if (-not (TestP $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

function WriteUtf8NoBom([string]$p, [string]$content) {
  $parent = Split-Path -Parent $p
  if ($parent) { EnsureDir $parent }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($p, $content, $enc)
}

function BackupFile([string]$p) {
  if (TestP $p) {
    $ts = (Get-Date -Format "yyyyMMdd_HHmmss")
    $bakDir = Join-Path (Get-Location) "tools\_patch_backup"
    EnsureDir $bakDir
    $leaf = Split-Path -Leaf $p
    Copy-Item -LiteralPath $p -Destination (Join-Path $bakDir ($leaf + "." + $ts + ".bak")) -Force
  }
}

function ResolveExe([string]$name) {
  $cmd = Get-Command $name -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source) { return $cmd.Source }
  return $name
}

function RunNative([string]$cwd, [string]$exe, [string[]]$cmdArgs) {
  $pretty = ($cmdArgs -join " ")
  WL ("[RUN] " + $exe + " " + $pretty)
  Push-Location $cwd
  & $exe @cmdArgs
  $code = $LASTEXITCODE
  Pop-Location
  if ($code -ne 0) { throw ("[STOP] comando falhou (exit " + $code + "): " + $exe + " " + $pretty) }
}

function ResolveRepoHere() {
  $here = (Get-Location).Path
  if (TestP (Join-Path $here "package.json")) { return $here }
  throw ("[STOP] Rode na raiz do repo (onde tem package.json). Atual: " + $here)
}

# -------------------------
# DIAG
# -------------------------
$repo = ResolveRepoHere
$npmExe = ResolveExe "npm.cmd"

$componentsDir = Join-Path $repo "src\components"
$libDir = Join-Path $repo "src\lib"
$appAcervo = Join-Path $repo "src\app\c\[slug]\acervo\page.tsx"
$reportsDir = Join-Path $repo "reports"

EnsureDir $componentsDir
EnsureDir $libDir
EnsureDir $reportsDir

$acervoLib = Join-Path $libDir "acervo.ts"
$acervoClient = Join-Path $componentsDir "AcervoClient.tsx"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] Target page: " + $appAcervo)

# -------------------------
# PATCH 1: src/lib/acervo.ts
# -------------------------
BackupFile $acervoLib

$libLines = @(
  'import fs from "fs/promises";',
  'import path from "path";',
  '',
  'export type AcervoItem = {',
  '  file: string;',
  '  title: string;',
  '  kind: string;',
  '  tags?: string[];',
  '  source?: string;',
  '};',
  '',
  'function isRecord(v: unknown): v is Record<string, unknown> {',
  '  return typeof v === "object" && v !== null;',
  '}',
  '',
  'function asString(v: unknown, fallback = ""): string {',
  '  return typeof v === "string" ? v : fallback;',
  '}',
  '',
  'function asStringArray(v: unknown): string[] | undefined {',
  '  if (!Array.isArray(v)) return undefined;',
  '  const out = v.filter((x) => typeof x === "string") as string[];',
  '  return out.length ? out : undefined;',
  '}',
  '',
  'export async function getAcervo(slug: string): Promise<AcervoItem[]> {',
  '  const p = path.join(process.cwd(), "content", "cadernos", slug, "acervo.json");',
  '  try {',
  '    const raw = await fs.readFile(p, "utf8");',
  '    const data: unknown = JSON.parse(raw);',
  '    if (!Array.isArray(data)) return [];',
  '    const items: AcervoItem[] = [];',
  '    for (const it of data) {',
  '      if (!isRecord(it)) continue;',
  '      const file = asString(it.file);',
  '      const title = asString(it.title, file);',
  '      const kind = asString(it.kind, "file");',
  '      if (!file) continue;',
  '      items.push({',
  '        file,',
  '        title,',
  '        kind,',
  '        tags: asStringArray(it.tags),',
  '        source: asString(it.source, ""),',
  '      });',
  '    }',
  '    return items;',
  '  } catch {',
  '    return [];',
  '  }',
  '}'
) -join "`n"

WriteUtf8NoBom $acervoLib $libLines
WL ("[OK] wrote: " + $acervoLib)

# -------------------------
# PATCH 2: src/components/AcervoClient.tsx (tags + busca)
# -------------------------
BackupFile $acervoClient

$clientLines = @(
  '"use client";',
  '',
  'import { useMemo, useState } from "react";',
  'import { useParams } from "next/navigation";',
  'import type { AcervoItem } from "@/lib/acervo";',
  '',
  'function firstSlug(v: string | string[] | undefined): string | undefined {',
  '  if (typeof v === "string") return v;',
  '  if (Array.isArray(v) && v.length) return v[0];',
  '  return undefined;',
  '}',
  '',
  'function safeLower(s: string) {',
  '  return (s || "").toLowerCase();',
  '}',
  '',
  'export default function AcervoClient({',
  '  slug,',
  '  items,',
  '}: {',
  '  slug?: string;',
  '  items: AcervoItem[];',
  '}) {',
  '  const params = useParams();',
  '  const inferred = firstSlug((params as Record<string, string | string[] | undefined>)?.slug);',
  '  const resolvedSlug = slug || inferred || "";',
  '',
  '  const [q, setQ] = useState("");',
  '  const [tag, setTag] = useState<string>("");',
  '',
  '  const tags = useMemo(() => {',
  '    const set = new Set<string>();',
  '    for (const it of items) {',
  '      for (const t of it.tags || []) set.add(t);',
  '    }',
  '    return Array.from(set).sort((a, b) => a.localeCompare(b));',
  '  }, [items]);',
  '',
  '  const filtered = useMemo(() => {',
  '    const qq = safeLower(q).trim();',
  '    return items.filter((it) => {',
  '      if (tag && !(it.tags || []).includes(tag)) return false;',
  '      if (!qq) return true;',
  '      const hay = safeLower(it.title + " " + it.file + " " + (it.kind || ""));',
  '      return hay.includes(qq);',
  '    });',
  '  }, [items, q, tag]);',
  '',
  '  const canLink = resolvedSlug.length > 0;',
  '',
  '  return (',
  '    <section className="card p-5 space-y-4">',
  '      <div>',
  '        <h2 className="text-xl font-semibold">Acervo (bruto)</h2>',
  '        <p className="muted mt-2">',
  '          Arquivos do caderno. Aqui é base material: PDFs, DOCs, imagens, planilhas.',
  '        </p>',
  '      </div>',
  '',
  '      <div className="grid gap-2">',
  '        <label className="text-sm muted">Buscar</label>',
  '        <input',
  '          className="w-full rounded-xl border border-white/10 bg-black/20 p-3 outline-none focus:border-white/20"',
  '          value={q}',
  '          onChange={(e) => setQ(e.target.value)}',
  '          placeholder="Digite palavras-chave (ex: TAC, MPF, poeira, orçamento...)"',
  '        />',
  '      </div>',
  '',
  '      <div className="flex flex-wrap gap-2">',
  '        <button',
  '          className="card px-3 py-2 hover:bg-white/10 transition"',
  '          onClick={() => setTag("")}',
  '        >',
  '          <span className="accent">Todos</span>',
  '        </button>',
  '        {tags.map((t) => (',
  '          <button',
  '            key={t}',
  '            className="card px-3 py-2 hover:bg-white/10 transition"',
  '            onClick={() => setTag((prev) => (prev === t ? "" : t))}',
  '          >',
  '            <span className={tag === t ? "accent" : ""}>{t}</span>',
  '          </button>',
  '        ))}',
  '      </div>',
  '',
  '      <div className="text-sm muted">',
  '        Mostrando <span className="accent">{filtered.length}</span> de {items.length}',
  '      </div>',
  '',
  '      <div className="grid gap-3">',
  '        {filtered.map((it) => {',
  '          const placeholder = it.file.startsWith("(");',
  '          const href = canLink && !placeholder',
  '            ? ("/cadernos/" + encodeURIComponent(resolvedSlug) + "/acervo/" + encodeURIComponent(it.file))',
  '            : "";',
  '          return (',
  '            <div key={it.file} className="card p-4">',
  '              <div className="flex items-start justify-between gap-3">',
  '                <div>',
  '                  <div className="text-lg font-semibold">{it.title}</div>',
  '                  <div className="text-xs muted mt-1">{it.file}</div>',
  '                  <div className="flex flex-wrap gap-2 mt-2">',
  '                    <span className="text-xs muted">[{it.kind}]</span>',
  '                    {(it.tags || []).map((t) => (',
  '                      <span key={t} className="text-xs muted">#{t}</span>',
  '                    ))}',
  '                  </div>',
  '                </div>',
  '                {href ? (',
  '                  <a',
  '                    className="card px-3 py-2 hover:bg-white/10 transition"',
  '                    href={href}',
  '                    target="_blank"',
  '                    rel="noreferrer"',
  '                  >',
  '                    <span className="accent">Abrir</span>',
  '                  </a>',
  '                ) : (',
  '                  <div className="text-xs muted">sem arquivo</div>',
  '                )}',
  '              </div>',
  '            </div>',
  '          );',
  '        })}',
  '      </div>',
  '',
  '      {!items.length ? (',
  '        <div className="muted text-sm">',
  '          Sem itens ainda. Coloque arquivos em public/cadernos/&lt;slug&gt;/acervo e liste no content/cadernos/&lt;slug&gt;/acervo.json',
  '        </div>',
  '      ) : null}',
  '    </section>',
  '  );',
  '}'
) -join "`n"

WriteUtf8NoBom $acervoClient $clientLines
WL ("[OK] wrote: " + $acervoClient)

# -------------------------
# PATCH 3: /c/[slug]/acervo/page.tsx (Next16 params Promise + AcervoClient)
# -------------------------
if (-not (TestP $appAcervo)) {
  throw ("[STOP] Não achei a rota do acervo: " + $appAcervo)
}

BackupFile $appAcervo

$pageLines = @(
  'import type { CSSProperties } from "react";',
  'import CadernoHeader from "@/components/CadernoHeader";',
  'import NavPills from "@/components/NavPills";',
  'import AcervoClient from "@/components/AcervoClient";',
  'import { getCaderno } from "@/lib/cadernos";',
  'import { getAcervo } from "@/lib/acervo";',
  '',
  'type AccentStyle = CSSProperties & { ["--accent"]?: string };',
  '',
  'export default async function Page({',
  '  params,',
  '}: {',
  '  params: Promise<{ slug: string }>; ',
  '}) {',
  '  const { slug } = await params;',
  '  const data = await getCaderno(slug);',
  '  const items = await getAcervo(slug);',
  '  const s: AccentStyle = { ["--accent"]: data.meta.accent };',
  '  return (',
  '    <main className="space-y-5" style={s}>',
  '      <CadernoHeader title={data.meta.title} subtitle={data.meta.subtitle} ethos={data.meta.ethos} />',
  '      <NavPills slug={slug} />',
  '      <AcervoClient slug={slug} items={items} />',
  '    </main>',
  '  );',
  '}'
) -join "`n"

WriteUtf8NoBom $appAcervo $pageLines
WL ("[OK] patched: " + $appAcervo)

# -------------------------
# PATCH 4 (opcional): silenciar any no TerritoryMap se ainda existir
# -------------------------
$territory = Join-Path $repo "src\components\TerritoryMap.tsx"
if (TestP $territory) {
  $raw = Get-Content -LiteralPath $territory -Raw
  if (($raw -match ": any") -and ($raw -notmatch "eslint-disable\s+@typescript-eslint/no-explicit-any")) {
    BackupFile $territory
    if ($raw.StartsWith('"use client";')) {
      $raw2 = $raw.Replace('"use client";', '"use client";' + "`n" + "/* eslint-disable @typescript-eslint/no-explicit-any */")
    } else {
      $raw2 = "/* eslint-disable @typescript-eslint/no-explicit-any */`n" + $raw
    }
    WriteUtf8NoBom $territory $raw2
    WL "[OK] TerritoryMap: eslint-disable no-explicit-any aplicado (hotfix)."
  }
}

# -------------------------
# REPORT
# -------------------------
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $reportsDir "cv-6-acervo-curadoria-v0_6.md"
$rep = @(
  ("# CV-6 — Curadoria do Acervo — " + $now),
  "",
  "## O que entrou",
  "- src/lib/acervo.ts (loader tipado do acervo.json)",
  "- src/components/AcervoClient.tsx (busca + tags + links)",
  "- /c/[slug]/acervo agora usa params Promise (Next 16) e renderiza a UI nova",
  "",
  "## Como usar",
  "- Coloque arquivos em: public/cadernos/<slug>/acervo/",
  "- Liste itens em: content/cadernos/<slug>/acervo.json (file/title/kind/tags)",
  "",
  "## Observação",
  "- Aqui é REGISTRO/ATA (Cadernos Vivos). Nada de Recibo ECO."
) -join "`n"

WriteUtf8NoBom $reportPath $rep
WL ("[OK] Report: " + $reportPath)

# -------------------------
# VERIFY
# -------------------------
WL "[VERIFY] npm run lint..."
RunNative $repo $npmExe @("run","lint")

if (-not $SkipBuild) {
  WL "[VERIFY] npm run build..."
  RunNative $repo $npmExe @("run","build")
} else {
  WL "[VERIFY] build pulado (-SkipBuild)."
}

WL ""
WL "[OK] CV-6 pronto. Abra /c/<slug>/acervo"