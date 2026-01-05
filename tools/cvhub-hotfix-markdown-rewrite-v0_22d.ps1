param(
  [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function TestP([string]$p){ Test-Path -LiteralPath $p }

function ResolveRepoHere() {
  $here = (Get-Location).Path
  if (TestP (Join-Path $here "package.json")) { return $here }
  throw ("[STOP] Rode na raiz do repo (package.json). Atual: " + $here)
}

$repo = ResolveRepoHere
$boot = Join-Path $repo "tools\_bootstrap.ps1"
if (TestP $boot) { . $boot }

# fallbacks mínimos
if (-not (Get-Command WL -ErrorAction SilentlyContinue)) { function WL([string]$s){ Write-Host $s } }
if (-not (Get-Command EnsureDir -ErrorAction SilentlyContinue)) { function EnsureDir([string]$p){ if (-not (TestP $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } } }
if (-not (Get-Command WriteUtf8NoBom -ErrorAction SilentlyContinue)) {
  function WriteUtf8NoBom([string]$p,[string]$content){
    $parent = Split-Path -Parent $p
    if ($parent) { EnsureDir $parent }
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($p, $content, $enc)
  }
}
if (-not (Get-Command BackupFile -ErrorAction SilentlyContinue)) {
  function BackupFile([string]$p){
    if (TestP $p) {
      $ts = (Get-Date -Format "yyyyMMdd_HHmmss")
      $bakDir = Join-Path (Get-Location) "tools\_patch_backup"
      EnsureDir $bakDir
      $leaf = Split-Path -Leaf $p
      Copy-Item -LiteralPath $p -Destination (Join-Path $bakDir ($leaf + "." + $ts + ".bak")) -Force
    }
  }
}
if (-not (Get-Command ResolveExe -ErrorAction SilentlyContinue)) {
  function ResolveExe([string]$name){
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { return $cmd.Source }
    return $name
  }
}
if (-not (Get-Command RunNative -ErrorAction SilentlyContinue)) {
  function RunNative([string]$cwd,[string]$exe,[string[]]$args){
    WL ("[RUN] " + $exe + " " + ($args -join " "))
    Push-Location $cwd
    & $exe @args
    $code = $LASTEXITCODE
    Pop-Location
    if ($code -ne 0) { throw ("[STOP] comando falhou (exit " + $code + ")") }
  }
}
if (-not (Get-Command NewReport -ErrorAction SilentlyContinue)) {
  function NewReport([string]$name,[string]$content){
    $repDir = Join-Path $repo "reports"
    EnsureDir $repDir
    $p = Join-Path $repDir $name
    WriteUtf8NoBom $p $content
    return $p
  }
}

$npmExe = ResolveExe "npm.cmd"
$mdLibPath = Join-Path $repo "src\lib\markdown.ts"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] markdown lib: " + $mdLibPath)

EnsureDir (Split-Path -Parent $mdLibPath)
BackupFile $mdLibPath

# Reescreve markdown.ts inteiro (PS-safe)
$ts = @(
'// Auto-generated (hotfix) — markdown renderer minimalista e estável.',
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
'  // primeiro escapa tudo',
'  let t = escapeHtml(s);',
'',
'  // code `x`',
'  t = t.replace(/`([^`]+)`/g, "<code>$1</code>");',
'',
'  // bold **x**',
'  t = t.replace(/\\*\\*([^*]+?)\\*\\*/g, "<strong>$1</strong>");',
'',
'  // italic *x* (simples, sem cobrir todos os casos complexos)',
'  t = t.replace(/(^|[^*])\\*([^*]+?)\\*(?!\\*)/g, "$1<em>$2</em>");',
'',
'  // links [texto](url)',
'  t = t.replace(/\\[([^\\]]+)\\]\\(([^)]+)\\)/g, function (_m: string, text: string, url: string) {',
'    const safeText = text;',
'    const safeUrl = url.replace(/\\s+/g, "");',
'    return "<a href=\\"" + safeUrl + "\\" target=\\"_blank\\" rel=\\"noreferrer\\">" + safeText + "</a>";',
'  });',
'',
'  return t;',
'}',
'',
'function renderBlocks(md: string): string {',
'  const src = (md || "").replace(/\\r\\n/g, "\\n");',
'  const lines = src.split("\\n");',
'',
'  let out: string[] = [];',
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
'    const body = escapeHtml(codeBuf.join("\\n"));',
'    out.push("<pre><code>" + body + "</code></pre>");',
'    codeBuf = [];',
'    inCode = false;',
'  }',
'',
'  for (let i = 0; i < lines.length; i++) {',
'    const raw = lines[i];',
'    const line = raw.trimEnd();',
'',
'    // fences ```',
'    if (line.startsWith("```")) {',
'      if (inCode) { flushCode(); } else { flushList(); inCode = true; codeBuf = []; }',
'      continue;',
'    }',
'',
'    if (inCode) {',
'      codeBuf.push(raw);',
'      continue;',
'    }',
'',
'    if (line.trim() === "") {',
'      flushList();',
'      continue;',
'    }',
'',
'    // headings',
'    if (line.startsWith("# ")) { flushList(); out.push("<h1>" + inline(line.slice(2).trim()) + "</h1>"); continue; }',
'    if (line.startsWith("## ")) { flushList(); out.push("<h2>" + inline(line.slice(3).trim()) + "</h2>"); continue; }',
'    if (line.startsWith("### ")) { flushList(); out.push("<h3>" + inline(line.slice(4).trim()) + "</h3>"); continue; }',
'',
'    // blockquote',
'    if (line.startsWith(">")) { flushList(); out.push("<blockquote>" + inline(line.replace(/^>\\s?/, "")) + "</blockquote>"); continue; }',
'',
'    // unordered list',
'    if (line.startsWith("- ") || line.startsWith("* ")) {',
'      if (inOl) { out.push("</ol>"); inOl = false; }',
'      if (!inUl) { out.push("<ul>"); inUl = true; }',
'      out.push("<li>" + inline(line.slice(2).trim()) + "</li>");',
'      continue;',
'    }',
'',
'    // ordered list "1. x"',
'    if (/^\\d+\\.\\s+/.test(line)) {',
'      if (inUl) { out.push("</ul>"); inUl = false; }',
'      if (!inOl) { out.push("<ol>"); inOl = true; }',
'      const item = line.replace(/^\\d+\\.\\s+/, "");',
'      out.push("<li>" + inline(item.trim()) + "</li>");',
'      continue;',
'    }',
'',
'    // paragraph',
'    flushList();',
'    out.push("<p>" + inline(line.trim()) + "</p>");',
'  }',
'',
'  flushCode();',
'  flushList();',
'  return out.join("\\n");',
'}',
'',
'export function renderMarkdown(md: string): string {',
'  return renderBlocks(md);',
'}',
'',
'// aliases pra compatibilidade com imports antigos',
'export const markdownToHtml = renderMarkdown;',
'export const mdToHtml = renderMarkdown;',
'export default renderMarkdown;',
''
) -join "`n"

WriteUtf8NoBom $mdLibPath $ts
WL "[OK] wrote: src/lib/markdown.ts (rewrite estável)"

# REPORT
$rep = @()
$rep += ('# Hotfix — markdown.ts rewrite v0.22d — ' + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
$rep += ''
$rep += '## O que foi feito'
$rep += '- Reescreveu src/lib/markdown.ts inteiro com renderer minimalista.'
$rep += '- Inclui suporte: headings, paragrafos, listas, blockquote, code fences, inline code, bold/italic e links.'
$rep += '- Exporta aliases: renderMarkdown, markdownToHtml, mdToHtml e default.'
$repPath = NewReport "cv-hotfix-markdown-rewrite-v0_22d.md" ($rep -join "`n")
WL ("[OK] Report: " + $repPath)

# VERIFY
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