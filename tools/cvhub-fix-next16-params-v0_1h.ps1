param(
  [string]$ProjectName = "cadernos-vivos"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function WriteLine([string]$s) { Write-Host $s }
function EnsureDir([string]$p) { if (-not (Test-Path $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }

function WriteUtf8NoBom([string]$p, [string]$content) {
  EnsureDir (Split-Path -Parent $p)
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($p, $content, $enc)
}

function BackupFile([string]$p) {
  if (Test-Path $p) {
    $ts = (Get-Date -Format "yyyyMMdd_HHmmss")
    $bakDir = Join-Path (Get-Location) "tools\_patch_backup"
    EnsureDir $bakDir
    $name = [IO.Path]::GetFileName($p)
    Copy-Item -Force $p (Join-Path $bakDir ($name + "." + $ts + ".bak"))
  }
}

function ResolveExe([string]$name) {
  $cmd = Get-Command $name -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source) { return $cmd.Source }
  return $name
}

function RunNative([string]$cwd, [string]$exe, [string[]]$cmdArgs) {
  $pretty = ($cmdArgs -join " ")
  WriteLine ("[RUN] " + $exe + " " + $pretty)
  Push-Location $cwd
  & $exe @cmdArgs
  $code = $LASTEXITCODE
  Pop-Location
  if ($code -ne 0) { throw ("[STOP] comando falhou (exit " + $code + "): " + $exe + " " + $pretty) }
}

$base = (Get-Location).Path
$repo = Join-Path $base $ProjectName

WriteLine ("[DIAG] Base: " + $base)
WriteLine ("[DIAG] Repo: " + $repo)

if (-not (Test-Path $repo)) { throw ("[STOP] Repo não existe: " + $repo) }

$npmExe = ResolveExe "npm.cmd"
WriteLine ("[DIAG] npm: " + $npmExe)

# 1) /c/[slug]/page.tsx  (params Promise)
$pCaderno = Join-Path $repo "src\app\c\[slug]\page.tsx"
BackupFile $pCaderno
$cadernoPage = @(
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
  '}',
  ''
) -join "`n"
WriteUtf8NoBom $pCaderno $cadernoPage
WriteLine "[OK] Patch: /c/[slug]/page.tsx (await params)."

# 2) /c/[slug]/a/[aula]/page.tsx  (params Promise)
$pAula = Join-Path $repo "src\app\c\[slug]\a\[aula]\page.tsx"
BackupFile $pAula
$aulaPage = @(
  'import type { CSSProperties } from "react";',
  'import { getCaderno, getAula } from "@/lib/cadernos";',
  'import Markdown from "@/components/Markdown";',
  'import { CadernoHeader, NavPills } from "@/components/CadernoHeader";',
  'import Link from "next/link";',
  '',
  'type AccentStyle = CSSProperties & { ["--accent"]?: string };',
  '',
  'export default async function Page({ params }: { params: Promise<{ slug: string; aula: string }> }) {',
  '  const { slug, aula: n } = await params;',
  '  const data = await getCaderno(slug);',
  '  const s: AccentStyle = { ["--accent"]: data.meta.accent };',
  '  const aula = await getAula(slug, "aula-" + n);',
  '  const total = data.aulas.length;',
  '  const num = Number(n);',
  '  const prev = num > 1 ? ("/c/" + slug + "/a/" + (num - 1)) : null;',
  '  const next = num < total ? ("/c/" + slug + "/a/" + (num + 1)) : null;',
  '  return (',
  '    <main className="space-y-5" style={s}>',
  '      <CadernoHeader title={data.meta.title} subtitle={data.meta.subtitle} ethos={data.meta.ethos} />',
  '      <NavPills slug={data.meta.slug} />',
  '      <div className="card p-5">',
  '        <div className="text-xs muted">Aula {n} / {total}</div>',
  '        <h2 className="text-xl font-semibold mt-1">Aula {n}</h2>',
  '        <div className="mt-4"><Markdown markdown={aula.markdown} /></div>',
  '        <div className="mt-6 flex gap-2">',
  '          {prev ? <Link className="card px-3 py-2 hover:bg-white/10 transition" href={prev}>Anterior</Link> : null}',
  '          {next ? <Link className="card px-3 py-2 hover:bg-white/10 transition" href={next}>Próxima</Link> : null}',
  '        </div>',
  '      </div>',
  '    </main>',
  '  );',
  '}',
  ''
) -join "`n"
WriteUtf8NoBom $pAula $aulaPage
WriteLine "[OK] Patch: /c/[slug]/a/[aula]/page.tsx (await params)."

# 3) /c/[slug]/pratica/page.tsx (params Promise)
$pPratica = Join-Path $repo "src\app\c\[slug]\pratica\page.tsx"
BackupFile $pPratica
$praticaPage = @(
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
  '}',
  ''
) -join "`n"
WriteUtf8NoBom $pPratica $praticaPage
WriteLine "[OK] Patch: /c/[slug]/pratica/page.tsx (await params)."

# 4) /c/[slug]/quiz/page.tsx (params Promise)
$pQuiz = Join-Path $repo "src\app\c\[slug]\quiz\page.tsx"
BackupFile $pQuiz
$quizPage = @(
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
  '}',
  ''
) -join "`n"
WriteUtf8NoBom $pQuiz $quizPage
WriteLine "[OK] Patch: /c/[slug]/quiz/page.tsx (await params)."

# 5) VERIFY
WriteLine "[VERIFY] npm run lint..."
RunNative $repo $npmExe @("run","lint")

WriteLine ""
WriteLine "[OK] Params Promise corrigido. Reinicie o dev se necessário."