param(
  [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function ResolveRepoHereLocal() {
  $here = (Get-Location).Path
  if (Test-Path -LiteralPath (Join-Path $here "package.json")) { return $here }
  throw ("[STOP] Rode na raiz do repo (onde tem package.json). Atual: " + $here)
}

$repo = ResolveRepoHereLocal
$boot = Join-Path $repo "tools\_bootstrap.ps1"
if (Test-Path -LiteralPath $boot) { . $boot }

# fallbacks
if (-not (Get-Command WL -ErrorAction SilentlyContinue)) { function WL([string]$s) { Write-Host $s } }
if (-not (Get-Command EnsureDir -ErrorAction SilentlyContinue)) { function EnsureDir([string]$p) { if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } } }
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
      $bakDir = Join-Path $repo "tools\_patch_backup"
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
if (-not (Get-Command NewReport -ErrorAction SilentlyContinue)) {
  function NewReport([string]$name, [string[]]$lines) {
    $repDir = Join-Path $repo "reports"
    EnsureDir $repDir
    $p = Join-Path $repDir $name
    WriteUtf8NoBom $p ($lines -join "`n")
    return $p
  }
}

$npmExe = ResolveExe "npm.cmd"
$mdPath = Join-Path $repo "src\lib\markdown.ts"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] markdown: " + $mdPath)

BackupFile $mdPath

# Reescreve markdown.ts com exports compatíveis (inclui simpleMarkdownToHtml)
$lines = @(
'// Auto-generated (hotfix) - markdown renderer minimalista e estavel.',
'',
'function escapeHtml(input: string): string {',
'  return (input || "")',
'    .replace(/&/g, "&amp;")',
'    .replace(/</g, "&lt;")',
'    .replace(/>/g, "&gt;")',
'    .replace(/"/g, "&quot;")',
"    .replace(/'/g, '&#39;');",
'}',
'',
'function inline(s: string): string {',
'  let t = escapeHtml(s);',
'',
'  // code `x`',
'  t = t.replace(/`([^`]+)`/g, "<code>$1</code>");',
'',
'  // bold **x**',
'  t = t.replace(/\*\*([^*]+?)\*\*/g, "<strong>$1</strong>");',
'',
'  // italic *x* (simples)',
'  t = t.replace(/(^|[^*])\*([^*]+?)\*(?!\*)/g, "$1<em>$2</em>");',
'',
'  // links [texto](url)',
'  t = t.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_m, text, url) => {',
'    const rawUrl = String(url || "").replace(/\s+/g, "");',
'    const allowed = /^(https?:\/\/|mailto:)/i.test(rawUrl) ? rawUrl : "#";',
'    return "<a href=\\"" + allowed + "\\" target=\\"_blank\\" rel=\\"noreferrer\\">" + String(text || "") + "</a>";',
'  });',
'',
'  return t;',
'}',
'',
'function renderBlocks(md: string): string {',
'  const src = (md || "").replace(/\r\n/g, "\n");',
'  const lines = src.split("\n");',
'',
'  const out: string[] = [];',
'  let inCode = false;',
'  let codeBuf: string[] = [];',
'  let inUl = false;',
'  let inOl = false;',
'',
'  function flushList(): void {',
'    if (inUl) { out.push("</ul>"); inUl = false; }',
'    if (inOl) { out.push("</ol>"); inOl = false; }',
'  }',
'',
'  function flushCode(): void {',
'    if (!inCode) return;',
'    const body = escapeHtml(codeBuf.join("\n"));',
'    out.push("<pre><code>" + body + "</code></pre>");',
'    codeBuf = [];',
'    inCode = false;',
'  }',
'',
'  for (let i = 0; i < lines.length; i++) {',
'    const raw = lines[i];',
'    const line = raw.trimEnd();',
'',
'    if (line.startsWith("```")) {',
'      if (inCode) { flushCode(); } else { flushList(); inCode = true; codeBuf = []; }',
'      continue;',
'    }',
'',
'    if (inCode) { codeBuf.push(raw); continue; }',
'',
'    if (line.trim() === "") { flushList(); continue; }',
'',
'    if (line.startsWith("# ")) { flushList(); out.push("<h1>" + inline(line.slice(2).trim()) + "</h1>"); continue; }',
'    if (line.startsWith("## ")) { flushList(); out.push("<h2>" + inline(line.slice(3).trim()) + "</h2>"); continue; }',
'    if (line.startsWith("### ")) { flushList(); out.push("<h3>" + inline(line.slice(4).trim()) + "</h3>"); continue; }',
'',
'    if (line.startsWith(">")) { flushList(); out.push("<blockquote>" + inline(line.replace(/^>\\s?/, "")) + "</blockquote>"); continue; }',
'',
'    if (line.startsWith("- ") || line.startsWith("* ")) {',
'      if (inOl) { out.push("</ol>"); inOl = false; }',
'      if (!inUl) { out.push("<ul>"); inUl = true; }',
'      out.push("<li>" + inline(line.slice(2).trim()) + "</li>");',
'      continue;',
'    }',
'',
'    if (/^\\d+\\.\\s+/.test(line)) {',
'      if (inUl) { out.push("</ul>"); inUl = false; }',
'      if (!inOl) { out.push("<ol>"); inOl = true; }',
'      const item = line.replace(/^\\d+\\.\\s+/, "");',
'      out.push("<li>" + inline(item.trim()) + "</li>");',
'      continue;',
'    }',
'',
'    flushList();',
'    out.push("<p>" + inline(line.trim()) + "</p>");',
'  }',
'',
'  flushCode();',
'  flushList();',
'  return out.join("\n");',
'}',
'',
'export function renderMarkdown(md: string): string {',
'  return renderBlocks(md);',
'}',
'',
'// Aliases compatíveis (páginas antigas / engines)',
'export const simpleMarkdownToHtml = renderMarkdown;',
'export const markdownToHtml = renderMarkdown;',
'export const mdToHtml = renderMarkdown;',
'export default renderMarkdown;',
''
)

WriteUtf8NoBom $mdPath ($lines -join "`n")
WL "[OK] patched: src/lib/markdown.ts (exports + allowed used)"

$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$rep = @(
  ("# CV Hotfix - Markdown export alias v0.22f - " + $now),
  "",
  "## O que fez",
  "- Reescreveu src/lib/markdown.ts mantendo renderer estável.",
  "- Exporta simpleMarkdownToHtml (alias) + markdownToHtml/mdToHtml/default.",
  "- Corrigiu warning de variavel 'allowed' (agora é usada no retorno do link).",
  "",
  "## Verify",
  "- npm run lint",
  "- npm run build (a menos que -SkipBuild)"
)
$repPath = NewReport "cv-hotfix-markdown-export-alias-v0_22f.md" $rep
WL ("[OK] Report: " + $repPath)

WL "[VERIFY] npm run lint..."
RunNative $repo $npmExe @("run","lint")

if (-not $SkipBuild) {
  WL "[VERIFY] npm run build..."
  RunNative $repo $npmExe @("run","build")
} else {
  WL "[VERIFY] build pulado (-SkipBuild)."
}

WL "[OK] Hotfix aplicado: export simpleMarkdownToHtml OK."