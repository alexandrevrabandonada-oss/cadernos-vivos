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

function DetectAppRoot([string]$repo) {
  $a = Join-Path $repo "src\app"
  if (TestP $a) { return $a }
  $b = Join-Path $repo "app"
  if (TestP $b) { return $b }
  throw "[STOP] Não achei src\app nem app."
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
# PATHS (com [slug] e afins sempre via -LiteralPath nas funcs)
# -------------------------
$cSlugDir   = Join-Path $appRoot "c\[slug]"
$cAulaDir   = Join-Path $appRoot "c\[slug]\a\[aula]"
$cPraDir    = Join-Path $appRoot "c\[slug]\pratica"
$cQuizDir   = Join-Path $appRoot "c\[slug]\quiz"
$cAceDir    = Join-Path $appRoot "c\[slug]\acervo"
$cTrilhaDir = Join-Path $appRoot "c\[slug]\trilha"
$cDebDir    = Join-Path $appRoot "c\[slug]\debate"

EnsureDir $cSlugDir
EnsureDir $cAulaDir
EnsureDir $cPraDir
EnsureDir $cQuizDir
EnsureDir $cAceDir
EnsureDir $cTrilhaDir
EnsureDir $cDebDir

$compDir = Join-Path $repo "src\components"
if (-not (TestP $compDir)) { $compDir = Join-Path $repo "components" }
EnsureDir $compDir

$libDir = Join-Path $repo "src\lib"
if (-not (TestP $libDir)) { $libDir = Join-Path $repo "lib" }
EnsureDir $libDir

# -------------------------
# PATCH: NavPills com Trilha + Debate
# -------------------------
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
'    { href: `/c/${slug}/trilha`, label: "Trilha" },',
'    { href: `/c/${slug}/a/1`, label: "Aulas" },',
'    { href: `/c/${slug}/pratica`, label: "Prática" },',
'    { href: `/c/${slug}/quiz`, label: "Quiz" },',
'    { href: `/c/${slug}/acervo`, label: "Acervo" },',
'    { href: `/c/${slug}/debate`, label: "Debate" },',
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

# -------------------------
# NOVO: components (DebateBoard + AulaProgress)
# -------------------------
$debateBoardPath = Join-Path $compDir "DebateBoard.tsx"
$debateBoard = @(
'"use client";',
'',
'import { useEffect, useMemo, useState } from "react";',
'',
'export type DebatePrompt = { id: string; title: string; prompt: string };',
'',
'type Saved = {',
'  answers: Record<string, string>;',
'  pedidoConcreto: string;',
'  acaoAjudaMutua: string;',
'};',
'',
'function keyFor(slug: string) {',
'  return `cv:${slug}:debate:v1`;',
'}',
'',
'export default function DebateBoard({ slug, prompts }: { slug: string; prompts: DebatePrompt[] }) {',
'  const k = useMemo(() => keyFor(slug), [slug]);',
'  const [answers, setAnswers] = useState<Record<string, string>>({});',
'  const [pedidoConcreto, setPedido] = useState("");',
'  const [acaoAjudaMutua, setAcao] = useState("");',
'  const [status, setStatus] = useState<"" | "salvo" | "copiado">("");',
'',
'  useEffect(() => {',
'    try {',
'      const raw = localStorage.getItem(k);',
'      if (!raw) return;',
'      const data = JSON.parse(raw) as Saved;',
'      setAnswers(data.answers || {});',
'      setPedido(data.pedidoConcreto || "");',
'      setAcao(data.acaoAjudaMutua || "");',
'    } catch {}',
'  }, [k]);',
'',
'  const save = () => {',
'    try {',
'      const data: Saved = { answers, pedidoConcreto, acaoAjudaMutua };',
'      localStorage.setItem(k, JSON.stringify(data));',
'      setStatus("salvo");',
'      setTimeout(() => setStatus(""), 1200);',
'    } catch {}',
'  };',
'',
'  const copy = async () => {',
'    try {',
'      const payload = { slug, answers, pedidoConcreto, acaoAjudaMutua };',
'      await navigator.clipboard.writeText(JSON.stringify(payload, null, 2));',
'      setStatus("copiado");',
'      setTimeout(() => setStatus(""), 1200);',
'    } catch {}',
'  };',
'',
'  return (',
'    <div className="space-y-4">',
'      <div className="card p-5">',
'        <h3 className="text-lg font-semibold">Sem tribunal</h3>',
'        <p className="muted mt-2">Debate aqui é ferramenta de cuidado e organização: diagnóstico estrutural, linguagem concreta, e saída prática.</p>',
'        <div className="mt-4 grid gap-2 text-sm muted">',
'          <div>• Evitar moralismo / caça às bruxas.</div>',
'          <div>• Sempre terminar com: <span className="accent">pedido concreto</span> + <span className="accent">ação simples de ajuda mútua</span>.</div>',
'        </div>',
'      </div>',
'',
'      <div className="grid gap-3">',
'        {prompts.map(p => (',
'          <div key={p.id} className="card p-5">',
'            <div className="text-xs muted">{p.id}</div>',
'            <div className="text-lg font-semibold mt-1">{p.title}</div>',
'            <div className="muted mt-2 whitespace-pre-wrap">{p.prompt}</div>',
'            <textarea',
'              className="mt-4 w-full rounded-xl border border-white/10 bg-black/20 p-3 outline-none focus:border-white/20"',
'              rows={5}',
'              value={answers[p.id] || ""}',
'              onChange={(e) => setAnswers(prev => ({ ...prev, [p.id]: e.target.value }))}',
'              placeholder="Escreva sua síntese (sem pânico, sem tribunal)."',
'            />',
'          </div>',
'        ))}',
'      </div>',
'',
'      <div className="card p-5">',
'        <h3 className="text-lg font-semibold">Fechamento obrigatório</h3>',
'        <div className="grid gap-3 mt-3">',
'          <div>',
'            <div className="text-sm muted">Pedido concreto (para poder público / empresa / órgão / bairro)</div>',
'            <textarea className="mt-2 w-full rounded-xl border border-white/10 bg-black/20 p-3 outline-none focus:border-white/20" rows={3} value={pedidoConcreto} onChange={(e)=>setPedido(e.target.value)} />',
'          </div>',
'          <div>',
'            <div className="text-sm muted">Ação simples de ajuda mútua (2–10 min)</div>',
'            <textarea className="mt-2 w-full rounded-xl border border-white/10 bg-black/20 p-3 outline-none focus:border-white/20" rows={3} value={acaoAjudaMutua} onChange={(e)=>setAcao(e.target.value)} />',
'          </div>',
'        </div>',
'',
'        <div className="mt-4 flex flex-wrap gap-2">',
'          <button className="card px-3 py-2 hover:bg-white/10 transition" onClick={save}>',
'            <span className="accent">{status === "salvo" ? "Salvo!" : "Salvar"}</span>',
'          </button>',
'          <button className="card px-3 py-2 hover:bg-white/10 transition" onClick={copy}>',
'            <span className="accent">{status === "copiado" ? "Copiado!" : "Copiar JSON"}</span>',
'          </button>',
'          <button className="card px-3 py-2 hover:bg-white/10 transition" onClick={() => { setAnswers({}); setPedido(""); setAcao(""); try { localStorage.removeItem(k); } catch {} }}>',
'            Limpar',
'          </button>',
'        </div>',
'      </div>',
'    </div>',
'  );',
'}'
) -join "`n"
EnsureFile $debateBoardPath $debateBoard

$aulaProgressPath = Join-Path $compDir "AulaProgress.tsx"
$aulaProgress = @(
'"use client";',
'',
'import Link from "next/link";',
'import { useEffect, useMemo, useState } from "react";',
'',
'function keyFor(slug: string) {',
'  return `cv:${slug}:aulasDone:v1`;',
'}',
'',
'function parseSet(raw: string | null): Set<number> {',
'  try {',
'    if (!raw) return new Set();',
'    const arr = JSON.parse(raw) as number[];',
'    return new Set(Array.isArray(arr) ? arr : []);',
'  } catch {',
'    return new Set();',
'  }',
'}',
'',
'function saveSet(k: string, s: Set<number>) {',
'  try { localStorage.setItem(k, JSON.stringify(Array.from(s.values()).sort((a,b)=>a-b))); } catch {}',
'}',
'',
'export default function AulaProgress({ slug, total, current }: { slug: string; total: number; current: number }) {',
'  const k = useMemo(() => keyFor(slug), [slug]);',
'  const [done, setDone] = useState<Set<number>>(new Set());',
'',
'  useEffect(() => {',
'    setDone(parseSet(localStorage.getItem(k)));',
'  }, [k]);',
'',
'  const isDone = done.has(current);',
'  const toggle = () => {',
'    const next = new Set(done);',
'    if (next.has(current)) next.delete(current); else next.add(current);',
'    setDone(next);',
'    saveSet(k, next);',
'  };',
'',
'  return (',
'    <div className="card p-4">',
'      <div className="flex items-center justify-between gap-3">',
'        <div className="text-sm muted">Progresso das aulas</div>',
'        <button className="card px-3 py-2 hover:bg-white/10 transition" onClick={toggle}>',
'          <span className="accent">{isDone ? "Marcar como não-feita" : "Marcar como feita"}</span>',
'        </button>',
'      </div>',
'',
'      <div className="mt-3 flex flex-wrap gap-2">',
'        {Array.from({ length: total }).map((_, i) => {',
'          const n = i + 1;',
'          const d = done.has(n);',
'          const href = `/c/${slug}/a/${n}`;',
'          const base = "w-9 h-9 rounded-xl border flex items-center justify-center text-sm transition";',
'          const cls = d',
'            ? (base + " border-[color:var(--accent)] bg-white/10")',
'            : (base + " border-white/10 hover:bg-white/10");',
'          const cur = n === current;',
'          return (',
'            <Link key={n} href={href} className={cls} aria-label={`Aula ${n}`}>',
'              <span className={cur ? "accent font-semibold" : (d ? "accent" : "")}>{n}</span>',
'            </Link>',
'          );',
'        })}',
'      </div>',
'    </div>',
'  );',
'}'
) -join "`n"
EnsureFile $aulaProgressPath $aulaProgress

# -------------------------
# PATCH: lib/cadernos.ts (trilha.md + debate.json)
# -------------------------
$cadernosPath = Join-Path $libDir "cadernos.ts"
if (-not (TestP $cadernosPath)) { throw "[STOP] Não achei src/lib/cadernos.ts" }

$rawC = [System.IO.File]::ReadAllText($cadernosPath, [System.Text.Encoding]::UTF8)

if ($rawC -notmatch "DebatePrompt") {
  BackupFile $cadernosPath

  # inserir tipos
  if ($rawC -notmatch "export type AcervoItem") {
    # (se por algum motivo ainda não tiver acervo, não vamos inventar; só segue)
    $rawC = $rawC -replace "export type QuizQ = \{ q: string; choices: string\[\]; answer: number \};",
@"
export type QuizQ = { q: string; choices: string[]; answer: number };
export type DebatePrompt = { id: string; title: string; prompt: string };
"@
  } else {
    $rawC = $rawC -replace "export type AcervoItem = \{ file: string; title: string; kind: string; tags\?: string\[\] \};",
@"
export type AcervoItem = { file: string; title: string; kind: string; tags?: string[] };
export type DebatePrompt = { id: string; title: string; prompt: string };
"@
  }

  # adicionar caminhos
  if ($rawC -notmatch "trilha\.md") {
    $rawC = $rawC -replace "const refsPath = path\.join\(base, slug, ""referencias\.md""\);",
@"
const refsPath = path.join(base, slug, "referencias.md");
const trilhaPath = path.join(base, slug, "trilha.md");
const debatePath = path.join(base, slug, "debate.json");
"@
  }

  # adicionar vars
  if ($rawC -notmatch "let trilha") {
    $rawC = $rawC -replace "let quiz: QuizQ\[\] = \[\];",
@"
let quiz: QuizQ[] = [];
let trilha = "";
let debate: DebatePrompt[] = [];
"@
  }

  # ler trilha/debate
  if ($rawC -notmatch "debatePath") {
    # já tem
  } else {
    if ($rawC -notmatch "try \{ trilha") {
      $rawC = $rawC -replace "try \{ quiz = JSON\.parse\(await fs\.readFile\(praticaQuiz, ""utf8""\)\); \} catch \{\}",
@"
try { quiz = JSON.parse(await fs.readFile(praticaQuiz, "utf8")); } catch {}
try { trilha = await fs.readFile(trilhaPath, "utf8"); } catch { trilha = ""; }
try { debate = JSON.parse(await fs.readFile(debatePath, "utf8")); } catch { debate = []; }
"@
    }
  }

  # retorno
  if ($rawC -match "return \{ meta, panorama, referencias, aulas, flashcards, quiz, acervo \};") {
    $rawC = $rawC -replace "return \{ meta, panorama, referencias, aulas, flashcards, quiz, acervo \};",
"return { meta, panorama, referencias, aulas, flashcards, quiz, acervo, trilha, debate };"
  } elseif ($rawC -match "return \{ meta, panorama, referencias, aulas, flashcards, quiz \};") {
    $rawC = $rawC -replace "return \{ meta, panorama, referencias, aulas, flashcards, quiz \};",
"return { meta, panorama, referencias, aulas, flashcards, quiz, trilha, debate };"
  }

  WriteUtf8NoBom $cadernosPath $rawC
  WL "[OK] patched: cadernos.ts (trilha + debate)"
} else {
  WL "[OK] cadernos.ts já tem DebatePrompt/trilha/debate."
}

# -------------------------
# PAGES: Trilha + Debate
# -------------------------
$pageTrilha = @(
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
'',
'  return (',
'    <main className="space-y-5" style={s}>',
'      <CadernoHeader title={data.meta.title} subtitle={data.meta.subtitle} ethos={data.meta.ethos} />',
'      <NavPills slug={data.meta.slug} />',
'      <div className="card p-5">',
'        <h2 className="text-xl font-semibold">Trilha</h2>',
'        <p className="muted mt-2">Leitura guiada: do panorama ao chão da cidade. Sem excesso de burocracia.</p>',
'      </div>',
'      <div className="card p-5">',
'        {data.trilha ? <Markdown markdown={data.trilha} /> : <p className="muted">Sem trilha ainda. (Crie content/cadernos/[slug]/trilha.md)</p>}',
'      </div>',
'    </main>',
'  );',
'}'
) -join "`n"
EnsureFile (Join-Path $cTrilhaDir "page.tsx") $pageTrilha

$pageDebate = @(
'import type { CSSProperties } from "react";',
'import { getCaderno } from "@/lib/cadernos";',
'import { CadernoHeader, NavPills } from "@/components/CadernoHeader";',
'import DebateBoard from "@/components/DebateBoard";',
'',
'type AccentStyle = CSSProperties & { ["--accent"]?: string };',
'',
'export default async function Page({ params }: { params: Promise<{ slug: string }> }) {',
'  const { slug } = await params;',
'  const data = await getCaderno(slug);',
'  const s: AccentStyle = { ["--accent"]: data.meta.accent };',
'',
'  const prompts = (data.debate && data.debate.length) ? data.debate : [',
'    { id: "P1", title: "O que está acontecendo?", prompt: "Descreva o fenômeno sem moralismo (estrutura, território, rotina)." },',
'    { id: "P2", title: "Quem paga o custo?", prompt: "Exposição • vulnerabilidade • proteção: onde pesa mais e por quê." },',
'    { id: "P3", title: "Que dado falta?", prompt: "O que você precisaria medir/confirmar (sem travar na ausência)." },',
'  ];',
'',
'  return (',
'    <main className="space-y-5" style={s}>',
'      <CadernoHeader title={data.meta.title} subtitle={data.meta.subtitle} ethos={data.meta.ethos} />',
'      <NavPills slug={data.meta.slug} />',
'      <div className="card p-5">',
'        <h2 className="text-xl font-semibold">Debate</h2>',
'        <p className="muted mt-2">Quadro de síntese (salva no seu aparelho). Fecha com pedido concreto + ajuda mútua.</p>',
'      </div>',
'      <DebateBoard slug={slug} prompts={prompts} />',
'    </main>',
'  );',
'}'
) -join "`n"
EnsureFile (Join-Path $cDebDir "page.tsx") $pageDebate

# -------------------------
# PATCH: Aula page para incluir progresso (sem quebrar teu conteúdo)
# -------------------------
$aulaPagePath = Join-Path $cAulaDir "page.tsx"
if (TestP $aulaPagePath) {
  $rawA = [System.IO.File]::ReadAllText($aulaPagePath, [System.Text.Encoding]::UTF8)
  if ($rawA -notmatch "AulaProgress") {
    BackupFile $aulaPagePath

    # injeta import
    if ($rawA -match 'import Link from "next/link";') {
      $rawA = $rawA -replace 'import Link from "next/link";', @(
'import Link from "next/link";',
'import AulaProgress from "@/components/AulaProgress";'
) -join "`n"
    } else {
      # fallback: coloca no topo
      $rawA = 'import AulaProgress from "@/components/AulaProgress";' + "`n" + $rawA
    }

    # injeta o componente antes do card da aula (se possível)
    if ($rawA -match '<div className="card p-5">') {
      $rawA = $rawA -replace '<div className="card p-5">', @(
'<AulaProgress slug={slug} total={total} current={num} />',
'<div className="card p-5">'
) -join "`n"
    }

    WriteUtf8NoBom $aulaPagePath $rawA
    WL "[OK] patched: aula page (AulaProgress)"
  } else {
    WL "[OK] aula page já tem AulaProgress."
  }
} else {
  WL "[WARN] não achei page.tsx de aula para patch: " + $aulaPagePath
}

# -------------------------
# SEED: trilha.md + debate.json para poluicao-vr
# -------------------------
$slug = "poluicao-vr"
$contentBase = Join-Path $repo ("content\cadernos\" + $slug)
EnsureDir $contentBase

$trilhaPath = Join-Path $contentBase "trilha.md"
if (-not (TestP $trilhaPath)) {
  $trilha = @(
'# Trilha v0.2c — Poluição em Volta Redonda',
'',
'Esta trilha é simples e “pé no chão”. A ideia não é acumular PDF: é **entender o território** e produzir **pedido concreto + ação de ajuda mútua**.',
'',
'## 1) Começo (10–15 min)',
'- Leia o **Panorama** e responda mentalmente: *onde pesa mais? por quê?*',
'',
'## 2) Aulas (1 por dia, 10–20 min)',
'- Faça **Aula 1** e marque como feita.',
'- Siga até a 8. Se estiver pesado: pule para a **Prática** e volte depois.',
'',
'## 3) Prática (5–8 min)',
'- Faça 6–10 flashcards por dia.',
'- Use o quiz só como revisão (sem tribunal).',
'',
'## 4) Acervo (quando for necessário)',
'- Use os PDFs/DOCs para aprofundar uma pergunta específica.',
'- Dica: anote *qual dado faltou* e *qual evidência o texto oferece*.',
'',
'## 5) Debate (fechamento)',
'- Preencha o quadro e finalize com:',
'  - **Pedido concreto** (o que exigir e de quem)',
'  - **Ação simples de ajuda mútua** (2–10 min)',
'',
'## Regra do comum',
'Conhecimento aqui é **bem comum**: serve para cuidado, organização e trabalho digno — não para vaidade.'
) -join "`n"
  WriteUtf8NoBom $trilhaPath $trilha
  WL "[OK] seed: trilha.md"
} else {
  WL "[OK] seed já existe: trilha.md"
}

$debatePath = Join-Path $contentBase "debate.json"
if (-not (TestP $debatePath)) {
  $deb = @(
'[',
'  { "id": "P1", "title": "O que está acontecendo (sem moralismo)?", "prompt": "Descreva o fenômeno como estrutura: rotina, território, fontes prováveis, falta de proteção." },',
'  { "id": "P2", "title": "Quem paga o custo (território)?", "prompt": "Use a tríade: Exposição • Vulnerabilidade • Proteção. Onde pesa mais e por quê?" },',
'  { "id": "P3", "title": "Que dado falta (sem travar)?", "prompt": "O que você precisaria medir/confirmar? E qual proxy dá pra usar enquanto isso?" },',
'  { "id": "P4", "title": "Cuidado público mínimo", "prompt": "Liste 3 coisas concretas: (1) informação/dado; (2) infraestrutura de respiro (sombra, água, banheiro, abrigo); (3) resposta pública quando piora." },',
'  { "id": "P5", "title": "Trabalho digno no centro", "prompt": "Como essa camada afeta quem trabalha (turno, calor, poeira, deslocamento)? O que seria proteção real no cotidiano?" },',
'  { "id": "P6", "title": "Saída prática", "prompt": "Qual pedido concreto dá pra fazer hoje? Qual ação simples de ajuda mútua dá pra iniciar em 10 minutos?" }',
']'
) -join "`n"
  WriteUtf8NoBom $debatePath $deb
  WL "[OK] seed: debate.json"
} else {
  WL "[OK] seed já existe: debate.json"
}

# -------------------------
# REPORT
# -------------------------
$repDir = Join-Path $repo "reports"
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repDir "cv-2-debate-trilha-progress-v0_2c.md"
$report = @(
  "# CV-2 v0.2c — " + $now,
  "",
  "## O que entrou",
  "- Rota: /c/[slug]/trilha (markdown trilha.md)",
  "- Rota: /c/[slug]/debate (quadro interativo, localStorage)",
  "- Progresso de aulas (localStorage) + bolinhas navegáveis",
  "- NavPills atualizado (inclui Trilha e Debate)",
  "- Loader inclui trilha.md e debate.json (opcionais)",
  "",
  "## Seed (poluicao-vr)",
  "- content/cadernos/poluicao-vr/trilha.md",
  "- content/cadernos/poluicao-vr/debate.json",
  "",
  "## Ideia-força (ethos)",
  "Conhecimento como bem comum. Diagnóstico estrutural, não moralismo. Fechar com pedido concreto + ajuda mútua."
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
WL "[OK] CV-2 v0.2c aplicado."
WL "[NEXT] npm run dev e teste:"
WL "       /c/poluicao-vr/trilha"
WL "       /c/poluicao-vr/debate"
WL "       /c/poluicao-vr/a/1 (progresso)"