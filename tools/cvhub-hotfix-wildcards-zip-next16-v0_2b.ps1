param(
  [string]$ZipPath = "",
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
  throw ("[STOP] Rode este script na raiz do repo (onde tem package.json). Atual: " + $here)
}

function DetectAppRoot([string]$repo) {
  $a = Join-Path $repo "src\app"
  if (TestP $a) { return $a }
  $b = Join-Path $repo "app"
  if (TestP $b) { return $b }
  throw "[STOP] Não achei src\app nem app."
}

function TitleFromFile([string]$f) {
  $t = [IO.Path]::GetFileNameWithoutExtension($f)
  $t = $t -replace "_", " "
  $t = $t -replace "\s{2,}", " "
  return $t.Trim()
}

function TryFindZip([string]$repo, [string]$zipPathArg) {
  if ($zipPathArg -and (TestP $zipPathArg)) { return (Resolve-Path $zipPathArg).Path }
  $parent = Split-Path -Parent $repo

  $hits = @()
  $hits += @(Get-ChildItem -LiteralPath $repo   -Filter "*.zip" -ErrorAction SilentlyContinue)
  $hits += @(Get-ChildItem -LiteralPath $parent -Filter "*.zip" -ErrorAction SilentlyContinue)

  $hits = @($hits | Sort-Object LastWriteTime -Descending)
  if ($hits.Count -gt 0) { return $hits[0].FullName }
  return ""
}

function EnsureFile([string]$p, [string]$content) {
  $parent = Split-Path -Parent $p
  if ($parent) { EnsureDir $parent }
  if (TestP $p) {
    $old = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
    if ($old -eq $content) { WL ("[OK] ok: " + (Split-Path -Leaf $p)); return }
    BackupFile $p
  }
  WriteUtf8NoBom $p $content
  WL ("[OK] wrote: " + (Split-Path -Leaf $p))
}

# -------------------------
# DIAG
# -------------------------
$repo = ResolveRepoHere
$appRoot = DetectAppRoot $repo
$npmExe = ResolveExe "npm.cmd"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] AppRoot: " + $appRoot)
WL ("[DIAG] npm: " + $npmExe)

# -------------------------
# PATCH: garantir rotas Next16 + remover as any + acervo
# -------------------------
$cSlugDir = Join-Path $appRoot "c\[slug]"
$cAulaDir = Join-Path $appRoot "c\[slug]\a\[aula]"
$cPraDir  = Join-Path $appRoot "c\[slug]\pratica"
$cQuizDir = Join-Path $appRoot "c\[slug]\quiz"
$cAceDir  = Join-Path $appRoot "c\[slug]\acervo"

EnsureDir $cSlugDir
EnsureDir $cAulaDir
EnsureDir $cPraDir
EnsureDir $cQuizDir
EnsureDir $cAceDir

# components nav: adiciona "Acervo" se ainda não existir (regrava inteiro pra ficar consistente)
$compDir = Join-Path $repo "src\components"
if (-not (TestP $compDir)) { $compDir = Join-Path $repo "components" } # fallback raro
EnsureDir $compDir

$cadernoHeaderPath = Join-Path $compDir "CadernoHeader.tsx"
$cadernoHeader = @(
'import Link from "next/link";',
'',
'export function CadernoHeader({ title, subtitle, ethos }: { title: string; subtitle?: string; ethos?: string }) {',
'  return (',
'    <div className="card p-5 flex items-start justify-between gap-4">',
'      <div className="min-w-0">',
'        <div className="text-xs muted">VR Abandonada • Cadernos Vivos</div>',
'        <h1 className="text-2xl font-semibold leading-tight mt-1">{title}</h1>',
'        {subtitle ? <p className="muted mt-1">{subtitle}</p> : null}',
'        {ethos ? <p className="text-sm mt-3 muted">{ethos}</p> : null}',
'      </div>',
'      <div className="enso shrink-0" aria-hidden="true" />',
'    </div>',
'  );',
'}',
'',
'export function NavPills({ slug }: { slug: string }) {',
'  const items = [',
'    { href: `/c/${slug}`, label: "Panorama" },',
'    { href: `/c/${slug}/a/1`, label: "Aulas" },',
'    { href: `/c/${slug}/pratica`, label: "Prática" },',
'    { href: `/c/${slug}/quiz`, label: "Quiz" },',
'    { href: `/c/${slug}/acervo`, label: "Acervo" },',
'  ];',
'  return (',
'    <div className="flex flex-wrap gap-2 mt-4">',
'      {items.map(it => (',
'        <Link key={it.href} href={it.href} className="card px-3 py-2 text-sm hover:bg-white/10 transition">',
'          <span className="accent">{it.label}</span>',
'        </Link>',
'      ))}',
'    </div>',
'  );',
'}'
) -join "`n"
EnsureFile $cadernoHeaderPath $cadernoHeader

# lib/cadernos.ts: garantir acervo no retorno
$libDir = Join-Path $repo "src\lib"
if (-not (TestP $libDir)) { $libDir = Join-Path $repo "lib" }
EnsureDir $libDir

$cadernosPath = Join-Path $libDir "cadernos.ts"
if (-not (TestP $cadernosPath)) {
  throw "[STOP] Não achei src/lib/cadernos.ts (ele deveria existir)."
}

BackupFile $cadernosPath
$rawC = [System.IO.File]::ReadAllText($cadernosPath, [System.Text.Encoding]::UTF8)

# patch simples: inserir tipos AcervoItem e leitura acervo.json se ainda não existir
if ($rawC -notmatch "AcervoItem") {
  $rawC = $rawC -replace "export type QuizQ = \{ q: string; choices: string\[\]; answer: number \};",
@"
export type QuizQ = { q: string; choices: string[]; answer: number };
export type AcervoItem = { file: string; title: string; kind: string; tags?: string[] };
"@
}

if ($rawC -notmatch "acervo\.json") {
  $rawC = $rawC -replace "const praticaQuiz = path\.join\(base, slug, ""pratica"", ""quiz\.json""\);",
@"
const praticaQuiz = path.join(base, slug, "pratica", "quiz.json");
const acervoPath = path.join(base, slug, "acervo.json");
"@
  $rawC = $rawC -replace "let quiz: QuizQ\[\] = \[\];",
@"
let quiz: QuizQ[] = [];
let acervo: AcervoItem[] = [];
"@
  $rawC = $rawC -replace "try \{ quiz = JSON\.parse\(await fs\.readFile\(praticaQuiz, ""utf8""\)\); \} catch \{\}",
@"
try { quiz = JSON.parse(await fs.readFile(praticaQuiz, "utf8")); } catch {}
try { acervo = JSON.parse(await fs.readFile(acervoPath, "utf8")); } catch {}
"@
  $rawC = $rawC -replace "return \{ meta, panorama, referencias, aulas, flashcards, quiz \};",
"return { meta, panorama, referencias, aulas, flashcards, quiz, acervo };"
}

WriteUtf8NoBom $cadernosPath $rawC
WL "[OK] patched: cadernos.ts (acervo)"

# Pages (Next 16 params Promise + estilo sem any)
$pageCaderno = @(
'import type { CSSProperties } from "react";',
'import { getCaderno } from "@/lib/cadernos";',
'import Markdown from "@/components/Markdown";',
'import { CadernoHeader, NavPills } from "@/components/CadernoHeader";',
'',
'type AccentStyle = CSSProperties & { ["--accent"]?: string };',
'',
'export default async function Page({ params }: { params: Promise<{ slug: string }> }) {',
'  const { slug } = await params;',
'  const data = await getCaderno(slug);',
'  const s: AccentStyle = { ["--accent"]: data.meta.accent };',
'  return (',
'    <main className="space-y-5" style={s}>',
'      <CadernoHeader title={data.meta.title} subtitle={data.meta.subtitle} ethos={data.meta.ethos} />',
'      <NavPills slug={data.meta.slug} />',
'      <div className="card p-5">',
'        <h2 className="text-xl font-semibold">Panorama</h2>',
'        <div className="mt-4"><Markdown markdown={data.panorama} /></div>',
'      </div>',
'      {data.referencias ? (',
'        <div className="card p-5">',
'          <h3 className="text-lg font-semibold">Referências do pacote</h3>',
'          <div className="mt-4"><Markdown markdown={data.referencias} /></div>',
'        </div>',
'      ) : null}',
'    </main>',
'  );',
'}'
) -join "`n"
EnsureFile (Join-Path $cSlugDir "page.tsx") $pageCaderno

$pageAula = @(
'import type { CSSProperties } from "react";',
'import { getCaderno, getAula } from "@/lib/cadernos";',
'import Markdown from "@/components/Markdown";',
'import { CadernoHeader, NavPills } from "@/components/CadernoHeader";',
'import Link from "next/link";',
'',
'type AccentStyle = CSSProperties & { ["--accent"]?: string };',
'',
'export default async function Page({ params }: { params: Promise<{ slug: string; aula: string }> }) {',
'  const { slug, aula } = await params;',
'  const data = await getCaderno(slug);',
'  const total = data.aulas.length;',
'  const num = Number(aula);',
'  const aulaData = await getAula(slug, "aula-" + String(num));',
'  const prev = num > 1 ? ("/c/" + slug + "/a/" + String(num - 1)) : null;',
'  const next = num < total ? ("/c/" + slug + "/a/" + String(num + 1)) : null;',
'  const s: AccentStyle = { ["--accent"]: data.meta.accent };',
'',
'  return (',
'    <main className="space-y-5" style={s}>',
'      <CadernoHeader title={data.meta.title} subtitle={data.meta.subtitle} ethos={data.meta.ethos} />',
'      <NavPills slug={data.meta.slug} />',
'      <div className="card p-5">',
'        <div className="text-xs muted">Aula {String(num)} / {String(total)}</div>',
'        <h2 className="text-xl font-semibold mt-1">Aula {String(num)}</h2>',
'        <div className="mt-4"><Markdown markdown={aulaData.markdown} /></div>',
'        <div className="mt-6 flex gap-2">',
'          {prev ? <Link className="card px-3 py-2 hover:bg-white/10 transition" href={prev}>Anterior</Link> : null}',
'          {next ? <Link className="card px-3 py-2 hover:bg-white/10 transition" href={next}>Próxima</Link> : null}',
'        </div>',
'      </div>',
'    </main>',
'  );',
'}'
) -join "`n"
EnsureFile (Join-Path $cAulaDir "page.tsx") $pageAula

$pagePratica = @(
'import type { CSSProperties } from "react";',
'import { getCaderno } from "@/lib/cadernos";',
'import { CadernoHeader, NavPills } from "@/components/CadernoHeader";',
'import Flashcards from "@/components/Flashcards";',
'',
'type AccentStyle = CSSProperties & { ["--accent"]?: string };',
'',
'export default async function Page({ params }: { params: Promise<{ slug: string }> }) {',
'  const { slug } = await params;',
'  const data = await getCaderno(slug);',
'  const s: AccentStyle = { ["--accent"]: data.meta.accent };',
'  return (',
'    <main className="space-y-5" style={s}>',
'      <CadernoHeader title={data.meta.title} subtitle={data.meta.subtitle} ethos={data.meta.ethos} />',
'      <NavPills slug={data.meta.slug} />',
'      <div className="card p-5">',
'        <h2 className="text-xl font-semibold">Prática</h2>',
'        <p className="muted mt-2">Flashcards pra estudar sem ansiedade: pergunta boa, resposta curta, repetição leve.</p>',
'      </div>',
'      <Flashcards cards={data.flashcards} />',
'    </main>',
'  );',
'}'
) -join "`n"
EnsureFile (Join-Path $cPraDir "page.tsx") $pagePratica

$pageQuiz = @(
'import type { CSSProperties } from "react";',
'import { getCaderno } from "@/lib/cadernos";',
'import { CadernoHeader, NavPills } from "@/components/CadernoHeader";',
'import Quiz from "@/components/Quiz";',
'',
'type AccentStyle = CSSProperties & { ["--accent"]?: string };',
'',
'export default async function Page({ params }: { params: Promise<{ slug: string }> }) {',
'  const { slug } = await params;',
'  const data = await getCaderno(slug);',
'  const s: AccentStyle = { ["--accent"]: data.meta.accent };',
'  return (',
'    <main className="space-y-5" style={s}>',
'      <CadernoHeader title={data.meta.title} subtitle={data.meta.subtitle} ethos={data.meta.ethos} />',
'      <NavPills slug={data.meta.slug} />',
'      <div className="card p-5">',
'        <h2 className="text-xl font-semibold">Quiz</h2>',
'        <p className="muted mt-2">Sem tribunal: o quiz é só ferramenta de revisão.</p>',
'      </div>',
'      <Quiz qs={data.quiz} />',
'    </main>',
'  );',
'}'
) -join "`n"
EnsureFile (Join-Path $cQuizDir "page.tsx") $pageQuiz

$pageAcervo = @(
'import type { CSSProperties } from "react";',
'import Link from "next/link";',
'import { getCaderno } from "@/lib/cadernos";',
'import { CadernoHeader, NavPills } from "@/components/CadernoHeader";',
'',
'type AccentStyle = CSSProperties & { ["--accent"]?: string };',
'',
'export default async function Page({ params }: { params: Promise<{ slug: string }> }) {',
'  const { slug } = await params;',
'  const data = await getCaderno(slug);',
'  const s: AccentStyle = { ["--accent"]: data.meta.accent };',
'  const base = "/cadernos/" + slug + "/acervo/";',
'',
'  return (',
'    <main className="space-y-5" style={s}>',
'      <CadernoHeader title={data.meta.title} subtitle={data.meta.subtitle} ethos={data.meta.ethos} />',
'      <NavPills slug={data.meta.slug} />',
'      <div className="card p-5">',
'        <h2 className="text-xl font-semibold">Acervo</h2>',
'        <p className="muted mt-2">Materiais brutos do pacote (PDF/DOC). Isso é base de estudo, não tribunal.</p>',
'      </div>',
'      <div className="card p-5">',
'        <div className="grid gap-3">',
'          {(data.acervo || []).map((it, idx) => (',
'            <div key={idx} className="card p-4">',
'              <div className="text-xs muted">{it.kind}{it.tags?.length ? " • " + it.tags.join(", ") : ""}</div>',
'              <div className="font-semibold mt-1">{it.title}</div>',
'              {it.file ? (',
'                <Link className="inline-block mt-3 card px-3 py-2 hover:bg-white/10 transition" href={base + it.file} target="_blank">',
'                  <span className="accent">Abrir arquivo</span>',
'                </Link>',
'              ) : <div className="muted mt-3">Sem arquivo importado ainda.</div>}',
'            </div>',
'          ))}',
'        </div>',
'      </div>',
'    </main>',
'  );',
'}'
) -join "`n"
EnsureFile (Join-Path $cAceDir "page.tsx") $pageAcervo

# -------------------------
# ACERVO: importar ZIP opcional + gerar acervo.json
# -------------------------
$slug = "poluicao-vr"
$contentBase = Join-Path $repo ("content\cadernos\" + $slug)
EnsureDir $contentBase

$publicAcervo = Join-Path $repo ("public\cadernos\" + $slug + "\acervo")
EnsureDir $publicAcervo

$acervoJsonPath = Join-Path $contentBase "acervo.json"
$imported = @()

$zip = TryFindZip $repo $ZipPath
if ($zip) {
  WL ("[STEP] Import: ZIP encontrado: " + $zip)
  $tmp = Join-Path $repo "tools\_tmp_import"
  if (TestP $tmp) { Remove-Item -Recurse -Force $tmp }
  EnsureDir $tmp
  Expand-Archive -LiteralPath $zip -DestinationPath $tmp -Force

  $files = Get-ChildItem -LiteralPath $tmp -Recurse -File | Where-Object { $_.Extension -match "\.(pdf|doc|docx)$" }
  foreach ($f in $files) {
    $dest = Join-Path $publicAcervo $f.Name
    Copy-Item -LiteralPath $f.FullName -Destination $dest -Force
    $k = $f.Extension.TrimStart(".").ToLower()
    $imported += [PSCustomObject]@{
      file  = $f.Name
      title = (TitleFromFile $f.Name)
      kind  = $k
      tags  = @("pacote-inicial")
    }
  }
  WL ("[OK] Importou " + $imported.Count + " arquivos para public/cadernos/" + $slug + "/acervo")
} else {
  WL "[WARN] ZIP não encontrado automaticamente (ok)."
  WL "       Se quiser, rode com -ZipPath C:\caminho\seu.zip"
}

if ($imported.Count -eq 0) {
  $imported = @(
    [PSCustomObject]@{ file=""; title="Sem import ainda (adicione um ZIP para listar PDFs/DOCs)"; kind="info"; tags=@("setup") }
  )
}

BackupFile $acervoJsonPath
$acervoJson = ($imported | ConvertTo-Json -Depth 6)
WriteUtf8NoBom $acervoJsonPath $acervoJson
WL "[OK] acervo.json atualizado."

# -------------------------
# REPORT
# -------------------------
$repDir = Join-Path $repo "reports"
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repDir "cv-hotfix-wildcards-zip-next16-v0_2b.md"
$report = @(
  "# CV Hotfix v0.2b — " + $now,
  "",
  "Correções:",
  "- PowerShell agora usa -LiteralPath em caminhos com [slug]/[aula] (sem wildcard)",
  "- TryFindZip agora força array (@(...)) e não quebra com 1 item",
  "- Rotas Next 16 com params Promise + await params",
  "- Removeu as any (lint)",
  "- Garante /c/[slug]/acervo e acervo.json",
  "",
  "Testar:",
  "- /c/poluicao-vr",
  "- /c/poluicao-vr/acervo"
) -join "`n"
WriteUtf8NoBom $reportPath $report
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
WL "[OK] v0.2b aplicado."
WL "[NEXT] npm run dev e abra /c/poluicao-vr e /c/poluicao-vr/acervo"