$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Write-Host ("[DIAG] Repo: " + $repo)

. (Join-Path $PSScriptRoot "_bootstrap.ps1")

$changed = New-Object System.Collections.Generic.List[string]

function WriteFileLines([string]$rel, [string[]]$lines) {
  $full = Join-Path $repo $rel
  EnsureDir (Split-Path -Parent $full) | Out-Null
  $bk = $null
  if (Test-Path -LiteralPath $full) { $bk = BackupFile $full }
  $content = $lines -join "`r`n"
  WriteUtf8NoBom $full $content
  Write-Host ("[OK] wrote: " + $full)
  if ($bk) { Write-Host ("[BK] " + $bk) }
  $script:changed.Add($full) | Out-Null
}

# 1) Component: src/components/v2/DebateV2.tsx
$deb = @(
  '"use client";',
  '',
  'import React, { useCallback, useEffect, useMemo, useSyncExternalStore } from "react";',
  '',
  'export type DebatePrompt = { id: string; title: string; prompt: string };',
  '',
  'function readHashId(): string {',
  '  if (typeof window === "undefined") return "";',
  '  const h = window.location.hash || "";',
  '  return h.startsWith("#") ? h.slice(1) : h;',
  '}',
  '',
  'function setHashId(id: string) {',
  '  if (typeof window === "undefined") return;',
  '  try {',
  '    const url = new URL(window.location.href);',
  '    url.hash = id ? "#" + id : "";',
  '    window.history.replaceState(null, "", url.toString());',
  '    try { window.dispatchEvent(new HashChangeEvent("hashchange")); } catch { window.dispatchEvent(new Event("hashchange")); }',
  '  } catch {',
  '  }',
  '}',
  '',
  'function useHashId(): string {',
  '  return useSyncExternalStore(',
  '    (cb) => {',
  '      if (typeof window === "undefined") return () => {};',
  '      window.addEventListener("hashchange", cb);',
  '      return () => window.removeEventListener("hashchange", cb);',
  '    },',
  '    () => readHashId(),',
  '    () => ""',
  '  );',
  '}',
  '',
  'async function copyText(text: string): Promise<boolean> {',
  '  try {',
  '    if (navigator.clipboard && navigator.clipboard.writeText) {',
  '      await navigator.clipboard.writeText(text);',
  '      return true;',
  '    }',
  '  } catch {}',
  '  try {',
  '    const ta = document.createElement("textarea");',
  '    ta.value = text;',
  '    ta.style.position = "fixed";',
  '    ta.style.left = "-9999px";',
  '    document.body.appendChild(ta);',
  '    ta.select();',
  '    const ok = document.execCommand("copy");',
  '    document.body.removeChild(ta);',
  '    return ok;',
  '  } catch {',
  '    return false;',
  '  }',
  '}',
  '',
  'export function DebateV2(props: { slug: string; title: string; prompts: DebatePrompt[] }) {',
  '  const activeId = useHashId();',
  '',
  '  const prompts = useMemo(() => {',
  '    return (props.prompts || []).filter((p) => p && p.id && p.title && p.prompt);',
  '  }, [props.prompts]);',
  '',
  '  useEffect(() => {',
  '    if (!activeId) return;',
  '    const el = document.getElementById(activeId);',
  '    if (!el) return;',
  '    const t = setTimeout(() => {',
  '      try { el.scrollIntoView({ behavior: "smooth", block: "start" }); } catch {}',
  '    }, 20);',
  '    return () => clearTimeout(t);',
  '  }, [activeId]);',
  '',
  '  const onFocus = useCallback((id: string) => setHashId(id), []);',
  '  const onClear = useCallback(() => setHashId(""), []);',
  '',
  '  return (',
  '    <div style={{ display: "grid", gap: 12 }}>',
  '      <header style={{ border: "1px solid rgba(255,255,255,0.10)", borderRadius: 14, padding: 12, background: "rgba(0,0,0,0.22)" }}>',
  '        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 12 }}>',
  '          <div style={{ display: "flex", flexDirection: "column", gap: 2 }}>',
  '            <div style={{ fontSize: 12, opacity: 0.75 }}>Debate V2</div>',
  '            <div style={{ fontSize: 16, fontWeight: 800 }}>{props.title}</div>',
  '          </div>',
  '          <div style={{ display: "flex", alignItems: "center", gap: 8, flexWrap: "wrap" }}>',
  '            <span style={{ fontSize: 12, opacity: 0.85, padding: "6px 10px", borderRadius: 999, border: "1px solid rgba(255,255,255,0.12)" }}>',
  '              Foco: {activeId ? "#" + activeId : "nenhum"}',
  '            </span>',
  '            <button',
  '              onClick={onClear}',
  '              type="button"',
  '              title="Limpar foco (remover hash)"',
  '              style={{ cursor: "pointer", fontSize: 12, fontWeight: 700, padding: "8px 10px", borderRadius: 10, background: "rgba(255,255,255,0.06)", border: "1px solid rgba(255,255,255,0.12)", color: "inherit" }}',
  '            >',
  '              Limpar foco',
  '            </button>',
  '          </div>',
  '        </div>',
  '      </header>',
  '',
  '      <div style={{ display: "grid", gap: 10 }}>',
  '        {prompts.map((p) => {',
  '          const isActive = activeId && activeId === p.id;',
  '          return (',
  '            <section key={p.id} id={p.id} style={{ borderRadius: 14, padding: 12, border: isActive ? "2px solid var(--accent)" : "1px solid rgba(255,255,255,0.10)", background: "rgba(0,0,0,0.18)" }}>',
  '              <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", gap: 12 }}>',
  '                <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>',
  '                  <div style={{ display: "flex", alignItems: "center", gap: 8, flexWrap: "wrap" }}>',
  '                    <button',
  '                      onClick={() => onFocus(p.id)}',
  '                      type="button"',
  '                      title="Definir foco via hash"',
  '                      style={{ cursor: "pointer", fontSize: 12, fontWeight: 800, padding: "6px 10px", borderRadius: 999, background: isActive ? "var(--accent)" : "rgba(255,255,255,0.06)", border: "1px solid rgba(255,255,255,0.12)", color: isActive ? "#111" : "inherit" }}',
  '                    >',
  '                      #{p.id}',
  '                    </button>',
  '                    <div style={{ fontSize: 14, fontWeight: 900 }}>{p.title}</div>',
  '                  </div>',
  '                  <div style={{ fontSize: 13, lineHeight: 1.45, opacity: 0.95, whiteSpace: "pre-wrap" }}>{p.prompt}</div>',
  '                </div>',
  '',
  '                <div style={{ display: "flex", gap: 8, flexWrap: "wrap", justifyContent: "flex-end" }}>',
  '                  <button',
  '                    type="button"',
  '                    title="Copiar prompt"',
  '                    style={{ cursor: "pointer", fontSize: 12, fontWeight: 800, padding: "8px 10px", borderRadius: 10, background: "rgba(255,255,255,0.06)", border: "1px solid rgba(255,255,255,0.12)", color: "inherit" }}',
  '                    onClick={async () => { const ok = await copyText(p.prompt); if (!ok) alert("Não consegui copiar aqui. Tenta manualmente."); }}',
  '                  >',
  '                    Copiar',
  '                  </button>',
  '                  <button',
  '                    type="button"',
  '                    title="Focar (hash) e destacar"',
  '                    style={{ cursor: "pointer", fontSize: 12, fontWeight: 800, padding: "8px 10px", borderRadius: 10, background: "rgba(255,255,255,0.06)", border: "1px solid rgba(255,255,255,0.12)", color: "inherit" }}',
  '                    onClick={() => onFocus(p.id)}',
  '                  >',
  '                    Focar',
  '                  </button>',
  '                </div>',
  '              </div>',
  '            </section>',
  '          );',
  '        })}',
  '      </div>',
  '    </div>',
  '  );',
  '}'
)
WriteFileLines "src\components\v2\DebateV2.tsx" $deb

# 2) Page: src/app/c/[slug]/v2/debate/page.tsx
$pg = @(
  'import { notFound } from "next/navigation";',
  'import type { CSSProperties } from "react";',
  'import { getCaderno } from "@/lib/cadernos";',
  'import { V2Nav } from "@/components/v2/V2Nav";',
  'import { DebateV2, type DebatePrompt } from "@/components/v2/DebateV2";',
  '',
  'type AccentStyle = CSSProperties & Record<"--accent", string>;',
  '',
  'export default async function Page({ params }: { params: Promise<{ slug: string }> }) {',
  '  const { slug } = await params;',
  '',
  '  let data: Awaited<ReturnType<typeof getCaderno>>;',
  '  try {',
  '    data = await getCaderno(slug);',
  '  } catch (e) {',
  '    const err = e as { code?: string };',
  '    if (err && err.code === "ENOENT") return notFound();',
  '    throw e;',
  '  }',
  '',
  '  const title = data.meta?.title ?? slug;',
  '  const accent = data.meta?.accent ?? "#F7C600";',
  '  const s: AccentStyle = { ["--accent"]: accent } as AccentStyle;',
  '',
  '  const prompts: DebatePrompt[] = data.debate && data.debate.length',
  '    ? (data.debate as DebatePrompt[])',
  '    : [',
  '        { id: "impacto", title: "Impacto", prompt: "Qual é o choque aqui? Em uma frase: o que está acontecendo e por que é urgente?" },',
  '        { id: "contexto", title: "Contexto", prompt: "O que precisa ser entendido do território, da história e da rotina para não cair no moralismo?" },',
  '        { id: "critica", title: "Crítica estrutural", prompt: "Qual é a engrenagem (poder, dinheiro, burocracia, silêncio) que mantém isso funcionando assim?" },',
  '        { id: "humanizacao", title: "Humanização", prompt: "Quem carrega o custo? Traga gente real: trabalho, saúde, tempo, medo, esperança." },',
  '        { id: "convocacao", title: "Convocação", prompt: "Qual é o próximo passo prático? O que dá pra fazer junto (apoio mútuo, organização, prova, continuidade)?" },',
  '      ];',
  '',
  '  return (',
  '    <main style={{ padding: 14, maxWidth: 1100, margin: "0 auto", ...s }}>',
  '      <V2Nav slug={slug} active="debate" />',
  '      <div style={{ marginTop: 12 }}>',
  '        <DebateV2 slug={slug} title={title} prompts={prompts} />',
  '      </div>',
  '    </main>',
  '  );',
  '}'
)
WriteFileLines "src\app\c\[slug]\v2\debate\page.tsx" $pg

# 3) VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# 4) REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Step D3 — Debate V2 interativo (v0_55)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que entrou") | Out-Null
$rep.Add("- DebateV2 (client): foco por hash, scroll suave, copiar prompt, limpar foco.") | Out-Null
$rep.Add("- /c/[slug]/v2/debate: carrega caderno, fallback de prompts, aplica --accent e usa V2Nav.") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null
$rep.Add("") | Out-Null
$rp = WriteReport "cv-step-d3-debatev2-interactive-v0_55.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Step D3 aplicado e verificado."