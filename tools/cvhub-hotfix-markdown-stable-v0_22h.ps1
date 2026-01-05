param(
  [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- bootstrap (preferencial)
$bootstrap = Join-Path $PSScriptRoot "_bootstrap.ps1"
if (Test-Path -LiteralPath $bootstrap) { . $bootstrap }

# --- fallbacks mínimos (se algo faltar no bootstrap)
if (-not (Get-Command WL -ErrorAction SilentlyContinue)) { function WL([string]$s){ Write-Host $s } }
if (-not (Get-Command EnsureDir -ErrorAction SilentlyContinue)) {
  function EnsureDir([string]$p) { if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }
}
if (-not (Get-Command WriteUtf8NoBom -ErrorAction SilentlyContinue)) {
  function WriteUtf8NoBom([string]$p, [string]$content) {
    $parent = Split-Path -Parent $p
    if ($parent) { EnsureDir $parent }
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($p, $content, $enc)
  }
}
if (-not (Get-Command BackupFile -ErrorAction SilentlyContinue)) {
  function BackupFile([string]$p) {
    if (Test-Path -LiteralPath $p) {
      $ts = (Get-Date -Format "yyyyMMdd_HHmmss")
      $bakDir = Join-Path (Get-Location) "tools\_patch_backup"
      EnsureDir $bakDir
      $leaf = Split-Path -Leaf $p
      Copy-Item -LiteralPath $p -Destination (Join-Path $bakDir ($leaf + "." + $ts + ".bak")) -Force
    }
  }
}
if (-not (Get-Command ResolveExe -ErrorAction SilentlyContinue)) {
  function ResolveExe([string]$name) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { return $cmd.Source }
    return $name
  }
}
if (-not (Get-Command RunNative -ErrorAction SilentlyContinue)) {
  function RunNative([string]$cwd, [string]$exe, [string[]]$cmdArgs) {
    $pretty = ($cmdArgs -join " ")
    WL ("[RUN] " + $exe + " " + $pretty)
    Push-Location $cwd
    & $exe @cmdArgs
    $code = $LASTEXITCODE
    Pop-Location
    if ($code -ne 0) { throw ("[STOP] comando falhou (exit " + $code + "): " + $exe + " " + $pretty) }
  }
}
if (-not (Get-Command ResolveRepoHere -ErrorAction SilentlyContinue)) {
  function ResolveRepoHere() {
    $here = (Get-Location).Path
    if (Test-Path -LiteralPath (Join-Path $here "package.json")) { return $here }
    throw ("[STOP] Rode na raiz do repo (onde tem package.json). Atual: " + $here)
  }
}
if (-not (Get-Command NewReport -ErrorAction SilentlyContinue)) {
  function NewReport([string]$fileName, [string]$content) {
    $repo = ResolveRepoHere
    $repDir = Join-Path $repo "reports"
    EnsureDir $repDir
    $p = Join-Path $repDir $fileName
    WriteUtf8NoBom $p $content
    return $p
  }
}

# -------------------------
# DIAG
# -------------------------
$repo = ResolveRepoHere
$npmExe = ResolveExe "npm.cmd"
$mdPath = Join-Path $repo "src\lib\markdown.ts"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] markdown: " + $mdPath)

if (-not (Test-Path -LiteralPath $mdPath)) {
  throw ("[STOP] Não achei markdown.ts em: " + $mdPath)
}

# -------------------------
# PATCH (rewrite total)
# -------------------------
BackupFile $mdPath

$ts = @(
'// Stable markdown renderer (no deps).',
'',
'export type MarkdownRenderOptions = {',
'  allowLinks?: boolean;',
'};',
'',
'function escapeHtml(s: string): string {',
'  return (s || "")',
'    .replace(/&/g, "&amp;")',
'    .replace(/</g, "&lt;")',
'    .replace(/>/g, "&gt;")',
'    .replace(/"/g, "&quot;")',
'    .replace(/''/g, "&#39;");',
'}',
'',
'function renderInline(s: string, allowLinks: boolean): string {',
'  let t = escapeHtml(s);',
'',
'  // inline code',
'  t = t.replace(/`([^`]+)`/g, "<code>$1</code>");',
'  // bold then italic (ordem importa)',
'  t = t.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");',
'  t = t.replace(/\*([^*]+)\*/g, "<em>$1</em>");',
'',
'  if (allowLinks) {',
'    t = t.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_m, text, url) => {',
'      const raw = String(url || "").trim();',
'      const allowed = /^(https?:\/\/|mailto:)/i.test(raw) ? raw : "#";',
'      const safeText = String(text || "");',
'      return "<a href=\"" + allowed + "\" target=\"_blank\" rel=\"noreferrer\">" + safeText + "</a>";',
'    });',
'  } else {',
'    t = t.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_m, text) => String(text || ""));',
'  }',
'',
'  return t;',
'}',
'',
'export function markdownToHtml(md: string, opts: MarkdownRenderOptions = {}): string {',
'  const allowLinks = opts.allowLinks !== false;',
'  const src = (md || "").replace(/\r\n?/g, "\n");',
'  const lines = src.split("\n");',
'',
'  const out: string[] = [];',
'  let inCode = false;',
'  const codeBuf: string[] = [];',
'  let listType: "" | "ul" | "ol" = "";',
'  const listBuf: string[] = [];',
'',
'  function flushList(): void {',
'    if (!listType) return;',
'    out.push("<" + listType + ">" + listBuf.join("") + "</" + listType + ">");',
'    listType = "";',
'    listBuf.length = 0;',
'  }',
'',
'  for (let i = 0; i < lines.length; i++) {',
'    const rawLine = lines[i];',
'    const line = rawLine == null ? "" : String(rawLine);',
'    const trimmed = line.trim();',
'',
'    if (trimmed.startsWith("```")) {',
'      if (inCode) {',
'        out.push("<pre><code>" + escapeHtml(codeBuf.join("\n")) + "</code></pre>");',
'        codeBuf.length = 0;',
'        inCode = false;',
'      } else {',
'        flushList();',
'        inCode = true;',
'      }',
'      continue;',
'    }',
'',
'    if (inCode) {',
'      codeBuf.push(line);',
'      continue;',
'    }',
'',
'    if (!trimmed) {',
'      flushList();',
'      continue;',
'    }',
'',
'    // headings',
'    if (/^#{1,6}\s+/.test(trimmed)) {',
'      flushList();',
'      const m = trimmed.match(/^(#{1,6})\s+(.*)$/);',
'      const level = m ? m[1].length : 2;',
'      const text = m ? m[2] : trimmed;',
'      out.push("<h" + level + ">" + renderInline(text, allowLinks) + "</h" + level + ">");',
'      continue;',
'    }',
'',
'    // blockquote',
'    if (trimmed.startsWith(">")) {',
'      flushList();',
'      const inner = trimmed.replace(/^>\s?/, "");',
'      out.push("<blockquote>" + renderInline(inner, allowLinks) + "</blockquote>");',
'      continue;',
'    }',
'',
'    // ordered list',
'    if (/^\d+\.\s+/.test(trimmed)) {',
'      const item = trimmed.replace(/^\d+\.\s+/, "");',
'      if (listType !== "ol") { flushList(); listType = "ol"; }',
'      listBuf.push("<li>" + renderInline(item, allowLinks) + "</li>");',
'      continue;',
'    }',
'',
'    // unordered list',
'    if (/^[-*]\s+/.test(trimmed)) {',
'      const item = trimmed.replace(/^[-*]\s+/, "");',
'      if (listType !== "ul") { flushList(); listType = "ul"; }',
'      listBuf.push("<li>" + renderInline(item, allowLinks) + "</li>");',
'      continue;',
'    }',
'',
'    // paragraph',
'    flushList();',
'    out.push("<p>" + renderInline(trimmed, allowLinks) + "</p>");',
'  }',
'',
'  if (inCode) {',
'    out.push("<pre><code>" + escapeHtml(codeBuf.join("\n")) + "</code></pre>");',
'  }',
'  flushList();',
'',
'  return out.join("\n");',
'}',
'',
'// compat: rota de aula importa esse nome',
'export const simpleMarkdownToHtml = markdownToHtml;',
''
) -join "`n"

WriteUtf8NoBom $mdPath $ts
WL "[OK] wrote: src/lib/markdown.ts (stable + alias export)"

# -------------------------
# REPORT (sem aspas escapadas)
# -------------------------
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$rep = @(
("# CV Hotfix — markdown.ts stable v0_22h — " + $now),
"",
"## O que foi feito",
"- Reescreveu src/lib/markdown.ts com renderer simples (sem dependencias).",
"- Links e regex com escapes seguros (sem over-escape).",
"- Exporta markdownToHtml e simpleMarkdownToHtml (alias p/ compat).",
"",
"## Verify",
"- npm run lint",
"- npm run build"
) -join "`n"

$repPath = NewReport "cv-hotfix-markdown-stable-v0_22h.md" $rep
WL ("[OK] Report: " + $repPath)

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
WL "[OK] Hotfix markdown aplicado (v0_22h)."