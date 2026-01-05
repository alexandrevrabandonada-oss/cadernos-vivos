# CV — V2 Extra — DeepLink por query (?q=) em Provas (e tentativa no Debate) — v0_37
# DIAG → PATCH → VERIFY → REPORT
$ErrorActionPreference = "Stop"

$toolsDir = if ($PSScriptRoot -and (Test-Path -LiteralPath $PSScriptRoot)) { $PSScriptRoot } else { Join-Path (Get-Location) "tools" }
$repo = (Resolve-Path (Join-Path $toolsDir "..")).Path
. (Join-Path $toolsDir "_bootstrap.ps1")

Write-Host ("[DIAG] Repo: " + $repo)

function WriteFileLines([string]$p, [string[]]$lines) {
  EnsureDir (Split-Path -Parent $p)
  WriteUtf8NoBom $p ($lines -join "`n")
}

# -----------------------
# 1) ProvasV2: aceitar initialQuery e iniciar q por prop (sem effect)
# -----------------------
$provasComp = Join-Path $repo "src\components\v2\ProvasV2.tsx"
if (Test-Path -LiteralPath $provasComp) {
  Write-Host ("[DIAG] ProvasV2: " + $provasComp)
  $raw = Get-Content -LiteralPath $provasComp -Raw
  if (-not $raw) { throw "[STOP] ProvasV2 vazio/ilegível." }

  $lines = $raw -split "`r?`n"
  $out = New-Object System.Collections.Generic.List[string]
  $changed = $false

  foreach ($ln in $lines) {
    $n = $ln

    # assinatura props: adiciona initialQuery?: string
    if ($n -match 'export default function ProvasV2\(props:\s*\{\s*slug:\s*string;\s*title:\s*string;\s*provas:\s*unknown\s*\}\s*\)') {
      $n = 'export default function ProvasV2(props: { slug: string; title: string; provas: unknown; initialQuery?: string }) {'
      $changed = $true
    }

    # destructuring
    if ($n -match 'const\s*\{\s*slug\s*,\s*title\s*,\s*provas\s*\}\s*=\s*props\s*;') {
      $n = '  const { slug, title, provas, initialQuery } = props;'
      $changed = $true
    }

    # init q
    if ($n -match 'const\s*\[\s*q\s*,\s*setQ\s*\]\s*=\s*useState<\s*string\s*>\(\s*""\s*\)\s*;') {
      $n = '  const [q, setQ] = useState<string>(() => (typeof initialQuery === "string" ? initialQuery : ""));'
      $changed = $true
    }

    $out.Add($n) | Out-Null
  }

  if ($changed) {
    $bk = BackupFile $provasComp
    WriteUtf8NoBom $provasComp ($out -join "`n")
    Write-Host "[OK] patched: ProvasV2 (initialQuery + init q)"
    if ($bk) { Write-Host ("[BK] " + $bk) }
  } else {
    Write-Host "[OK] ProvasV2: nada pra mudar (já tem initialQuery?)."
  }
} else {
  Write-Host "[WARN] Não achei ProvasV2.tsx — pulando."
}

# -----------------------
# 2) Page /v2/provas: ler ?q= e passar initialQuery
# -----------------------
$provasPage = Join-Path $repo "src\app\c\[slug]\v2\provas\page.tsx"
if (Test-Path -LiteralPath $provasPage) {
  Write-Host ("[DIAG] Provas page: " + $provasPage)
  $bk = BackupFile $provasPage

  $pageLines = @(
    'import V2Nav from "@/components/v2/V2Nav";',
    'import ProvasV2 from "@/components/v2/ProvasV2";',
    'import { loadCadernoV2 } from "@/lib/v2";',
    '',
    'function titleFromMeta(meta: unknown, fallback: string): string {',
    '  if (typeof meta !== "object" || meta === null) return fallback;',
    '  const r = meta as { title?: unknown };',
    '  return typeof r.title === "string" && r.title.trim() ? r.title : fallback;',
    '}',
    '',
    'function qFrom(search: unknown): string {',
    '  if (typeof search !== "object" || search === null) return "";',
    '  const r = search as { q?: unknown };',
    '  return typeof r.q === "string" ? r.q : "";',
    '}',
    '',
    'export default async function Page(props: { params: Promise<{ slug: string }>; searchParams?: Promise<unknown> }) {',
    '  const slug = (await props.params).slug;',
    '  const c = await loadCadernoV2(slug);',
    '',
    '  const meta = (c as unknown as { meta?: unknown }).meta;',
    '  const title = titleFromMeta(meta, slug);',
    '',
    '  const bag = c as unknown as { provas?: unknown; acervo?: unknown; evidencias?: unknown; docs?: unknown; links?: unknown };',
    '  const provas = bag.provas ?? bag.evidencias ?? bag.acervo ?? bag.docs ?? bag.links ?? null;',
    '',
    '  const sp = props.searchParams ? await props.searchParams : null;',
    '  const initialQuery = qFrom(sp);',
    '',
    '  return (',
    '    <main style={{ padding: 18 }}>',
    '      <V2Nav slug={slug} active="provas" />',
    '      <ProvasV2 slug={slug} title={title} provas={provas} initialQuery={initialQuery} />',
    '    </main>',
    '  );',
    '}'
  )

  WriteFileLines $provasPage $pageLines
  Write-Host "[OK] wrote: /v2/provas/page.tsx (support ?q=)"
  if ($bk) { Write-Host ("[BK] " + $bk) }
} else {
  Write-Host "[WARN] Não achei v2/provas/page.tsx — pulando."
}

# -----------------------
# 3) Tentativa opcional: DebateV2 aceitar initialQuery (se existir e tiver q)
# -----------------------
$debComp = Join-Path $repo "src\components\v2\DebateV2.tsx"
if (Test-Path -LiteralPath $debComp) {
  Write-Host ("[DIAG] DebateV2: " + $debComp)
  $raw = Get-Content -LiteralPath $debComp -Raw
  if ($raw) {
    $did = $false
    $lines = $raw -split "`r?`n"
    $out = New-Object System.Collections.Generic.List[string]

    foreach ($ln in $lines) {
      $n = $ln

      # assinatura com props tipados: tenta acrescentar initialQuery?: string
      if ($n -match 'export default function DebateV2\(props:\s*\{') {
        if ($raw -notmatch 'initialQuery\?:\s*string') {
          # só injeta se for a linha da assinatura "export default function DebateV2(props: {"
          $n = $n.Replace('props: {', 'props: { initialQuery?: string; ')
          $did = $true
        }
      }

      # se existir destructuring { slug, title, debate } etc, tenta incluir initialQuery
      if ($n -match 'const\s*\{\s*([^}]*)\}\s*=\s*props\s*;') {
        if ($n -notmatch 'initialQuery') {
          $n = $n.Replace('} = props;', ', initialQuery } = props;')
          $did = $true
        }
      }

      # se achar q state padrão, inicializa por prop
      if ($n -match 'const\s*\[\s*q\s*,\s*setQ\s*\]\s*=\s*useState<\s*string\s*>\(\s*""\s*\)\s*;') {
        $n = '  const [q, setQ] = useState<string>(() => (typeof initialQuery === "string" ? initialQuery : ""));'
        $did = $true
      }

      $out.Add($n) | Out-Null
    }

    if ($did) {
      $bk = BackupFile $debComp
      WriteUtf8NoBom $debComp ($out -join "`n")
      Write-Host "[OK] patched: DebateV2 (initialQuery best-effort)"
      if ($bk) { Write-Host ("[BK] " + $bk) }
    } else {
      Write-Host "[SKIP] DebateV2: não achei padrão seguro pra mexer."
    }
  }
} else {
  Write-Host "[SKIP] DebateV2.tsx não existe — ok."
}

# -----------------------
# 4) Debate page: passar ?q= se o componente suportar (best-effort)
# -----------------------
$debPage = Join-Path $repo "src\app\c\[slug]\v2\debate\page.tsx"
if (Test-Path -LiteralPath $debPage) {
  $raw = Get-Content -LiteralPath $debPage -Raw
  if ($raw -and $raw.Contains("<DebateV2")) {
    Write-Host ("[DIAG] Debate page: " + $debPage)

    $o = $raw
    # garantir params Promise (se ainda não estiver)
    $o = $o.Replace("props.params.", "(await props.params).")

    # injeta leitura de searchParams e prop initialQuery se ainda não existir
    if ($o -notmatch 'searchParams' -and $o -notmatch 'initialQuery') {
      # tenta inserir após loadCadernoV2
      $marker = 'const c = await loadCadernoV2(slug);'
      if ($o.Contains($marker)) {
        $insert = $marker + "`n`n" +
          '  const sp = (props as unknown as { searchParams?: Promise<unknown> }).searchParams ? await (props as unknown as { searchParams?: Promise<unknown> }).searchParams : null;' + "`n" +
          '  const initialQuery = (typeof sp === "object" && sp !== null && typeof (sp as { q?: unknown }).q === "string") ? String((sp as { q?: unknown }).q) : "";'
        $o = $o.Replace($marker, $insert)
      }
      # tenta adicionar prop no JSX
      $o = $o.Replace("<DebateV2 ", "<DebateV2 initialQuery={initialQuery} ")
    }

    if ($o -ne $raw) {
      $bk = BackupFile $debPage
      WriteUtf8NoBom $debPage $o
      Write-Host "[OK] patched: Debate page (best-effort ?q=)"
      if ($bk) { Write-Host ("[BK] " + $bk) }
    } else {
      Write-Host "[OK] Debate page: nada pra mudar."
    }
  }
}

# VERIFY
RunPs1 (Join-Path $repo "tools\cv-verify.ps1")

# REPORT (sem crases)
$rep = @(
  '# CV — V2 Extra v0_37 — Deep links por query (?q=)',
  '',
  '## O que entrou',
  '- ProvasV2 aceita initialQuery e inicia a busca por prop (sem effect).',
  '- /v2/provas lê ?q= (searchParams) e passa initialQuery.',
  '- Tentativa best-effort para Debate (component/page) se já existir padrão de q.',
  '',
  '## Como usar',
  '- /c/SEU-SLUG/v2/provas?q=palavra',
  '- /c/SEU-SLUG/v2/provas#id (continua funcionando)',
  '',
  '## Verify',
  '- tools/cv-verify.ps1 (guard + lint + build)',
  ''
) -join "`n"

WriteReport "cv-v2-extra-deeplink-q-v0_37.md" $rep | Out-Null
Write-Host "[OK] v0_37 aplicado e verificado."