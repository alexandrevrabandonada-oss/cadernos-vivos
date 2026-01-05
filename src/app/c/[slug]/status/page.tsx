import React from "react";
import fs from "fs/promises";
import path from "path";
import Link from "next/link";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

type StatusItem = {
  key: string;
  label: string;
  ok: boolean;
  detail?: string;
  href?: string;
};

async function exists(p: string): Promise<boolean> {
  try {
    await fs.stat(p);
    return true;
  } catch {
    return false;
  }
}

async function existsAny(base: string, names: string[]): Promise<string> {
  for (const n of names) {
    const p = path.join(base, n);
    if (await exists(p)) return n;
  }
  return "";
}

function asRecord(v: unknown): Record<string, unknown> {
  if (v && typeof v === "object") return v as Record<string, unknown>;
  return {};
}

function pick(meta: Record<string, unknown>, keys: string[]): string {
  for (const k of keys) {
    const v = meta[k];
    if (typeof v === "string" && v.trim()) return v.trim();
  }
  return "";
}

function badge(ok: boolean) {
  return ok ? (
    <span className="px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-900">OK</span>
  ) : (
    <span className="px-2 py-0.5 rounded text-xs font-medium bg-amber-100 text-amber-900">FALTA</span>
  );
}

export default async function StatusPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const base = path.join(process.cwd(), "content", "cadernos", slug);

  const metaPath = path.join(base, "meta.json");
  const metaExists = await exists(metaPath);
  let meta: Record<string, unknown> = {};
  let metaErr = "";

  if (metaExists) {
    try {
      const raw = await fs.readFile(metaPath, "utf8");
      meta = asRecord(JSON.parse(raw));
    } catch {
      metaErr = "meta.json inválido (JSON)";
      meta = {};
    }
  }

  const title = pick(meta, ["title"]) || slug;
  const subtitle = pick(meta, ["subtitle"]);
  const mood = pick(meta, ["mood", "universe", "theme", "tone"]);
  const ethos = pick(meta, ["ethos"]);

  const aulasDir = path.join(base, "aulas");
  let aulaCount = 0;
  if (await exists(aulasDir)) {
    try {
      const files = await fs.readdir(aulasDir);
      aulaCount = files.filter((f) => f.endsWith(".md") || f.endsWith(".mdx")).length;
    } catch {}
  }

  const hasMapa = await exists(path.join(base, "mapa.json"));
  const hasDebate = await exists(path.join(base, "debate.json"));
  const quizFile = await existsAny(base, ["quiz.json", "quiz.md", "quiz.mdx"]);
  const trilhaFile = await existsAny(base, ["trilha.json", "trilha.md", "trilha.mdx"]);
  const acervoFile = await existsAny(base, ["acervo.json", "acervo.md", "acervo.mdx"]);
  const praticaFile = await existsAny(base, ["pratica.md", "pratica.mdx", "pratica.json"]);
  const registroFile = await existsAny(base, ["registro.json", "registro.md", "registro.mdx"]);

  const checks: StatusItem[] = [
    { key: "meta", label: "Meta (meta.json)", ok: metaExists && !metaErr, detail: metaErr || "" },
    { key: "aulas", label: "Aulas (aulas/*.md)", ok: aulaCount > 0, detail: aulaCount ? String(aulaCount) + " arquivo(s)" : "nenhuma aula" },
    { key: "trilha", label: "Trilha (trilha.*)", ok: !!trilhaFile, detail: trilhaFile || "não encontrado", href: "/c/" + slug + "/trilha" },
    { key: "pratica", label: "Prática (pratica.*)", ok: !!praticaFile, detail: praticaFile || "não encontrado", href: "/c/" + slug + "/pratica" },
    { key: "quiz", label: "Quiz (quiz.*)", ok: !!quizFile, detail: quizFile || "não encontrado", href: "/c/" + slug + "/quiz" },
    { key: "acervo", label: "Acervo (acervo.*)", ok: !!acervoFile, detail: acervoFile || "não encontrado", href: "/c/" + slug + "/acervo" },
    { key: "mapa", label: "Mapa (mapa.json)", ok: hasMapa, detail: hasMapa ? "mapa.json" : "não encontrado", href: "/c/" + slug + "/mapa" },
    { key: "debate", label: "Debate (debate.json)", ok: hasDebate, detail: hasDebate ? "debate.json" : "não encontrado", href: "/c/" + slug + "/debate" },
    { key: "registro", label: "Registro/Evidência (registro.*)", ok: !!registroFile, detail: registroFile || "não encontrado", href: "/c/" + slug + "/registro" },
  ];

  const okCount = checks.filter((c) => c.ok).length;
  const pct = Math.round((okCount * 100) / checks.length);

  return (
    <main className="space-y-5">
      <section className="card p-5">
        <div className="flex items-start justify-between gap-4">
          <div>
            <div className="text-xs muted">Status do Caderno</div>
            <h1 className="text-2xl font-semibold mt-1">{title}</h1>
            {subtitle ? <p className="muted mt-2">{subtitle}</p> : null}
            <div className="text-sm muted mt-2">slug: <span className="font-mono">{slug}</span>{mood ? " • mood: " + mood : ""}</div>
            {ethos ? <p className="mt-3 text-sm">{ethos}</p> : null}
          </div>
          <div className="text-right">
            <div className="text-xs muted">completude</div>
            <div className="text-3xl font-semibold mt-1">{pct}%</div>
            <div className="text-xs muted mt-1">{okCount}/{checks.length} itens</div>
          </div>
        </div>
      </section>

      <section className="card p-5">
        <h2 className="text-lg font-semibold">Checklist</h2>
        <div className="mt-4 space-y-3">
          {checks.map((c) => (
            <div key={c.key} className="flex items-start justify-between gap-4">
              <div>
                <div className="font-medium">{c.label}</div>
                {c.detail ? <div className="text-xs muted mt-1">{c.detail}</div> : null}
                {c.href ? (
                  <div className="text-xs mt-1">
                    <Link className="underline" href={c.href}>Abrir seção</Link>
                  </div>
                ) : null}
              </div>
              <div>{badge(c.ok)}</div>
            </div>
          ))}
        </div>
      </section>

      <section className="card p-5">
        <h2 className="text-lg font-semibold">Atalhos</h2>
        <div className="mt-3 flex flex-wrap gap-2">
          <Link className="btn" href={"/c/" + slug}>Panorama</Link>
          <Link className="btn" href={"/c/" + slug + "/trilha"}>Trilha</Link>
          <Link className="btn" href={"/c/" + slug + "/a/1"}>Aulas</Link>
          <Link className="btn" href={"/c/" + slug + "/pratica"}>Prática</Link>
          <Link className="btn" href={"/c/" + slug + "/quiz"}>Quiz</Link>
          <Link className="btn" href={"/c/" + slug + "/acervo"}>Acervo</Link>
          <Link className="btn" href={"/c/" + slug + "/mapa"}>Mapa</Link>
          <Link className="btn" href={"/c/" + slug + "/debate"}>Debate</Link>
          <Link className="btn" href={"/c/" + slug + "/registro"}>Registro</Link>
        </div>
        <p className="text-xs muted mt-3">Dica: se algo estiver faltando, isso é sobre conteúdo em content/cadernos/
${slug}
 — não sobre código.</p>
      </section>
    </main>
  );
}