"use client";

import Link from "next/link";
import { useMemo, useState } from "react";

type AcervoItem = {
  id: string;
  title: string;
  kind: string;
  url?: string;
  source?: string;
  year?: string;
  tags: string[];
  note?: string;
};

function isRecord(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

function asString(v: unknown): string | undefined {
  if (typeof v === "string") {
    const t = v.trim();
    return t.length ? t : undefined;
  }
  if (typeof v === "number" && Number.isFinite(v)) return String(v);
  if (typeof v === "boolean") return v ? "true" : "false";
  return undefined;
}

function asStringArray(v: unknown): string[] {
  if (!Array.isArray(v)) return [];
  const out: string[] = [];
  for (const it of v) {
    const s = asString(it);
    if (s) out.push(s);
  }
  return out;
}

function safeIdFromTitle(title: string): string {
  const base = title.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, "");
  return (base.length ? base : "item") + "-" + Math.random().toString(36).slice(2, 7);
}

function normalizeAcervo(acervo: unknown): AcervoItem[] {
  if (!Array.isArray(acervo)) return [];
  const out: AcervoItem[] = [];
  for (const raw of acervo) {
    if (!isRecord(raw)) continue;

    const title =
      asString(raw.title) ??
      asString(raw.titulo) ??
      asString(raw.nome) ??
      asString(raw.name) ??
      "Sem título";

    const id = asString(raw.id) ?? asString(raw.slug) ?? safeIdFromTitle(title);
    const kind = (asString(raw.kind) ?? asString(raw.tipo) ?? asString(raw.type) ?? "item").toLowerCase();
    const url = asString(raw.url) ?? asString(raw.link) ?? asString(raw.href);
    const source = asString(raw.source) ?? asString(raw.fonte) ?? asString(raw.autor) ?? asString(raw.org);
    const year = asString(raw.year) ?? asString(raw.ano) ?? asString(raw.data);
    const tags = asStringArray(raw.tags ?? raw.etiquetas ?? raw.labels);
    const note = asString(raw.note ?? raw.nota ?? raw.obs ?? raw.descricao ?? raw.descrição);

    out.push({ id, title, kind, url, source, year, tags, note });
  }
  return out;
}

export default function AcervoV2(props: { slug: string; title: string; acervo: unknown }) {
  const items = useMemo(() => normalizeAcervo(props.acervo), [props.acervo]);
  const [q, setQ] = useState("");
  const [kind, setKind] = useState("todos");

  const kinds = useMemo(() => {
    const set = new Set<string>();
    for (const it of items) set.add(it.kind);
    return Array.from(set).sort((a, b) => a.localeCompare(b));
  }, [items]);

  const filtered = useMemo(() => {
    const qq = q.trim().toLowerCase();
    return items.filter((it) => {
      if (kind !== "todos" && it.kind !== kind) return false;
      if (!qq) return true;
      const hay = (it.title + " " + (it.source ?? "") + " " + it.tags.join(" ") + " " + (it.note ?? "")).toLowerCase();
      return hay.includes(qq);
    });
  }, [items, q, kind]);

  return (
    <section
      style={{
        border: "1px solid rgba(255,255,255,0.12)",
        borderRadius: 16,
        padding: 14,
        background: "linear-gradient(180deg, rgba(255,255,255,0.05), rgba(0,0,0,0.08))",
      }}
    >
      <div style={{ display: "flex", justifyContent: "space-between", gap: 12, flexWrap: "wrap" }}>
        <div>
          <div style={{ fontSize: 12, opacity: 0.8 }}>Caderno</div>
          <div style={{ fontSize: 18, fontWeight: 800 }}>{props.title}</div>
        </div>
        <div style={{ display: "flex", gap: 10, alignItems: "center", opacity: 0.85 }}>
          <div style={{ fontSize: 12 }}>Itens: <b>{filtered.length}</b></div>
          <Link href={"/c/" + props.slug + "/v2"} style={{ textDecoration: "underline" }}>
            Voltar
          </Link>
        </div>
      </div>

      <div style={{ marginTop: 12, display: "flex", gap: 10, flexWrap: "wrap" }}>
        <input
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="Buscar no acervo (título, fonte, tags, nota…)"
          style={{
            flex: "1 1 280px",
            padding: "10px 12px",
            borderRadius: 12,
            border: "1px solid rgba(255,255,255,0.16)",
            background: "rgba(0,0,0,0.25)",
            color: "inherit",
          }}
        />
        <select
          value={kind}
          onChange={(e) => setKind(e.target.value)}
          style={{
            flex: "0 0 220px",
            padding: "10px 12px",
            borderRadius: 12,
            border: "1px solid rgba(255,255,255,0.16)",
            background: "rgba(0,0,0,0.25)",
            color: "inherit",
          }}
        >
          <option value="todos">Todos os tipos</option>
          {kinds.map((k) => (
            <option key={k} value={k}>
              {k}
            </option>
          ))}
        </select>
      </div>

      <div style={{ marginTop: 12, display: "grid", gap: 10 }}>
        {filtered.length === 0 ? (
          <div style={{ opacity: 0.75, padding: 10 }}>
            Nada por aqui ainda. (Se o seu caderno ainda não tem acervo, a gente já tem o componente pronto.)
          </div>
        ) : null}

        {filtered.map((it) => (
          <div
            key={it.id}
            id={it.id}
            style={{
              border: "1px solid rgba(255,255,255,0.10)",
              borderRadius: 14,
              padding: 12,
              background: "rgba(0,0,0,0.20)",
            }}
          >
            <div style={{ display: "flex", justifyContent: "space-between", gap: 12, flexWrap: "wrap" }}>
              <div style={{ fontWeight: 800 }}>{it.title}</div>
              <div style={{ opacity: 0.75, fontSize: 12 }}>
                {it.kind}{it.year ? " • " + it.year : ""}
              </div>
            </div>

            {it.source ? <div style={{ marginTop: 6, opacity: 0.85, fontSize: 13 }}>Fonte: {it.source}</div> : null}
            {it.note ? <div style={{ marginTop: 6, opacity: 0.90 }}>{it.note}</div> : null}

            {it.tags.length ? (
              <div style={{ marginTop: 8, display: "flex", gap: 6, flexWrap: "wrap" }}>
                {it.tags.slice(0, 10).map((t) => (
                  <span
                    key={t}
                    style={{
                      fontSize: 12,
                      padding: "4px 8px",
                      borderRadius: 999,
                      border: "1px solid rgba(255,255,255,0.14)",
                      opacity: 0.9,
                    }}
                  >
                    {t}
                  </span>
                ))}
              </div>
            ) : null}

            <div style={{ marginTop: 10, display: "flex", gap: 12, flexWrap: "wrap", opacity: 0.95 }}>
              {it.url ? (
                <a href={it.url} target="_blank" rel="noreferrer" style={{ textDecoration: "underline" }}>
                  Abrir fonte
                </a>
              ) : (
                <span style={{ opacity: 0.65 }}>Sem link</span>
              )}
              <Link href={"/c/" + props.slug + "/v2/provas#"+ encodeURIComponent(it.id)} style={{ textDecoration: "underline" }}>
                Link direto
              </Link>
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}