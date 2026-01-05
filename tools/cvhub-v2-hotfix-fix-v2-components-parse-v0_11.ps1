# CV — V2 Hotfix — Fix Parsing Error (reescrever componentes V2) — v0_11
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

$repo = Get-Location
Write-Host ("[DIAG] Repo: " + $repo)

$bootstrap = Join-Path $repo "tools\_bootstrap.ps1"
if (Test-Path -LiteralPath $bootstrap) {
  try { . $bootstrap } catch { }
}

if (-not (Get-Command EnsureDir -ErrorAction SilentlyContinue)) {
  function EnsureDir([string]$p) { if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
}
if (-not (Get-Command WriteUtf8NoBom -ErrorAction SilentlyContinue)) {
  function WriteUtf8NoBom([string]$path, [string]$text) {
    EnsureDir (Split-Path -Parent $path)
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $text, $enc)
  }
}
if (-not (Get-Command BackupFile -ErrorAction SilentlyContinue)) {
  function BackupFile([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    $bkRoot = Join-Path (Get-Location) "tools\_patch_backup"
    EnsureDir $bkRoot
    $stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
    $name = (Split-Path -Leaf $path)
    if ($name -match "\.tsx?$") { $name = $name + ".bak" }
    $dest = Join-Path $bkRoot ($stamp + "-" + $name)
    Copy-Item -LiteralPath $path -Destination $dest -Force
    return $dest
  }
}

function RunCmd([string]$exe, [string[]]$cmdArgs) {
  Write-Host ("[RUN] " + $exe + " " + ($cmdArgs -join " "))
  & $exe @cmdArgs
  if ($LASTEXITCODE -ne 0) { throw ("[STOP] falhou (exit " + $LASTEXITCODE + "): " + $exe + " " + ($cmdArgs -join " ")) }
}

$cmd = Get-Command "npm.cmd" -ErrorAction SilentlyContinue
$npmCmd = if ($cmd) { $cmd.Source } else { "npm.cmd" }
Write-Host ("[DIAG] npm: " + $npmCmd)

$debatePath   = Join-Path $repo "src\components\v2\DebateV2.tsx"
$provasPath   = Join-Path $repo "src\components\v2\ProvasV2.tsx"
$timelinePath = Join-Path $repo "src\components\v2\TimelineV2.tsx"
$trilhasList  = Join-Path $repo "src\app\c\[slug]\v2\trilhas\page.tsx"

Write-Host ("[DIAG] debate: " + $debatePath)
Write-Host ("[DIAG] provas: " + $provasPath)
Write-Host ("[DIAG] timeline: " + $timelinePath)

# -------------------------
# PATCH — reescrever componentes (remove syntax quebrada / parser errors)
# -------------------------

# DebateV2.tsx
$bk = BackupFile $debatePath
$debateLines = @(
'import type { JsonValue } from "@/lib/v2/types";',
'',
'function asObj(v: unknown): Record<string, JsonValue> | null {',
'  if (!v || typeof v !== "object") return null;',
'  if (Array.isArray(v)) return null;',
'  return v as Record<string, JsonValue>;',
'}',
'',
'function asArr(v: unknown): JsonValue[] {',
'  return Array.isArray(v) ? (v as JsonValue[]) : [];',
'}',
'',
'function toText(v: unknown): string {',
'  if (typeof v === "string") return v;',
'  if (typeof v === "number" && Number.isFinite(v)) return String(v);',
'  if (typeof v === "boolean") return v ? "true" : "false";',
'  return "";',
'}',
'',
'export default function DebateV2({ debate }: { debate: JsonValue }) {',
'  const root = asObj(debate) || {};',
'  const qs = asArr(root["questions"] ?? root["perguntas"] ?? root["itens"]);',
'',
'  return (',
'    <div className="space-y-4">',
'      <div className="rounded-xl border border-white/10 bg-black/30 p-4">',
'        <div className="text-sm opacity-70">Debate</div>',
'        <div className="text-xl font-semibold">Perguntas e posições</div>',
'        <div className="mt-1 text-sm opacity-70">',
'          V2 placeholder estável (sem quebrar lint/build).',
'        </div>',
'      </div>',
'',
'      {qs.length === 0 ? (',
'        <div className="rounded-xl border border-white/10 bg-black/20 p-4 text-sm opacity-70">',
'          Sem perguntas ainda neste caderno.',
'        </div>',
'      ) : (',
'        <div className="space-y-3">',
'          {qs.map((q, i) => {',
'            const qo = asObj(q);',
'            const title = toText(qo?.["title"] ?? qo?.["question"] ?? qo?.["pergunta"]) || ("Questao " + (i + 1));',
'            const body = toText(qo?.["body"] ?? qo?.["text"] ?? qo?.["descricao"]);',
'            const sides = asArr(qo?.["sides"] ?? qo?.["posicoes"] ?? qo?.["positions"]);',
'',
'            return (',
'              <div key={i} className="rounded-xl border border-white/10 bg-black/20 p-4">',
'                <div className="text-base font-semibold">{title}</div>',
'                {body ? (',
'                  <div className="mt-2 whitespace-pre-wrap text-sm opacity-80">{body}</div>',
'                ) : null}',
'                {sides.length ? (',
'                  <div className="mt-3 flex flex-wrap gap-2">',
'                    {sides.slice(0, 12).map((s, j) => {',
'                      const so = asObj(s);',
'                      const label = toText(so?.["label"] ?? so?.["title"] ?? so?.["nome"]) || ("Posicao " + (j + 1));',
'                      return (',
'                        <span',
'                          key={j}',
'                          className="rounded-full border border-white/10 bg-black/30 px-3 py-1 text-xs opacity-90"',
'                        >',
'                          {label}',
'                        </span>',
'                      );',
'                    })}',
'                  </div>',
'                ) : null}',
'              </div>',
'            );',
'          })}',
'        </div>',
'      )}',
'    </div>',
'  );',
'}',
''
) -join "`n"
WriteUtf8NoBom $debatePath $debateLines
Write-Host "[OK] wrote: src/components/v2/DebateV2.tsx"
if ($bk) { Write-Host ("[BK] " + $bk) }

# ProvasV2.tsx
$bk = BackupFile $provasPath
$provasLines = @(
'import type { JsonValue } from "@/lib/v2/types";',
'',
'function asObj(v: unknown): Record<string, JsonValue> | null {',
'  if (!v || typeof v !== "object") return null;',
'  if (Array.isArray(v)) return null;',
'  return v as Record<string, JsonValue>;',
'}',
'',
'function asArr(v: unknown): JsonValue[] {',
'  return Array.isArray(v) ? (v as JsonValue[]) : [];',
'}',
'',
'function toText(v: unknown): string {',
'  if (typeof v === "string") return v;',
'  if (typeof v === "number" && Number.isFinite(v)) return String(v);',
'  if (typeof v === "boolean") return v ? "true" : "false";',
'  return "";',
'}',
'',
'export default function ProvasV2({ acervo }: { acervo: JsonValue }) {',
'  const root = asObj(acervo) || {};',
'  const items = asArr(root["items"] ?? root["provas"] ?? root["links"] ?? root["fontes"]);',
'',
'  return (',
'    <div className="space-y-4">',
'      <div className="rounded-xl border border-white/10 bg-black/30 p-4">',
'        <div className="text-sm opacity-70">Provas</div>',
'        <div className="text-xl font-semibold">Acervo e referencias</div>',
'        <div className="mt-1 text-sm opacity-70">V2 placeholder estável.</div>',
'      </div>',
'',
'      {items.length === 0 ? (',
'        <div className="rounded-xl border border-white/10 bg-black/20 p-4 text-sm opacity-70">',
'          Sem itens no acervo ainda.',
'        </div>',
'      ) : (',
'        <div className="grid grid-cols-1 gap-3 md:grid-cols-2">',
'          {items.map((it, i) => {',
'            const io = asObj(it) || {};',
'            const url = toText(io["url"] ?? io["link"]);',
'            const title = toText(io["title"] ?? io["name"] ?? io["titulo"]) || (url ? url : ("Item " + (i + 1)));',
'            const kind = toText(io["kind"] ?? io["type"] ?? io["tipo"]);',
'            const tagsArr = asArr(io["tags"]);',
'            const tags = tagsArr.map((t) => toText(t)).filter((t) => t.length > 0).slice(0, 6);',
'',
'            return (',
'              <div key={i} className="rounded-xl border border-white/10 bg-black/20 p-4">',
'                <div className="flex items-start justify-between gap-3">',
'                  <div className="min-w-0">',
'                    <div className="truncate text-base font-semibold">{title}</div>',
'                    {kind ? <div className="mt-1 text-xs opacity-70">{kind}</div> : null}',
'                  </div>',
'                  {url ? (',
'                    <a',
'                      className="shrink-0 rounded-lg border border-white/10 bg-black/30 px-3 py-1 text-xs hover:bg-black/40"',
'                      href={url}',
'                      target="_blank"',
'                      rel="noreferrer"',
'                    >',
'                      Abrir',
'                    </a>',
'                  ) : null}',
'                </div>',
'                {tags.length ? (',
'                  <div className="mt-3 flex flex-wrap gap-2">',
'                    {tags.map((t, j) => (',
'                      <span key={j} className="rounded-full border border-white/10 bg-black/30 px-3 py-1 text-xs opacity-90">',
'                        {t}',
'                      </span>',
'                    ))}',
'                  </div>',
'                ) : null}',
'              </div>',
'            );',
'          })}',
'        </div>',
'      )}',
'    </div>',
'  );',
'}',
''
) -join "`n"
WriteUtf8NoBom $provasPath $provasLines
Write-Host "[OK] wrote: src/components/v2/ProvasV2.tsx"
if ($bk) { Write-Host ("[BK] " + $bk) }

# TimelineV2.tsx
$bk = BackupFile $timelinePath
$timelineLines = @(
'import type { JsonValue } from "@/lib/v2/types";',
'',
'function asObj(v: unknown): Record<string, JsonValue> | null {',
'  if (!v || typeof v !== "object") return null;',
'  if (Array.isArray(v)) return null;',
'  return v as Record<string, JsonValue>;',
'}',
'',
'function asArr(v: unknown): JsonValue[] {',
'  return Array.isArray(v) ? (v as JsonValue[]) : [];',
'}',
'',
'function toText(v: unknown): string {',
'  if (typeof v === "string") return v;',
'  if (typeof v === "number" && Number.isFinite(v)) return String(v);',
'  if (typeof v === "boolean") return v ? "true" : "false";',
'  return "";',
'}',
'',
'function whenKey(o: Record<string, JsonValue>): number | null {',
'  const raw = toText(o["date"] ?? o["day"] ?? o["when"] ?? o["ano"] ?? o["year"]);',
'  if (!raw) return null;',
'  if (/^\\d{4}$/.test(raw)) {',
'    const t = Date.parse(raw + "-01-01T00:00:00Z");',
'    return Number.isFinite(t) ? t : null;',
'  }',
'  const t2 = Date.parse(raw);',
'  return Number.isFinite(t2) ? t2 : null;',
'}',
'',
'export default function TimelineV2({ items }: { items: JsonValue }) {',
'  const arr = Array.isArray(items) ? (items as JsonValue[]) : asArr((asObj(items) || {})["items"]);',
'',
'  const normalized = arr.map((it, i) => {',
'    const o = asObj(it) || {};',
'    const id = toText(o["id"]) || ("t" + (i + 1));',
'    const title = toText(o["title"] ?? o["name"] ?? o["titulo"]) || ("Item " + (i + 1));',
'    const when = toText(o["date"] ?? o["day"] ?? o["when"] ?? o["ano"] ?? o["year"]);',
'    const kind = toText(o["kind"] ?? o["type"] ?? o["tipo"]);',
'    const url = toText(o["url"] ?? o["link"]);',
'    return { id, title, when, kind, url, _k: whenKey(o) };',
'  });',
'',
'  normalized.sort((a, b) => {',
'    if (a._k === null && b._k === null) return 0;',
'    if (a._k === null) return 1;',
'    if (b._k === null) return -1;',
'    return a._k - b._k;',
'  });',
'',
'  return (',
'    <div className="space-y-4">',
'      <div className="rounded-xl border border-white/10 bg-black/30 p-4">',
'        <div className="text-sm opacity-70">Linha do tempo</div>',
'        <div className="text-xl font-semibold">Derivada do mapa</div>',
'        <div className="mt-1 text-sm opacity-70">V2 placeholder estável.</div>',
'      </div>',
'',
'      {normalized.length === 0 ? (',
'        <div className="rounded-xl border border-white/10 bg-black/20 p-4 text-sm opacity-70">',
'          Sem itens na linha do tempo.',
'        </div>',
'      ) : (',
'        <div className="space-y-3">',
'          {normalized.map((it) => (',
'            <div key={it.id} id={it.id} className="rounded-xl border border-white/10 bg-black/20 p-4">',
'              <div className="flex items-start justify-between gap-3">',
'                <div className="min-w-0">',
'                  <div className="truncate text-base font-semibold">{it.title}</div>',
'                  <div className="mt-1 flex flex-wrap gap-2 text-xs opacity-70">',
'                    {it.when ? <span>{it.when}</span> : null}',
'                    {it.kind ? <span>• {it.kind}</span> : null}',
'                  </div>',
'                </div>',
'                <div className="flex shrink-0 items-center gap-2">',
'                  <a className="rounded-lg border border-white/10 bg-black/30 px-3 py-1 text-xs hover:bg-black/40" href={"#" + it.id}>Link</a>',
'                  {it.url ? (',
'                    <a className="rounded-lg border border-white/10 bg-black/30 px-3 py-1 text-xs hover:bg-black/40" href={it.url} target="_blank" rel="noreferrer">Fonte</a>',
'                  ) : null}',
'                </div>',
'              </div>',
'            </div>',
'          ))}',
'        </div>',
'      )}',
'    </div>',
'  );',
'}',
''
) -join "`n"
WriteUtf8NoBom $timelinePath $timelineLines
Write-Host "[OK] wrote: src/components/v2/TimelineV2.tsx"
if ($bk) { Write-Host ("[BK] " + $bk) }

# Opcional: silenciar warning de asArr não usado em /trilhas/page.tsx
if (Test-Path -LiteralPath $trilhasList) {
  $raw = Get-Content -LiteralPath $trilhasList -Raw
  if ($raw -match "function\s+asArr") {
    # Se não houver eslint-disable logo acima, adiciona com segurança
    $lines = Get-Content -LiteralPath $trilhasList
    $out = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $lines.Count; $i++) {
      $line = $lines[$i]
      if ($line -match "function\s+asArr") {
        if ($i -eq 0 -or ($lines[$i-1] -notmatch "eslint-disable-next-line\s+@typescript-eslint/no-unused-vars")) {
          $out.Add("// eslint-disable-next-line @typescript-eslint/no-unused-vars")
        }
      }
      $out.Add($line)
    }
    $bk = BackupFile $trilhasList
    WriteUtf8NoBom $trilhasList ($out -join "`n")
    Write-Host "[OK] patched: /v2/trilhas/page.tsx (silenciou warning asArr)"
    if ($bk) { Write-Host ("[BK] " + $bk) }
  }
}

# -------------------------
# VERIFY
# -------------------------
RunCmd $npmCmd @("run","lint")
RunCmd $npmCmd @("run","build")

# -------------------------
# REPORT
# -------------------------
$reports = Join-Path $repo "reports"
EnsureDir $reports
$reportPath = Join-Path $reports "cv-v2-hotfix-fix-v2-components-parse-v0_11.md"

$report = @(
"# CV — Hotfix v0_11 — Fix Parsing Error em componentes V2",
"",
"## Sintoma",
"- eslint: Parsing error: Expression expected (DebateV2/ProvasV2/TimelineV2)",
"",
"## Causa raiz",
"- Arquivos TSX com sintaxe quebrada por patches anteriores (comentarios/insercoes tortas).",
"",
"## Fix",
"- Reescreveu do zero: DebateV2.tsx, ProvasV2.tsx, TimelineV2.tsx (sem any, sem JSX problemático).",
"- Opcional: silenciou warning de asArr não usado em /v2/trilhas/page.tsx.",
"",
"## Verify",
"- npm run lint",
"- npm run build",
""
) -join "`n"

WriteUtf8NoBom $reportPath $report
Write-Host ("[OK] Report: " + $reportPath)
Write-Host "[OK] v0_11 aplicado."