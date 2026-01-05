# CV — V2 Hotfix — Components V2 aceitam unknown (evita loop JsonValue vs unknown) — v0_12
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

function EnsureDir([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}
function WriteUtf8NoBom([string]$path, [string]$text) {
  EnsureDir (Split-Path -Parent $path)
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($path, $text, $enc)
}
function BackupFile([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) { return $null }
  $bkRoot = Join-Path (Get-Location) "tools\_patch_backup"
  EnsureDir $bkRoot
  $stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
  $name = (Split-Path -Leaf $path)
  if ($name -match '\.tsx?$') { $name = $name + ".bak" }
  $dest = Join-Path $bkRoot ($stamp + "-" + $name)
  Copy-Item -LiteralPath $path -Destination $dest -Force
  return $dest
}
function RunCmd([string]$exe, [string[]]$cmdArgs) {
  Write-Host ("[RUN] " + $exe + " " + ($cmdArgs -join " "))
  & $exe @cmdArgs
  if ($LASTEXITCODE -ne 0) { throw ("[STOP] falhou (exit " + $LASTEXITCODE + "): " + $exe + " " + ($cmdArgs -join " ")) }
}

$repo = Get-Location
Write-Host ("[DIAG] Repo: " + $repo)

$cmd = Get-Command "npm.cmd" -ErrorAction SilentlyContinue
$npm = if ($cmd) { $cmd.Source } else { "npm.cmd" }
Write-Host ("[DIAG] npm: " + $npm)

$debate = Join-Path $repo "src\components\v2\DebateV2.tsx"
$provas = Join-Path $repo "src\components\v2\ProvasV2.tsx"
$timeline = Join-Path $repo "src\components\v2\TimelineV2.tsx"

Write-Host ("[DIAG] debate: " + $debate)
Write-Host ("[DIAG] provas: " + $provas)
Write-Host ("[DIAG] timeline: " + $timeline)

# -------------------------
# PATCH: reescrever 3 componentes V2 para props = unknown (guards internos)
# -------------------------

# DebateV2.tsx
$bk1 = BackupFile $debate
$debateText = @(
'import type { JsonValue } from "@/lib/v2/types";',
'',
'function asObj(v: unknown): Record<string, JsonValue> | null {',
'  if (!v || typeof v !== "object") return null;',
'  return v as Record<string, JsonValue>;',
'}',
'function asArr(v: JsonValue | undefined): JsonValue[] {',
'  return Array.isArray(v) ? v : [];',
'}',
'function asStr(v: JsonValue | undefined): string | null {',
'  return typeof v === "string" ? v : null;',
'}',
'function pickArr(o: Record<string, JsonValue> | null, keys: string[]): JsonValue[] {',
'  if (!o) return [];',
'  for (const k of keys) {',
'    const vv = o[k];',
'    if (Array.isArray(vv)) return vv as JsonValue[];',
'  }',
'  return [];',
'}',
'',
'type Props = { slug: string; title: string; debate: unknown };',
'',
'export default function DebateV2({ slug, title, debate }: Props) {',
'  const o = asObj(debate);',
'  const questions = pickArr(o, ["questions", "perguntas", "items", "entries"]);',
'',
'  return (',
'    <div style={{ border: "1px solid rgba(255,255,255,0.10)", borderRadius: 12, padding: 14 }}>',
'      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", gap: 12 }}>',
'        <div>',
'          <div style={{ fontSize: 12, opacity: 0.7 }}>Debate V2</div>',
'          <h2 style={{ fontSize: 18, margin: "4px 0 0 0" }}>{title}</h2>',
'        </div>',
'        <div style={{ fontSize: 12, opacity: 0.7 }}>slug: {slug}</div>',
'      </div>',
'',
'      <div style={{ marginTop: 12, display: "grid", gap: 10 }}>',
'        {questions.length === 0 ? (',
'          <div style={{ opacity: 0.75, fontSize: 14 }}>',
'            Ainda não há perguntas estruturadas neste caderno (debate.json).',
'          </div>',
'        ) : (',
'          questions.map((q, i) => {',
'            const qo = asObj(q);',
'            const id = asStr(qo ? qo["id"] : undefined) || asStr(qo ? qo["slug"] : undefined) || String(i + 1);',
'            const t = asStr(qo ? qo["title"] : undefined) || asStr(qo ? qo["q"] : undefined) || asStr(qo ? qo["pergunta"] : undefined) || "Pergunta";',
'            const body = asStr(qo ? qo["text"] : undefined) || asStr(qo ? qo["body"] : undefined) || asStr(qo ? qo["conteudo"] : undefined);',
'            const tags = asArr(qo ? (qo["tags"] as JsonValue) : undefined).filter((x) => typeof x === "string") as string[];',
'            return (',
'              <div key={id} style={{ border: "1px solid rgba(255,255,255,0.08)", borderRadius: 10, padding: 12 }}>',
'                <div style={{ display: "flex", justifyContent: "space-between", gap: 10, alignItems: "baseline" }}>',
'                  <div style={{ fontWeight: 700 }}>{t}</div>',
'                  <div style={{ fontSize: 12, opacity: 0.7 }}>#{id}</div>',
'                </div>',
'                {body ? <div style={{ marginTop: 6, opacity: 0.85 }}>{body}</div> : null}',
'                {tags.length ? (',
'                  <div style={{ marginTop: 8, display: "flex", flexWrap: "wrap", gap: 6 }}>',
'                    {tags.map((tg) => (',
'                      <span key={tg} style={{ fontSize: 12, opacity: 0.8, border: "1px solid rgba(255,255,255,0.10)", padding: "2px 8px", borderRadius: 999 }}>',
'                        {tg}',
'                      </span>',
'                    ))}',
'                  </div>',
'                ) : null}',
'              </div>',
'            );',
'          })',
'        )}',
'      </div>',
'    </div>',
'  );',
'}',
''
) -join "`n"
WriteUtf8NoBom $debate $debateText
Write-Host "[OK] wrote: src/components/v2/DebateV2.tsx (debate: unknown)"
if ($bk1) { Write-Host ("[BK] " + $bk1) }

# ProvasV2.tsx
$bk2 = BackupFile $provas
$provasText = @(
'import type { JsonValue } from "@/lib/v2/types";',
'',
'function asObj(v: unknown): Record<string, JsonValue> | null {',
'  if (!v || typeof v !== "object") return null;',
'  return v as Record<string, JsonValue>;',
'}',
'function asArr(v: JsonValue | undefined): JsonValue[] {',
'  return Array.isArray(v) ? v : [];',
'}',
'function asStr(v: JsonValue | undefined): string | null {',
'  return typeof v === "string" ? v : null;',
'}',
'',
'type Props = { slug: string; title: string; acervo: unknown };',
'',
'export default function ProvasV2({ slug, title, acervo }: Props) {',
'  const o = asObj(acervo);',
'  const items = asArr(o ? (o["items"] as JsonValue) : undefined);',
'',
'  return (',
'    <div style={{ border: "1px solid rgba(255,255,255,0.10)", borderRadius: 12, padding: 14 }}>',
'      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", gap: 12 }}>',
'        <div>',
'          <div style={{ fontSize: 12, opacity: 0.7 }}>Provas V2</div>',
'          <h2 style={{ fontSize: 18, margin: "4px 0 0 0" }}>{title}</h2>',
'        </div>',
'        <div style={{ fontSize: 12, opacity: 0.7 }}>slug: {slug}</div>',
'      </div>',
'',
'      <div style={{ marginTop: 12, display: "grid", gap: 10 }}>',
'        {items.length === 0 ? (',
'          <div style={{ opacity: 0.75, fontSize: 14 }}>',
'            Nenhum item no acervo (acervo.json).',
'          </div>',
'        ) : (',
'          items.map((it, i) => {',
'            const io = asObj(it);',
'            const id = asStr(io ? io["id"] : undefined) || String(i + 1);',
'            const t = asStr(io ? io["title"] : undefined) || "Item";',
'            const url = asStr(io ? (io["url"] as JsonValue) : undefined) || asStr(io ? (io["link"] as JsonValue) : undefined);',
'            const kind = asStr(io ? (io["kind"] as JsonValue) : undefined) || asStr(io ? (io["type"] as JsonValue) : undefined);',
'            const tags = asArr(io ? (io["tags"] as JsonValue) : undefined).filter((x) => typeof x === "string") as string[];',
'            return (',
'              <div key={id} style={{ border: "1px solid rgba(255,255,255,0.08)", borderRadius: 10, padding: 12 }}>',
'                <div style={{ display: "flex", justifyContent: "space-between", gap: 10, alignItems: "baseline" }}>',
'                  <div style={{ fontWeight: 700 }}>{t}</div>',
'                  <div style={{ fontSize: 12, opacity: 0.7 }}>{kind ? kind : "prova"}</div>',
'                </div>',
'                {url ? (',
'                  <div style={{ marginTop: 6 }}>',
'                    <a href={url} target="_blank" rel="noreferrer" style={{ opacity: 0.9, textDecoration: "underline" }}>',
'                      Abrir fonte',
'                    </a>',
'                  </div>',
'                ) : null}',
'                {tags.length ? (',
'                  <div style={{ marginTop: 8, display: "flex", flexWrap: "wrap", gap: 6 }}>',
'                    {tags.map((tg) => (',
'                      <span key={tg} style={{ fontSize: 12, opacity: 0.8, border: "1px solid rgba(255,255,255,0.10)", padding: "2px 8px", borderRadius: 999 }}>',
'                        {tg}',
'                      </span>',
'                    ))}',
'                  </div>',
'                ) : null}',
'              </div>',
'            );',
'          })',
'        )}',
'      </div>',
'    </div>',
'  );',
'}',
''
) -join "`n"
WriteUtf8NoBom $provas $provasText
Write-Host "[OK] wrote: src/components/v2/ProvasV2.tsx (acervo: unknown)"
if ($bk2) { Write-Host ("[BK] " + $bk2) }

# TimelineV2.tsx
$bk3 = BackupFile $timeline
$timelineText = @(
'import type { JsonValue } from "@/lib/v2/types";',
'',
'function asObj(v: unknown): Record<string, JsonValue> | null {',
'  if (!v || typeof v !== "object") return null;',
'  return v as Record<string, JsonValue>;',
'}',
'function asArr(v: JsonValue | undefined): JsonValue[] {',
'  return Array.isArray(v) ? v : [];',
'}',
'function asStr(v: JsonValue | undefined): string | null {',
'  return typeof v === "string" ? v : null;',
'}',
'function asNum(v: JsonValue | undefined): number | null {',
'  return typeof v === "number" ? v : null;',
'}',
'',
'type Props = { slug: string; title: string; mapa: unknown };',
'',
'export default function TimelineV2({ slug, title, mapa }: Props) {',
'  const o = asObj(mapa);',
'  const nodes = asArr(o ? (o["nodes"] as JsonValue) : undefined);',
'',
'  return (',
'    <div style={{ border: "1px solid rgba(255,255,255,0.10)", borderRadius: 12, padding: 14 }}>',
'      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", gap: 12 }}>',
'        <div>',
'          <div style={{ fontSize: 12, opacity: 0.7 }}>Linha do tempo V2</div>',
'          <h2 style={{ fontSize: 18, margin: "4px 0 0 0" }}>{title}</h2>',
'        </div>',
'        <div style={{ fontSize: 12, opacity: 0.7 }}>slug: {slug}</div>',
'      </div>',
'',
'      <div style={{ marginTop: 12, display: "grid", gap: 10 }}>',
'        {nodes.length === 0 ? (',
'          <div style={{ opacity: 0.75, fontSize: 14 }}>',
'            Sem nodes no mapa (mapa.json).',
'          </div>',
'        ) : (',
'          nodes.map((n, i) => {',
'            const no = asObj(n);',
'            const id = asStr(no ? (no["id"] as JsonValue) : undefined) || String(i + 1);',
'            const t = asStr(no ? (no["title"] as JsonValue) : undefined) || asStr(no ? (no["label"] as JsonValue) : undefined) || "Evento";',
'            const date = asStr(no ? (no["date"] as JsonValue) : undefined) || asStr(no ? (no["day"] as JsonValue) : undefined) || asStr(no ? (no["when"] as JsonValue) : undefined);',
'            const year = asNum(no ? (no["year"] as JsonValue) : undefined) || asNum(no ? (no["ano"] as JsonValue) : undefined);',
'            const whenTxt = date ? date : (year ? String(year) : "sem data");',
'            return (',
'              <div key={id} id={id} style={{ border: "1px solid rgba(255,255,255,0.08)", borderRadius: 10, padding: 12 }}>',
'                <div style={{ display: "flex", justifyContent: "space-between", gap: 10, alignItems: "baseline" }}>',
'                  <div style={{ fontWeight: 700 }}>{t}</div>',
'                  <div style={{ fontSize: 12, opacity: 0.7 }}>{whenTxt}</div>',
'                </div>',
'              </div>',
'            );',
'          })',
'        )}',
'      </div>',
'    </div>',
'  );',
'}',
''
) -join "`n"
WriteUtf8NoBom $timeline $timelineText
Write-Host "[OK] wrote: src/components/v2/TimelineV2.tsx (mapa: unknown)"
if ($bk3) { Write-Host ("[BK] " + $bk3) }

# -------------------------
# VERIFY
# -------------------------
RunCmd $npm @("run","lint")
RunCmd $npm @("run","build")

# -------------------------
# REPORT
# -------------------------
$reports = Join-Path $repo "reports"
EnsureDir $reports
$reportPath = Join-Path $reports "cv-v2-hotfix-components-accept-unknown-v0_12.md"

$report = @(
"# CV — Hotfix v0_12 — V2 components accept unknown",
"",
"## Causa raiz",
"- Pages V2 estavam passando valores tipados como unknown (loader/normalize superset).",
"- Componentes V2 exigiam JsonValue e o build travava (unknown nao atribuivel).",
"",
"## Fix",
"- DebateV2/ProvasV2/TimelineV2 agora recebem unknown e validam internamente com guards.",
"",
"## Arquivos",
"- src/components/v2/DebateV2.tsx",
"- src/components/v2/ProvasV2.tsx",
"- src/components/v2/TimelineV2.tsx",
"",
"## Verify",
"- npm run lint",
"- npm run build",
""
) -join "`n"

WriteUtf8NoBom $reportPath $report
Write-Host ("[OK] Report: " + $reportPath)
Write-Host "[OK] v0_12 aplicado."