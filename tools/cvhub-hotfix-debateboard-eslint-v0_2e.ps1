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
$debPath = Join-Path $repo "src\components\DebateBoard.tsx"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] File: " + $debPath)

if (-not (TestP $debPath)) {
  throw ("[STOP] Não achei DebateBoard.tsx em: " + $debPath)
}

# -------------------------
# PATCH
# -------------------------
BackupFile $debPath

$deb = @(
'"use client";',
'',
'import { useMemo, useState } from "react";',
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
'function emptySaved(): Saved {',
'  return { answers: {}, pedidoConcreto: "", acaoAjudaMutua: "" };',
'}',
'',
'function loadSaved(k: string): Saved {',
'  try {',
'    const raw = localStorage.getItem(k);',
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
'  slug: string;',
'  prompts: DebatePrompt[];',
'}) {',
'  const k = useMemo(() => keyFor(slug), [slug]);',
'',
'  // Carrega do localStorage na inicialização do state (evita setState dentro de useEffect)',
'  const init = useMemo(() => loadSaved(k), [k]);',
'',
'  const [answers, setAnswers] = useState<Record<string, string>>(init.answers);',
'  const [pedidoConcreto, setPedido] = useState(init.pedidoConcreto);',
'  const [acaoAjudaMutua, setAcao] = useState(init.acaoAjudaMutua);',
'  const [status, setStatus] = useState<"" | "salvo" | "copiado">("");',
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
'  const clearAll = () => {',
'    setAnswers({});',
'    setPedido("");',
'    setAcao("");',
'    try {',
'      localStorage.removeItem(k);',
'    } catch {}',
'  };',
'',
'  return (',
'    <div className="space-y-4">',
'      <div className="card p-5">',
'        <h3 className="text-lg font-semibold">Sem tribunal</h3>',
'        <p className="muted mt-2">',
'          Debate aqui é ferramenta de cuidado e organização: diagnóstico estrutural,',
'          linguagem concreta, e saída prática.',
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
'              onChange={(e) =>',
'                setAnswers((prev) => ({ ...prev, [p.id]: e.target.value }))',
'              }',
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
'            <div className="text-sm muted">',
'              Pedido concreto (para poder público / empresa / órgão / bairro)',
'            </div>',
'            <textarea',
'              className="mt-2 w-full rounded-xl border border-white/10 bg-black/20 p-3 outline-none focus:border-white/20"',
'              rows={3}',
'              value={pedidoConcreto}',
'              onChange={(e) => setPedido(e.target.value)}',
'            />',
'          </div>',
'          <div>',
'            <div className="text-sm muted">',
'              Ação simples de ajuda mútua (2–10 min)',
'            </div>',
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
'          <button',
'            className="card px-3 py-2 hover:bg-white/10 transition"',
'            onClick={save}',
'          >',
'            <span className="accent">{status === "salvo" ? "Salvo!" : "Salvar"}</span>',
'          </button>',
'          <button',
'            className="card px-3 py-2 hover:bg-white/10 transition"',
'            onClick={copy}',
'          >',
'            <span className="accent">',
'              {status === "copiado" ? "Copiado!" : "Copiar JSON"}',
'            </span>',
'          </button>',
'          <button',
'            className="card px-3 py-2 hover:bg-white/10 transition"',
'            onClick={clearAll}',
'          >',
'            Limpar',
'          </button>',
'        </div>',
'      </div>',
'    </div>',
'  );',
'}',
''
) -join "`n"

WriteUtf8NoBom $debPath $deb
WL "[OK] DebateBoard.tsx reescrito (sem useEffect)."

# -------------------------
# REPORT
# -------------------------
$repDir = Join-Path $repo "reports"
EnsureDir $repDir
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$reportPath = Join-Path $repDir "cv-2d-hotfix-debateboard-eslint-v0_2e.md"

$report = @(
  "# CV-2d — Hotfix ESLint DebateBoard — " + $now,
  "",
  "## Problema",
  "- ESLint: react-hooks/set-state-in-effect (setState dentro de useEffect)",
  "",
  "## Correção",
  "- DebateBoard agora carrega do localStorage na inicialização do state (useMemo + useState)",
  "- Removeu useEffect e os setState no effect",
  "",
  "## Verify",
  "- npm run lint (deve passar)"
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
WL "[OK] Hotfix aplicado. Pode abrir /c/poluicao-vr/debate"