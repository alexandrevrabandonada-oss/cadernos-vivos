$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Write-Host ("[DIAG] Repo: " + $repo)

. (Join-Path $PSScriptRoot "_bootstrap.ps1")

$changed = New-Object System.Collections.Generic.List[string]

function PatchText([string]$rel, [scriptblock]$mutate) {
  $full = Join-Path $repo $rel
  if (!(Test-Path -LiteralPath $full)) {
    Write-Host ("[SKIP] nao achei: " + $full)
    return
  }
  $raw = Get-Content -LiteralPath $full -Raw
  if ($null -eq $raw) { throw ("[STOP] leitura nula: " + $full) }

  $next = & $mutate $raw
  if ($null -eq $next) { throw "[STOP] mutate retornou null" }

  if ($next -ne $raw) {
    $bk = BackupFile $full
    WriteUtf8NoBom $full $next
    Write-Host ("[OK] patched: " + $full)
    Write-Host ("[BK] " + $bk)
    $script:changed.Add($full) | Out-Null
  } else {
    Write-Host ("[OK] sem mudanca: " + $full)
  }
}

function WriteLines([string]$rel, [string[]]$lines) {
  $full = Join-Path $repo $rel
  EnsureDir (Split-Path -Parent $full)
  $next = ($lines -join "`r`n")
  if (Test-Path -LiteralPath $full) {
    $raw = Get-Content -LiteralPath $full -Raw
    if ($null -eq $raw) { $raw = "" }
    if ($raw -eq $next) {
      Write-Host ("[OK] sem mudanca: " + $full)
      return
    }
    $bk = BackupFile $full
    WriteUtf8NoBom $full $next
    Write-Host ("[OK] wrote: " + $full)
    Write-Host ("[BK] " + $bk)
  } else {
    WriteUtf8NoBom $full $next
    Write-Host ("[OK] wrote: " + $full)
  }
  $script:changed.Add($full) | Out-Null
}

# 1) MapaV2: padronizar tudo em idx (mata o “Cannot find _idx/idx”)
PatchText "src\components\v2\MapaV2.tsx" {
  param($s)
  $out = $s

  # map callbacks: (n, _idx) => (n, idx)
  $out = $out.Replace("nodes.map((n, _idx) =>", "nodes.map((n, idx) =>")
  $out = $out.Replace("nodes.map((n,_idx) =>", "nodes.map((n, idx) =>")
  $out = $out.Replace("nodes.map((n,_idx)=>", "nodes.map((n, idx) =>")
  $out = $out.Replace("nodes.map((n, _idx)=>", "nodes.map((n, idx) =>")

  # usos: _idx -> idx (somente expressões comuns)
  $out = $out.Replace("((_idx % 5)", "((idx % 5)")
  $out = $out.Replace("(Math.floor(_idx / 5)", "(Math.floor(idx / 5)")
  $out = $out.Replace("(_idx % 5)", "(idx % 5)")
  $out = $out.Replace("Math.floor(_idx / 5)", "Math.floor(idx / 5)")

  return $out
}

# 2) HomeV2Hub: versão estável (useSyncExternalStore) sem setState em effect
$homeLines = @(
'"use client";',
'',
'import React, { useMemo, useSyncExternalStore } from "react";',
'import Link from "next/link";',
'',
'function useLocalStorageString(key: string): string {',
'  const subscribe = (cb: () => void) => {',
'    if (typeof window === "undefined") return () => {};',
'    const h: EventListener = () => cb();',
'    window.addEventListener("storage", h);',
'    window.addEventListener("cv:ls", h);',
'    return () => {',
'      window.removeEventListener("storage", h);',
'      window.removeEventListener("cv:ls", h);',
'    };',
'  };',
'  const getSnap = () => {',
'    try {',
'      return localStorage.getItem(key) || "";',
'    } catch {',
'      return "";',
'    }',
'  };',
'  return useSyncExternalStore(subscribe, getSnap, () => "");',
'}',
'',
'function normalizeLastHref(slug: string, v: string): string {',
'  const base = "/c/" + slug + "/v2";',
'  if (!v) return base;',
'  if (typeof v !== "string") return base;',
'  if (v.startsWith("/c/" + slug)) return v;',
'  return base;',
'}',
'',
'export default function HomeV2Hub(props: { slug: string; title: string }) {',
'  const key = "cv:last:" + props.slug;',
'  const lastRaw = useLocalStorageString(key);',
'  const lastHref = useMemo(() => normalizeLastHref(props.slug, lastRaw), [props.slug, lastRaw]);',
'',
'  const cards = useMemo(() => {',
'    const s = props.slug;',
'    return [',
'      { href: "/c/" + s + "/v2/mapa", title: "Mapa", desc: "Mapa mental conectado (nós e links)." },',
'      { href: "/c/" + s + "/v2/linha-do-tempo", title: "Linha do tempo", desc: "Eventos e memórias em sequência." },',
'      { href: "/c/" + s + "/v2/trilhas", title: "Trilhas", desc: "Roteiros guiados de estudo e ação." },',
'      { href: "/c/" + s + "/v2/provas", title: "Provas", desc: "Documentos, fontes e evidências." },',
'      { href: "/c/" + s + "/v2/debate", title: "Debate", desc: "Camadas de conversa por tema/nó." },',
'    ];',
'  }, [props.slug]);',
'',
'  return (',
'    <section className="w-full max-w-6xl mx-auto px-4 py-8">',
'      <div className="mb-6 flex items-start justify-between gap-4">',
'        <div>',
'          <h1 className="text-2xl font-semibold tracking-tight">{props.title}</h1>',
'          <p className="text-sm opacity-80">Concreto Zen (V2) — navegação por mapas, trilhas, provas e debate.</p>',
'        </div>',
'        <div className="flex items-center gap-2">',
'          <Link href={lastHref} className="text-xs px-3 py-2 rounded-md border border-black/15 dark:border-white/15 hover:opacity-90">',
'            Continuar',
'          </Link>',
'        </div>',
'      </div>',
'',
'      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">',
'        {cards.map((c) => (',
'          <Link key={c.href} href={c.href} className="rounded-xl border border-black/10 dark:border-white/10 bg-white/70 dark:bg-black/25 p-4 hover:opacity-95">',
'            <div className="flex items-start justify-between gap-3">',
'              <h2 className="text-base font-semibold">{c.title}</h2>',
'              <span className="text-[10px] uppercase tracking-wider px-2 py-1 rounded-full border border-current/25 opacity-70">v2</span>',
'            </div>',
'            <p className="mt-2 text-sm opacity-85">{c.desc}</p>',
'          </Link>',
'        ))}',
'      </div>',
'',
'      <p className="mt-6 text-xs opacity-70">',
'        Dica: pages V2 podem salvar o ultimo lugar no localStorage usando a chave <span className="font-mono">{key}</span>.',
'      </p>',
'    </section>',
'  );',
'}'
)
WriteLines "src\components\v2\HomeV2Hub.tsx" $homeLines

# 3) /c/[slug]/page.tsx: usar uiDefault e redirect (remove warnings)
PatchText "src\app\c\[slug]\page.tsx" {
  param($s)
  $out = $s

  # garantir redirect no import do next/navigation
  $mImp = [regex]::Match($out, 'import\s*\{\s*([^}]*)\s*\}\s*from\s*"next/navigation";')
  if ($mImp.Success) {
    $inner = $mImp.Groups[1].Value
    if ($inner -notmatch '\bredirect\b') {
      $inner2 = $inner.Trim()
      if ($inner2.Length -gt 0 -and !$inner2.Trim().EndsWith(",")) { $inner2 = $inner2 + "," }
      if ($inner2.Length -gt 0) { $inner2 = $inner2 + " " }
      $inner2 = $inner2 + "redirect"
      $newImp = 'import { ' + $inner2 + ' } from "next/navigation";'
      $out = $out.Substring(0, $mImp.Index) + $newImp + $out.Substring($mImp.Index + $mImp.Length)
    }
  }

  # se já existe bloco de redirect por uiDefault, não mexe
  if ($out.IndexOf('uiDefault === "v2"') -ge 0 -and $out.IndexOf("redirect(") -ge 0) {
    return $out
  }

  # inserir após "const uiDefault = ...;"
  $m = [regex]::Match($out, 'const\s+uiDefault\s*=\s*[^;]+;\s*')
  if (!$m.Success) {
    return $out
  }

  $insLines = @(
'  if (uiDefault === "v2") {',
'    redirect("/c/" + slug + "/v2");',
'  }',
''
  )
  $ins = ($insLines -join "`r`n")
  $pos = $m.Index + $m.Length
  return ($out.Substring(0, $pos) + "`r`n" + $ins + $out.Substring($pos))
}

# VERIFY
$verify = Join-Path $repo "tools\cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
RunPs1 $verify

# REPORT
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# CV — Fix — V2 hardening (v0_93)") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## O que foi corrigido") | Out-Null
$rep.Add("- MapaV2: padronizou idx/_idx (evita erro de build).") | Out-Null
$rep.Add("- HomeV2Hub: versão estável com useSyncExternalStore (sem setState em effect).") | Out-Null
$rep.Add("- /c/[slug]: usa uiDefault + redirect quando default=v2 (tira warnings).") | Out-Null
$rep.Add("") | Out-Null
$rep.Add("## Arquivos alterados") | Out-Null
foreach ($f in $changed) { $rep.Add("- " + $f) | Out-Null }
$rep.Add("") | Out-Null
$rep.Add("## Verify") | Out-Null
$rep.Add("- tools/cv-verify.ps1 (guard + lint + build)") | Out-Null

$rp = WriteReport "cv-fix-v2-hardening-v0_93.md" ($rep -join "`n")
Write-Host ("[OK] Report: " + $rp)
Write-Host "[OK] Fix aplicado e verificado."