"use client";

import { useMemo, useState } from "react";
import { useParams } from "next/navigation";
import type { AcervoItem } from "@/lib/acervo";

function firstSlug(v: string | string[] | undefined): string | undefined {
  if (typeof v === "string") return v;
  if (Array.isArray(v) && v.length) return v[0];
  return undefined;
}

function safeLower(s: string) {
  return (s || "").toLowerCase();
}

export default function AcervoClient({
  slug,
  items,
}: {
  slug?: string;
  items: AcervoItem[];
}) {
  const params = useParams();
  const inferred = firstSlug((params as Record<string, string | string[] | undefined>)?.slug);
  const resolvedSlug = slug || inferred || "";

  const [q, setQ] = useState("");
  const [tag, setTag] = useState<string>("");

  const tags = useMemo(() => {
    const set = new Set<string>();
    for (const it of items) {
      for (const t of it.tags || []) set.add(t);
    }
    return Array.from(set).sort((a, b) => a.localeCompare(b));
  }, [items]);

  const filtered = useMemo(() => {
    const qq = safeLower(q).trim();
    return items.filter((it) => {
      if (tag && !(it.tags || []).includes(tag)) return false;
      if (!qq) return true;
      const hay = safeLower(it.title + " " + it.file + " " + (it.kind || ""));
      return hay.includes(qq);
    });
  }, [items, q, tag]);

  const canLink = resolvedSlug.length > 0;

  return (
    <section className="card p-5 space-y-4">
      <div>
        <h2 className="text-xl font-semibold">Acervo (bruto)</h2>
        <p className="muted mt-2">
          Arquivos do caderno. Aqui é base material: PDFs, DOCs, imagens, planilhas.
        </p>
      </div>

      <div className="grid gap-2">
        <label className="text-sm muted">Buscar</label>
        <input
          className="w-full rounded-xl border border-white/10 bg-black/20 p-3 outline-none focus:border-white/20"
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="Digite palavras-chave (ex: TAC, MPF, poeira, orçamento...)"
        />
      </div>

      <div className="flex flex-wrap gap-2">
        <button
          className="card px-3 py-2 hover:bg-white/10 transition"
          onClick={() => setTag("")}
        >
          <span className="accent">Todos</span>
        </button>
        {tags.map((t) => (
          <button
            key={t}
            className="card px-3 py-2 hover:bg-white/10 transition"
            onClick={() => setTag((prev) => (prev === t ? "" : t))}
          >
            <span className={tag === t ? "accent" : ""}>{t}</span>
          </button>
        ))}
      </div>

      <div className="text-sm muted">
        Mostrando <span className="accent">{filtered.length}</span> de {items.length}
      </div>

      <div className="grid gap-3">
        {filtered.map((it) => {
          const placeholder = it.file.startsWith("(");
          const href = canLink && !placeholder
            ? ("/cadernos/" + encodeURIComponent(resolvedSlug) + "/acervo/" + encodeURIComponent(it.file))
            : "";
          return (
            <div key={it.file} className="card p-4">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <div className="text-lg font-semibold">{it.title}</div>
                  <div className="text-xs muted mt-1">{it.file}</div>
                  <div className="flex flex-wrap gap-2 mt-2">
                    <span className="text-xs muted">[{it.kind}]</span>
                    {(it.tags || []).map((t) => (
                      <span key={t} className="text-xs muted">#{t}</span>
                    ))}
                  </div>
                </div>
                {href ? (
                  <a
                    className="card px-3 py-2 hover:bg-white/10 transition"
                    href={href}
                    target="_blank"
                    rel="noreferrer"
                  >
                    <span className="accent">Abrir</span>
                  </a>
                ) : (
                  <div className="text-xs muted">sem arquivo</div>
                )}
              </div>
            </div>
          );
        })}
      </div>

      {!items.length ? (
        <div className="muted text-sm">
          Sem itens ainda. Coloque arquivos em public/cadernos/&lt;slug&gt;/acervo e liste no content/cadernos/&lt;slug&gt;/acervo.json
        </div>
      ) : null}
    </section>
  );
}