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
  $p = $here
  for ($i=0; $i -lt 4; $i++) {
    $p2 = Split-Path -Parent $p
    if (-not $p2 -or $p2 -eq $p) { break }
    $p = $p2
    if (TestP (Join-Path $p "package.json")) { return $p }
  }
  throw ("[STOP] Rode na raiz do repo (onde tem package.json). Atual: " + $here)
}

# -------------------------
# DIAG
# -------------------------
$repo = ResolveRepoHere
$npmExe = ResolveExe "npm.cmd"
$debPath = Join-Path $repo "src\components\DebateBoard.tsx"
$regPath = Join-Path $repo "src\components\RegistroPanel.tsx"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] DebateBoard: " + $debPath)
WL ("[DIAG] RegistroPanel: " + $regPath)

if (-not (TestP $debPath)) { throw ("[STOP] Não achei: " + $debPath) }
if (-not (TestP $regPath)) { throw ("[STOP] Não achei: " + $regPath) }

# -------------------------
# PATCH: DebateBoard (remove hooks condicionais)
# -------------------------
BackupFile $debPath

$deb = @(
'"use client";',
'',
'import { useMemo, useState } from "react";',
'import { useParams } from "next/navigation";',
'',
'export type DebatePrompt = { id: string; title: string; prompt: string };',
'',
'type Saved = {',
'  answers: Record<string, string>;',
'  pedidoConcreto: string;',
'  acaoAjudaMutua: string;',
'};',
'',
'function slugFromParams(p: unknown): string | undefined {',
'  if (!p || typeof p !== "object") return;',
'  const v = (p as Record<string, unknown>).slug;',
'  return typeof v === "string" ? v : undefined;',
'}',
'',
'function keyFor(slug: string) {',
'  return `cv:${slug}:debate:v1`;',
'}',
'',
'function emptySaved(): Saved {',
'  return { answers: {}, pedidoConcreto: "", acaoAjudaMutua: "" };',
'}',
'',
'function safeGetItem(k: string): string | null {',
'  try {',
'    if (typeof window === "undefined") return null;',
'    return window.localStorage.getItem(k);',
'  } catch {',
'    return null;',
'  }',
'}',
'',
'function safeSetItem(k: string, v: string) {',
'  try {',
'    if (typeof window === "undefined") return;',
'    window.localStorage.setItem(k, v);',
'  } catch {}',
'}',
'',
'function safeRemoveItem(k: string) {',
'  try {',
'    if (typeof window === "undefined") return;',
'    window.localStorage.removeItem(k);',
'  } catch {}',
'}',
'',
'function loadSaved(k: string): Saved {',
'  try {',
'    const raw = safeGetItem(k);',
'    if (!raw) return emptySaved();',
'    const data = JSON.parse(raw) as Partial<Saved>;',
'    return {',
'      answers: (data.answers as Record<string, string>) || {},',
'      pedidoConcreto: (data.pedidoConcreto as string) || "",',
'      acaoAjudaMutua: (data.acaoAjudaMutua as string) || "",',
'    };',
'  } catch {',
'    return emptySaved();',
'  }',
'}',
'',
'export default function DebateBoard({',
'  slug,',
'  prompts,',
'}: {',
'  slug?: string;',
'  prompts: DebatePrompt[];',
'}) {',
'  const params = useParams();',
'  const s = useMemo(() => slug ?? slugFromParams(params) ?? "", [slug, params]);',
'  const k = useMemo(() => (s ? keyFor(s) : ""), [s]);',
'  const init = useMemo(() => (k ? loadSaved(k) : emptySaved()), [k]);',
'',
'  const [answers, setAnswers] = useState<Record<string, string>>(() => init.answers);',
'  const [pedidoConcreto, setPedido] = useState(() => init.pedidoConcreto);',
'  const [acaoAjudaMutua, setAcao] = useState(() => init.acaoAjudaMutua);',
'  const [status, setStatus] = useState<"" | "salvo" | "copiado">("");',
'',
'  const save = () => {',
'    if (!k) return;',
'    try {',
'      const data: Saved = { answers, pedidoConcreto, acaoAjudaMutua };',
'      safeSetItem(k, JSON.stringify(data));',
'      setStatus("salvo");',
'      setTimeout(() => setStatus(""), 1200);',
'    } catch {}',
'  };',
'',
'  const copy = async () => {',
'    if (!s) return;',
'    try {',
'      const payload = { slug: s, answers, pedidoConcreto, acaoAjudaMutua };',
'      await navigator.clipboard.writeText(JSON.stringify(payload, null, 2));',
'      setStatus("copiado");',
'      setTimeout(() => setStatus(""), 1200);',
'    } catch {}',
'  };',
'',
'  const clearAll = () => {',
'    setAnswers({});',
'    setPedido("");',
'    setAcao("");',
'    if (k) safeRemoveItem(k);',
'  };',
'',
'  if (!s) {',
'    return (',
'      <div className="card p-5">',
'        <div className="text-lg font-semibold">Carregando…</div>',
'        <div className="muted mt-2">Aguardando slug do caderno.</div>',
'      </div>',
'    );',
'  }',
'',
'  return (',
'    <div className="space-y-4">',
'      <div className="card p-5">',
'        <h3 className="text-lg font-semibold">Sem tribunal</h3>',
'        <p className="muted mt-2">',
'          Debate aqui é ferramenta de cuidado e organização: diagnóstico estrutural, linguagem concreta, e saída prática.',
'        </p>',
'        <div className="mt-4 grid gap-2 text-sm muted">',
'          <div>• Evitar moralismo / caça às bruxas.</div>',
'          <div>',
'            • Sempre terminar com: <span className="accent">pedido concreto</span> +{" "}',
'            <span className="accent">ação simples de ajuda mútua</span>.',
'          </div>',
'        </div>',
'      </div>',
'',
'      <div className="grid gap-3">',
'        {prompts.map((p) => (',
'          <div key={p.id} className="card p-5">',
'            <div className="text-xs muted">{p.id}</div>',
'            <div className="text-lg font-semibold mt-1">{p.title}</div>',
'            <div className="muted mt-2 whitespace-pre-wrap">{p.prompt}</div>',
'            <textarea',
'              className="mt-4 w-full rounded-xl border border-white/10 bg-black/20 p-3 outline-none focus:border-white/20"',
'              rows={5}',
'              value={answers[p.id] || ""}',
'              onChange={(e) => setAnswers((prev) => ({ ...prev, [p.id]: e.target.value }))}',
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
'            <div className="text-sm muted">Pedido concreto (poder público / empresa / órgão / bairro)</div>',
'            <textarea',
'              className="mt-2 w-full rounded-xl border border-white/10 bg-black/20 p-3 outline-none focus:border-white/20"',
'              rows={3}',
'              value={pedidoConcreto}',
'              onChange={(e) => setPedido(e.target.value)}',
'            />',
'          </div>',
'          <div>',
'            <div className="text-sm muted">Ação simples de ajuda mútua (2–10 min)</div>',
'            <textarea',
'              className="mt-2 w-full rounded-xl border border-white/10 bg-black/20 p-3 outline-none focus:border-white/20"',
'              rows={3}',
'              value={acaoAjudaMutua}',
'              onChange={(e) => setAcao(e.target.value)}',
'            />',
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
'          <button className="card px-3 py-2 hover:bg-white/10 transition" onClick={clearAll}>',
'            Limpar',
'          </button>',
'        </div>',
'      </div>',
'    </div>',
'  );',
'}'
) -join "`n"

WriteUtf8NoBom $debPath $deb
WL "[OK] patched: DebateBoard.tsx (hooks não-condicionais)"

# -------------------------
# PATCH: RegistroPanel (remove hooks condicionais)
# -------------------------
BackupFile $regPath

$reg = @(
'"use client";',
'',
'import { useMemo, useState } from "react";',
'import { useParams } from "next/navigation";',
'',
'type DebateSaved = {',
'  answers: Record<string, string>;',
'  pedidoConcreto: string;',
'  acaoAjudaMutua: string;',
'};',
'',
'type ProgressSaved = { total: number; current: number; updatedAt: number };',
'',
'function slugFromParams(p: unknown): string | undefined {',
'  if (!p || typeof p !== "object") return;',
'  const v = (p as Record<string, unknown>).slug;',
'  return typeof v === "string" ? v : undefined;',
'}',
'',
'function kDebate(slug: string) { return `cv:${slug}:debate:v1`; }',
'function kProg1(slug: string) { return `cv:${slug}:aulaProgress:v1`; }',
'function kProgAlt(slug: string) { return `cv:${slug}:progress:v1`; }',
'',
'function safeGet(k: string): string | null {',
'  try {',
'    if (typeof window === "undefined") return null;',
'    return window.localStorage.getItem(k);',
'  } catch {',
'    return null;',
'  }',
'}',
'',
'function safeRemove(k: string) {',
'  try {',
'    if (typeof window === "undefined") return;',
'    window.localStorage.removeItem(k);',
'  } catch {}',
'}',
'',
'function loadDebate(slug: string): DebateSaved | null {',
'  try {',
'    const raw = safeGet(kDebate(slug));',
'    if (!raw) return null;',
'    const data = JSON.parse(raw) as Partial<DebateSaved>;',
'    return {',
'      answers: (data.answers as Record<string, string>) || {},',
'      pedidoConcreto: (data.pedidoConcreto as string) || "",',
'      acaoAjudaMutua: (data.acaoAjudaMutua as string) || "",',
'    };',
'  } catch {',
'    return null;',
'  }',
'}',
'',
'function loadProg(slug: string): ProgressSaved | null {',
'  const keys = [kProg1(slug), kProgAlt(slug)];',
'  for (const k of keys) {',
'    const raw = safeGet(k);',
'    if (!raw) continue;',
'    try {',
'      const data = JSON.parse(raw) as Partial<ProgressSaved>;',
'      if (typeof data.total === "number" && typeof data.current === "number") {',
'        return {',
'          total: data.total,',
'          current: data.current,',
'          updatedAt: typeof data.updatedAt === "number" ? data.updatedAt : Date.now(),',
'        };',
'      }',
'    } catch {}',
'  }',
'  return null;',
'}',
'',
'export default function RegistroPanel({ slug }: { slug?: string }) {',
'  const params = useParams();',
'  const s = useMemo(() => slug ?? slugFromParams(params) ?? "", [slug, params]);',
'',
'  const debate = useMemo(() => (s ? loadDebate(s) : null), [s]);',
'  const prog = useMemo(() => (s ? loadProg(s) : null), [s]);',
'  const [status, setStatus] = useState<"" | "copiado">("");',
'',
'  const copy = async () => {',
'    if (!s) return;',
'    try {',
'      const payload = {',
'        slug: s,',
'        generatedAt: new Date().toISOString(),',
'        progress: prog,',
'        debate: debate,',
'      };',
'      await navigator.clipboard.writeText(JSON.stringify(payload, null, 2));',
'      setStatus("copiado");',
'      setTimeout(() => setStatus(""), 1200);',
'    } catch {}',
'  };',
'',
'  const clear = () => {',
'    if (!s) return;',
'    safeRemove(kDebate(s));',
'    safeRemove(kProg1(s));',
'    safeRemove(kProgAlt(s));',
'    window.location.reload();',
'  };',
'',
'  const answered = debate ? Object.values(debate.answers || {}).filter((v) => (v || "").trim().length > 0).length : 0;',
'',
'  if (!s) {',
'    return (',
'      <div className="card p-5">',
'        <div className="text-lg font-semibold">Carregando…</div>',
'        <div className="muted mt-2">Aguardando slug do caderno.</div>',
'      </div>',
'    );',
'  }',
'',
'  return (',
'    <div className="space-y-4">',
'      <div className="card p-5">',
'        <h2 className="text-xl font-semibold">Registro do Caderno</h2>',
'        <p className="muted mt-2">',
'          Isso é o “Registro do Caderno” (progresso + debate) salvo no seu aparelho. Não é “recibo de mutirão” (isso é do app ECO).',
'        </p>',
'      </div>',
'',
'      <div className="card p-5">',
'        <div className="text-xs muted">Progresso</div>',
'        {prog ? (',
'          <div className="mt-2">',
'            <div className="text-lg font-semibold">{prog.current} / {prog.total} aulas</div>',
'            <div className="text-sm muted mt-1">Atualizado: {new Date(prog.updatedAt).toLocaleString()}</div>',
'          </div>',
'        ) : (',
'          <div className="muted mt-2">Sem progresso salvo ainda (abra uma aula pra marcar).</div>',
'        )}',
'      </div>',
'',
'      <div className="card p-5">',
'        <div className="text-xs muted">Debate</div>',
'        {debate ? (',
'          <div className="mt-2 space-y-2">',
'            <div className="text-sm muted">Respostas preenchidas: <span className="accent">{answered}</span></div>',
'            <div className="text-sm muted">Pedido concreto: <span className="accent">{debate.pedidoConcreto ? "ok" : "vazio"}</span></div>',
'            <div className="text-sm muted">Ajuda mútua: <span className="accent">{debate.acaoAjudaMutua ? "ok" : "vazio"}</span></div>',
'          </div>',
'        ) : (',
'          <div className="muted mt-2">Sem debate salvo ainda (vá em Debate e salve).</div>',
'        )}',
'      </div>',
'',
'      <div className="card p-5">',
'        <div className="flex flex-wrap gap-2">',
'          <button className="card px-3 py-2 hover:bg-white/10 transition" onClick={copy}>',
'            <span className="accent">{status === "copiado" ? "Copiado!" : "Copiar JSON do registro"}</span>',
'          </button>',
'          <button className="card px-3 py-2 hover:bg-white/10 transition" onClick={clear}>',
'            Limpar registro local',
'          </button>',
'        </div>',
'      </div>',
'    </div>',
'  );',
'}'
) -join "`n"

WriteUtf8NoBom $regPath $reg
WL "[OK] patched: RegistroPanel.tsx (hooks não-condicionais)"

# -------------------------
# REPORT
# -------------------------
$repDir = Join-Path $repo "reports"
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repDir "cv-4c-hotfix-hooks-conditional.md"
$report = @(
("# CV-4c — Hotfix ESLint Hooks Condicionais — " + $now),
"",
"## Problema",
"- ESLint: react-hooks/rules-of-hooks (hooks chamados condicionalmente)",
"",
"## Correção",
"- DebateBoard.tsx: removeu return antes dos hooks; slug vira string vazia e render mostra 'Carregando' quando necessário.",
"- RegistroPanel.tsx: mesma correção; hooks sempre executam na mesma ordem.",
"",
"## Verify",
"- npm run lint",
"- npm run build"
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
WL "[OK] Hotfix aplicado."