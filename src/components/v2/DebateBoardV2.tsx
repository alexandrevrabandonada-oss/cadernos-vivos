"use client";

import React, { useMemo, useState } from "react";
import Link from "next/link";

type Topic = { id: string; label: string; kind: string };

type Props = {
  slug: string;
  title: string;
  mapa: unknown;
  debate: unknown;
};

function asRecord(v: unknown): Record<string, unknown> | null {
  if (!v || typeof v !== "object") return null;
  return v as Record<string, unknown>;
}

function asArray(v: unknown): unknown[] | null {
  return Array.isArray(v) ? v : null;
}

function getStr(v: unknown): string | null {
  return typeof v === "string" ? v : null;
}

function pickLabel(o: Record<string, unknown>): string {
  const a = getStr(o["title"]);
  if (a) return a;
  const b = getStr(o["label"]);
  if (b) return b;
  const c = getStr(o["name"]);
  if (c) return c;
  const d = getStr(o["id"]);
  if (d) return d;
  return "Sem título";
}

function pickId(o: Record<string, unknown>, fallback: string): string {
  const a = getStr(o["id"]);
  if (a) return a;
  const b = getStr(o["slug"]);
  if (b) return b;
  const c = getStr(o["key"]);
  if (c) return c;
  return fallback;
}

function pickKind(o: Record<string, unknown>): string {
  const a = getStr(o["type"]);
  if (a) return a;
  const b = getStr(o["kind"]);
  if (b) return b;
  return "node";
}

function extractTopics(mapa: unknown): Topic[] {
  const topics: Topic[] = [];

  const mo = asRecord(mapa);
  let nodes: unknown[] = [];

  if (mo) {
    const n1 = asArray(mo["nodes"]);
    if (n1) nodes = n1;
    const n2 = asArray(mo["items"]);
    if (nodes.length === 0 && n2) nodes = n2;
  }

  const asArr = asArray(mapa);
  if (nodes.length === 0 && asArr) nodes = asArr;

  for (let i = 0; i < nodes.length; i++) {
    const no = asRecord(nodes[i]);
    if (!no) continue;

    const id = pickId(no, "node-" + i);
    const label = pickLabel(no);
    const kind = pickKind(no);

    topics.push({ id, label, kind });
    if (topics.length >= 80) break;
  }

  return topics;
}

function renderDebate(debate: unknown): React.ReactNode {
  if (!debate) {
    return (
      <div style={{ opacity: 0.85, lineHeight: 1.5 }}>
        Nenhum conteúdo de debate encontrado neste caderno. Você pode adicionar em meta.json ou debate.json (ou equivalente), e a UI vai renderizar aqui.
      </div>
    );
  }

  if (typeof debate === "string") {
    return <div style={{ whiteSpace: "pre-wrap", lineHeight: 1.55 }}>{debate}</div>;
  }

  try {
    return (
      <pre
        style={{
          whiteSpace: "pre-wrap",
          lineHeight: 1.45,
          fontSize: 12,
          background: "rgba(255,255,255,0.04)",
          border: "1px solid rgba(255,255,255,0.08)",
          borderRadius: 12,
          padding: 12,
          overflow: "auto",
        }}
      >
        {JSON.stringify(debate, null, 2)}
      </pre>
    );
  } catch {
    return <div style={{ opacity: 0.9 }}>Debate em formato não exibível.</div>;
  }
}

export default function DebateBoardV2(props: Props) {
  const { slug, title, mapa, debate } = props;

  const topics = useMemo(() => extractTopics(mapa), [mapa]);
  const [selectedId, setSelectedId] = useState<string>(() => (topics[0]?.id ?? ""));

  const selected = useMemo(() => topics.find((t) => t.id === selectedId) ?? null, [topics, selectedId]);

  const baseV2 = "/c/" + slug + "/v2";
  const linkToMapa = baseV2 + "/mapa" + (selectedId ? "#" + selectedId : "");

  return (
    <section style={{ display: "flex", gap: 12, alignItems: "stretch" }}>
      <aside
        style={{
          width: 360,
          maxWidth: "42vw",
          border: "1px solid rgba(255,255,255,0.08)",
          background: "rgba(255,255,255,0.03)",
          borderRadius: 14,
          padding: 12,
          height: "calc(100vh - 110px)",
          overflow: "auto",
        }}
      >
        <div style={{ display: "flex", alignItems: "baseline", justifyContent: "space-between", gap: 10 }}>
          <div>
            <div style={{ fontSize: 12, opacity: 0.85 }}>Debate</div>
            <div style={{ fontSize: 18, fontWeight: 800, letterSpacing: 0.2 }}>{title}</div>
          </div>
          <div style={{ display: "flex", gap: 8, flexWrap: "wrap", justifyContent: "flex-end" }}>
            <Link href={baseV2} style={{ textDecoration: "underline", opacity: 0.9 }}>Home</Link>
            <Link href={baseV2 + "/provas"} style={{ textDecoration: "underline", opacity: 0.9 }}>Provas</Link>
            <Link href={baseV2 + "/linha"} style={{ textDecoration: "underline", opacity: 0.9 }}>Linha</Link>
          </div>
        </div>

        <div style={{ marginTop: 12, fontSize: 12, opacity: 0.9 }}>Tópicos puxados do mapa</div>
        <div style={{ marginTop: 8, display: "flex", flexDirection: "column", gap: 6 }}>
          {topics.length === 0 ? (
            <div style={{ opacity: 0.8, lineHeight: 1.5 }}>
              Nenhum nó detectado no mapa. Assim que o mapa tiver nodes/items, eles aparecem aqui.
            </div>
          ) : (
            topics.map((t) => (
              <button
                key={t.id}
                onClick={() => setSelectedId(t.id)}
                style={{
                  textAlign: "left",
                  padding: "10px 10px",
                  borderRadius: 12,
                  border: "1px solid rgba(255,255,255,0.08)",
                  background: t.id === selectedId ? "rgba(255,255,255,0.08)" : "rgba(0,0,0,0)",
                  color: "white",
                  cursor: "pointer",
                }}
              >
                <div style={{ fontWeight: 700, lineHeight: 1.25 }}>{t.label}</div>
                <div style={{ fontSize: 12, opacity: 0.75, marginTop: 2 }}>{t.kind} · {t.id}</div>
              </button>
            ))
          )}
        </div>
      </aside>

      <main style={{ flex: 1, minWidth: 0 }}>
        <div
          style={{
            border: "1px solid rgba(255,255,255,0.08)",
            background: "rgba(255,255,255,0.03)",
            borderRadius: 14,
            padding: 14,
            minHeight: "calc(100vh - 110px)",
          }}
        >
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", gap: 10, flexWrap: "wrap" }}>
            <div>
              <div style={{ fontSize: 12, opacity: 0.85 }}>Fio selecionado</div>
              <div style={{ fontSize: 20, fontWeight: 900, letterSpacing: 0.2 }}>
                {selected ? selected.label : "Sem seleção"}
              </div>
              <div style={{ fontSize: 12, opacity: 0.75, marginTop: 2 }}>
                {selected ? (selected.kind + " · " + selected.id) : ""}
              </div>
            </div>

            <div style={{ display: "flex", gap: 10, alignItems: "center", flexWrap: "wrap" }}>
              <Link href={linkToMapa} style={{ textDecoration: "underline", opacity: 0.95 }}>Abrir no mapa</Link>
              <button
                onClick={async () => {
                  try {
                    const url = (typeof window !== "undefined" ? window.location.origin : "") + linkToMapa;
                    await navigator.clipboard.writeText(url);
                  } catch {
                    /* noop */
                  }
                }}
                style={{
                  padding: "10px 12px",
                  borderRadius: 12,
                  border: "1px solid rgba(255,255,255,0.10)",
                  background: "rgba(255,255,255,0.06)",
                  color: "white",
                  cursor: "pointer",
                  fontWeight: 800,
                }}
              >
                Copiar link do fio
              </button>
            </div>
          </div>

          <div style={{ marginTop: 12, borderTop: "1px solid rgba(255,255,255,0.08)", paddingTop: 12 }}>
            <div style={{ fontSize: 12, opacity: 0.85, marginBottom: 8 }}>Conteúdo do debate</div>
            {renderDebate(debate)}
          </div>
        </div>
      </main>
    </section>
  );
}