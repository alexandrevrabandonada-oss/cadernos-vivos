param(
  [switch]$SkipBuild,
  [switch]$SkipLint
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function __HasCmd($n) { return [bool](Get-Command $n -ErrorAction SilentlyContinue) }

if (Test-Path -LiteralPath (Join-Path (Get-Location) "tools\_bootstrap.ps1")) {
  . (Join-Path (Get-Location) "tools\_bootstrap.ps1")
}

if (-not (__HasCmd "WL")) { function WL([string]$s) { Write-Host $s } }
if (-not (__HasCmd "EnsureDir")) { function EnsureDir([string]$p) { if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } } }
if (-not (__HasCmd "WriteUtf8NoBom")) {
  function WriteUtf8NoBom([string]$p, [string]$content) {
    $parent = Split-Path -Parent $p
    if ($parent) { EnsureDir $parent }
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($p, $content, $enc)
  }
}
if (-not (__HasCmd "BackupFile")) {
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
if (-not (__HasCmd "ResolveExe")) {
  function ResolveExe([string]$name) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { return $cmd.Source }
    return $name
  }
}
if (-not (__HasCmd "RunNative")) {
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
if (-not (__HasCmd "NewReport")) {
  function NewReport([string]$name, [string]$content) {
    $repo = (Get-Location).Path
    $repDir = Join-Path $repo "reports"
    EnsureDir $repDir
    $p = Join-Path $repDir $name
    WriteUtf8NoBom $p $content
    return $p
  }
}

function ResolveRepoHere() {
  $here = (Get-Location).Path
  if (Test-Path -LiteralPath (Join-Path $here "package.json")) { return $here }
  throw ("[STOP] Rode na raiz do repo (onde tem package.json). Atual: " + $here)
}

# -------------------------
# DIAG
# -------------------------
$repo = ResolveRepoHere
$npmExe = ResolveExe "npm.cmd"
$markdownPath = Join-Path $repo "src\lib\markdown.ts"

WL ("[DIAG] Repo: " + $repo)
WL ("[DIAG] npm: " + $npmExe)
WL ("[DIAG] markdown: " + $markdownPath)

if (-not (Test-Path -LiteralPath $markdownPath)) {
  throw ("[STOP] Não achei: " + $markdownPath)
}

# -------------------------
# PATCH (rewrite stable)
# -------------------------
BackupFile $markdownPath

$ts = @(
'export type MarkdownOptions = {',
'  target?: "_blank" | "_self";',
'};',
'',
'const DEFAULT_OPTS: Required<MarkdownOptions> = { target: "_blank" };',
'',
'function escapeHtml(s: string): string {',
'  return String(s ?? "")',
'    .replace(/&/g, "&amp;")',
'    .replace(/</g, "&lt;")',
'    .replace(/>/g, "&gt;");',
'}',
'',
'function escapeAttr(s: string): string {',
'  return escapeHtml(s).replace(/"/g, "&quot;");',
'}',
'',
'function sanitizeHref(raw: string): string {',
'  const u = String(raw ?? "").trim();',
'  if (!u) return "";',
'  if (u.startsWith("#") || u.startsWith("/")) return u;',
'  if (u.startsWith("mailto:")) return u;',
'  if (u.startsWith("https://") || u.startsWith("http://")) return u;',
'  return "";',
'}',
'',
'function inline(md: string, opts: Required<MarkdownOptions>): string {',
'  let t = escapeHtml(md);',
'',
'  // links [text](url)',
'  t = t.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_m, text, href) => {',
'    const safe = sanitizeHref(String(href));',
'    const label = String(text);',
'    if (!safe) return label;',
'    const targetAttr = opts.target === "_blank" ? '' target="_blank" rel="noreferrer noopener"'' : "";',
'    return `<a href="${escapeAttr(safe)}"${targetAttr}>${label}</a>`;',
'  });',
'',
'  // inline code',
'  t = t.replace(/`([^`]+)`/g, (_m, code) => `<code>${code}</code>`);',
'',
'  // bold / italic (simple)',
'  t = t.replace(/\*\*([^*]+)\*\*/g, (_m, b) => `<strong>${b}</strong>`);',
'  t = t.replace(/\*([^*]+)\*/g, (_m, i) => `<em>${i}</em>`);',
'',
'  return t;',
'}',
'',
'export async function markdownToHtml(markdown: string, options?: MarkdownOptions): Promise<string> {',
'  const opts: Required<MarkdownOptions> = { ...DEFAULT_OPTS, ...(options || {}) };',
'  const src = String(markdown || "").replace(/\r\n/g, "\n");',
'  const lines = src.split("\n");',
'',
'  const out: string[] = [];',
'  let inCode = false;',
'  let list: "ul" | "ol" | null = null;',
'',
'  const closeList = () => {',
'    if (list) {',
'      out.push(`</${list}>`);',
'      list = null;',
'    }',
'  };',
'',
'  for (const rawLine of lines) {',
'    const line = rawLine ?? "";',
'',
'    // fenced code ```',
'    if (/^```/.test(line)) {',
'      if (!inCode) {',
'        closeList();',
'        inCode = true;',
'        out.push("<pre><code>");',
'      } else {',
'        inCode = false;',
'        out.push("</code></pre>");',
'      }',
'      continue;',
'    }',
'',
'    if (inCode) {',
'      out.push(escapeHtml(line));',
'      continue;',
'    }',
'',
'    const trimmed = line.trim();',
'    if (!trimmed) {',
'      closeList();',
'      continue;',
'    }',
'',
'    const h = line.match(/^(#{1,6})\s+(.*)$/);',
'    if (h) {',
'      closeList();',
'      const level = h[1].length;',
'      out.push(`<h${level}>${inline(h[2], opts)}</h${level}>`);',
'      continue;',
'    }',
'',
'    const ul = line.match(/^[-*]\s+(.*)$/);',
'    if (ul) {',
'      if (list !== "ul") {',
'        closeList();',
'        list = "ul";',
'        out.push("<ul>");',
'      }',
'      out.push(`<li>${inline(ul[1], opts)}</li>`);',
'      continue;',
'    }',
'',
'    const ol = line.match(/^\d+\.\s+(.*)$/);',
'    if (ol) {',
'      if (list !== "ol") {',
'        closeList();',
'        list = "ol";',
'        out.push("<ol>");',
'      }',
'      out.push(`<li>${inline(ol[1], opts)}</li>`);',
'      continue;',
'    }',
'',
'    closeList();',
'    out.push(`<p>${inline(line, opts)}</p>`);',
'  }',
'',
'  if (inCode) out.push("</code></pre>");',
'  closeList();',
'',
'  return out.join("\n");',
'}',
'',
'// aliases para imports antigos',
'export async function mdToHtml(markdown: string, options?: MarkdownOptions): Promise<string> {',
'  return markdownToHtml(markdown, options);',
'}',
'',
'export async function simpleMarkdownToHtml(markdown: string, options?: MarkdownOptions): Promise<string> {',
'  return markdownToHtml(markdown, options);',
'}',
''
) -join "`n"

WriteUtf8NoBom $markdownPath $ts
WL "[OK] wrote: src/lib/markdown.ts (stable + aliases)"

# -------------------------
# REPORT
# -------------------------
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$rep = @(
("# CV Hotfix — Markdown exports v0.23 — " + $now),
"",
"## O que foi feito",
"- Reescreveu src/lib/markdown.ts com parser simples e estável",
"- Exporta markdownToHtml() e também aliases mdToHtml() e simpleMarkdownToHtml()",
"- Evita strings quebradas com barras e aspas",
"",
"## Motivo",
"- Build estava falhando por imports esperando mdToHtml/simpleMarkdownToHtml sem export correspondente"
) -join "`n"

$repPath = NewReport "cv-hotfix-markdown-exports-v0_23.md" $rep
WL ("[OK] Report: " + $repPath)

# -------------------------
# VERIFY
# -------------------------
if (-not $SkipLint) {
  WL "[VERIFY] npm run lint..."
  RunNative $repo $npmExe @("run","lint")
} else {
  WL "[VERIFY] lint pulado (-SkipLint)."
}

if (-not $SkipBuild) {
  WL "[VERIFY] npm run build..."
  RunNative $repo $npmExe @("run","build")
} else {
  WL "[VERIFY] build pulado (-SkipBuild)."
}

WL "[OK] Hotfix Markdown v0.23 aplicado."