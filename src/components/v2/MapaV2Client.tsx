"use client";

import Link from "next/link";
import { useMemo, useState } from "react";

type AnyObj = Record<string, unknown>;
type NodeLike = AnyObj | string | number | boolean;
type EdgeLike = AnyObj | string | number;

function isObj(v: unknown): v is AnyObj {
  return !!v && typeof v === "object" && !Array.isArray(v);
}

function textOf(v: unknown): string {
  if (typeof v === "string") return v;
  if (typeof v === "number") return String(v);
  if (typeof v === "boolean") return v ? "true" : "false";
  return "";
}

function pickNodes(mapa: unknown): NodeLike[] {
  if (!mapa) return [];
  if (Array.isArray(mapa)) return mapa as NodeLike[];
  if (isObj(mapa)) {
    const nodes = (mapa as AnyObj)["nodes"];
    if (Array.isArray(nodes)) return nodes as NodeLike[];
    const items = (mapa as AnyObj)["items"];
    if (Array.isArray(items)) return items as NodeLike[];
    const timeline = (mapa as AnyObj)["timeline"];
    if (Array.isArray(timeline)) return timeline as NodeLike[];
  }
  return [];
}

function pickEdges(mapa: unknown): EdgeLike[] {
  if (!mapa) return [];
  if (isObj(mapa)) {
    const edges = (mapa as AnyObj)["edges"];
    if (Array.isArray(edges)) return edges as EdgeLike[];
    const links = (mapa as AnyObj)["links"];
    if (Array.isArray(links)) return links as EdgeLike[];
    const rels = (mapa as AnyObj)["relations"];
    if (Array.isArray(rels)) return rels as EdgeLike[];
  }
  return [];
}

function nodeId(n: NodeLike, idx: number): string {
  if (isObj(n)) {
    const id = textOf(n["id"]) || textOf(n["slug"]) || textOf(n["key"]);
    if (id) return id;
    const t = textOf(n["title"]) || textOf(n["name"]) || textOf(n["label"]);
    if (t) return "n:" + t;
  }
  const t2 = textOf(n);
  return t2 ? ("n:" + t2) : ("n#" + String(idx));
}

function nodeTitle(n: NodeLike, idx: number): string {
  if (isObj(n)) {
    return textOf(n["title"]) || textOf(n["name"]) || textOf(n["label"]) || nodeId(n, idx);
  }
  const t = textOf(n);
  return t || ("Nó " + String(idx + 1));
}

function nodeKind(n: NodeLike): string {
  if (!isObj(n)) return "";
  return textOf(n["kind"]) || textOf(n["type"]) || "";
}

function edgeEnds(e: EdgeLike): { a: string; b: string; label: string } | null {
  if (isObj(e)) {
    const a = textOf(e["from"]) || textOf(e["a"]) || textOf(e["source"]);
    const b = textOf(e["to"]) || textOf(e["b"]) || textOf(e["target"]);
    const label = textOf(e["label"]) || textOf(e["kind"]) || "";
    if (a && b) return { a, b, label };
  }
  return null;
}

export default function MapaV2Client(props: { slug: string; title?: string; mapa?: unknown; rawText?: string | null }) {
  const { slug, title, mapa, rawText } = props;
  const [q, setQ] = useState("");
  const [selected, setSelected] = useState<string>("");

  const nodes = useMemo(() => pickNodes(mapa), [mapa]);
  const edges = useMemo(() => pickEdges(mapa), [mapa]);

  const nodeRows = useMemo(() => {
    return nodes.map((n, idx) => {
      const id = nodeId(n, idx);
      const t = nodeTitle(n, idx);
      const k = nodeKind(n);
      return { id, title: t, kind: k, raw: n, idx };
    });
  }, [nodes]);

  const kinds = useMemo(() => {
    const s = new Set<string>();
    nodeRows.forEach(r => { if (r.kind) s.add(r.kind); });
    return Array.from(s).sort((a,b) => a.localeCompare(b));
  }, [nodeRows]);

  const [kindFilter, setKindFilter] = useState<string>("");

  const filtered = useMemo(() => {
    const qq = q.trim().toLowerCase();
    return nodeRows.filter(r => {
      if (kindFilter && r.kind !== kindFilter) return false;
      if (!qq) return true;
      return r.title.toLowerCase().includes(qq) || r.id.toLowerCase().includes(qq);
    });
  }, [nodeRows, q, kindFilter]);

  const neighbors = useMemo(() => {
    if (!selected) return [] as { id: string; via: string }[];
    const out: { id: string; via: string }[] = [];
    edges.forEach((e) => {
      const ends = edgeEnds(e);
      if (!ends) return;
      if (ends.a === selected) out.push({ id: ends.b, via: ends.label });
      else if (ends.b === selected) out.push({ id: ends.a, via: ends.label });
    });
    const seen = new Set<string>();
    return out.filter(x => { if (seen.has(x.id)) return false; seen.add(x.id); return true; });
  }, [edges, selected]);

  const selectedNode = useMemo(() => nodeRows.find(r => r.id === selected) || null, [nodeRows, selected]);

  const wrap: React.CSSProperties = { display: "grid", gridTemplateColumns: "360px 1fr", gap: 12, marginTop: 12 };
  const card: React.CSSProperties = { border: "1px solid rgba(255,255,255,0.12)", borderRadius: 14, padding: 14, background: "rgba(0,0,0,0.22)" };
  const small: React.CSSProperties = { fontSize: 12, opacity: 0.78 };

  const inputStyle: React.CSSProperties = { width: "100%", padding: "10px 12px", borderRadius: 12, border: "1px solid rgba(255,255,255,0.14)", background: "rgba(0,0,0,0.35)", color: "inherit" };
  const pill: React.CSSProperties = { display: "inline-flex", alignItems: "center", gap: 6, padding: "6px 10px", borderRadius: 999, border: "1px solid rgba(255,255,255,0.14)", background: "rgba(255,255,255,0.06)" };

  const emptyStructured = nodeRows.length === 0;

  return (
    <section aria-label="Mapa V2 Interativo">
      <div style={card}>
        <div style={{ fontSize: 12, opacity: 0.75 }}>Concreto Zen • Mapa</div>
        <div style={{ fontSize: 22, fontWeight: 950, letterSpacing: "-0.4px", marginTop: 6 }}>{title || slug}</div>
        <div style={{ marginTop: 10, display: "flex", gap: 10, flexWrap: "wrap" }}>
          <Link href={"/c/" + slug + "/v2"} style={{ ...pill, textDecoration: "none", color: "inherit" }}>Voltar ao Hub</Link>
          <Link href={"/c/" + slug} style={{ ...pill, textDecoration: "none", color: "inherit" }}>Abrir V1</Link>
          <span style={{ ...pill, opacity: 0.85 }}>Nós: <b>{nodeRows.length}</b></span>
          <span style={{ ...pill, opacity: 0.85 }}>Relações: <b>{edges.length}</b></span>
        </div>
      </div>

      <div style={wrap}>
        <aside style={card}>
          <div style={small}>Buscar / filtrar</div>
          <div style={{ marginTop: 10, display: "grid", gap: 10 }}>
            <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="buscar nó..." style={inputStyle} />
            {kinds.length ? (
              <select value={kindFilter} onChange={(e) => setKindFilter(e.target.value)} style={inputStyle}>
                <option value="">(todos os tipos)</option>
                {kinds.map(k => <option key={k} value={k}>{k}</option>)}
              </select>
            ) : null}
          </div>

          <div style={{ marginTop: 12, display: "grid", gap: 8, maxHeight: 520, overflow: "auto", paddingRight: 6 }}>
            {filtered.map(r => {
              const isSel = r.id === selected;
              const isNei = neighbors.some(n => n.id === r.id);
              return (
                <button
                  key={r.id}
                  onClick={() => setSelected(r.id)}
                  style={{
                    textAlign: "left",
                    padding: 10,
                    borderRadius: 12,
                    cursor: "pointer",
                    border: "1px solid rgba(255,255,255,0.10)",
                    background: isSel ? "rgba(255,255,255,0.10)" : (isNei ? "rgba(255,255,255,0.06)" : "rgba(0,0,0,0.18)"),
                    color: "inherit"
                  }}>
                  <div style={{ fontSize: 13, fontWeight: 850 }}>{r.title}</div>
                  <div style={{ fontSize: 12, opacity: 0.72 }}>{r.kind || r.id}</div>
                </button>
              );
            })}
            {filtered.length === 0 ? <div style={{ fontSize: 13, opacity: 0.78 }}>Nada encontrado.</div> : null}
          </div>
        </aside>

        <main style={card}>
          {!selectedNode ? (
            <div>
              <div style={{ fontSize: 16, fontWeight: 900 }}>Selecione um nó</div>
              <div style={{ marginTop: 8, fontSize: 13, opacity: 0.82 }}>Clique em um item à esquerda para ver detalhes e conexões.</div>
              {emptyStructured && rawText ? (
                <div style={{ marginTop: 14 }}>
                  <div style={small}>Sem dados estruturados (mostrando texto bruto)</div>
                  <pre style={{ marginTop: 10, whiteSpace: "pre-wrap", lineHeight: 1.55, fontSize: 13, opacity: 0.92 }}>{rawText}</pre>
                </div>
              ) : null}
              {emptyStructured && !rawText ? (
                <div style={{ marginTop: 14, fontSize: 13, opacity: 0.82 }}>
                  Crie <code>content/cadernos/{slug}/mapa.json</code> (com <code>nodes</code> e opcional <code>edges</code>) para habilitar o mapa interativo.
                </div>
              ) : null}
            </div>
          ) : (
            <div>
              <div style={{ fontSize: 12, opacity: 0.75 }}>Nó selecionado</div>
              <div style={{ fontSize: 20, fontWeight: 950, letterSpacing: "-0.3px", marginTop: 6 }}>{selectedNode.title}</div>
              <div style={{ marginTop: 6, fontSize: 13, opacity: 0.85 }}>{selectedNode.kind ? ("Tipo: " + selectedNode.kind) : selectedNode.id}</div>

              <div style={{ marginTop: 14, fontSize: 13, opacity: 0.88 }}>Conexões</div>
              {neighbors.length ? (
                <ul style={{ marginTop: 10, marginBottom: 0, paddingLeft: 18, display: "grid", gap: 6 }}>
                  {neighbors.map(n => {
                    const row = nodeRows.find(r => r.id === n.id);
                    const label = row ? row.title : n.id;
                    return (
                      <li key={n.id} style={{ lineHeight: 1.45 }}>
                        <button onClick={() => setSelected(n.id)} style={{
                          padding: 0, border: "none", background: "transparent", color: "inherit", cursor: "pointer", textDecoration: "underline"
                        }}>{label}</button>
                        {n.via ? <span style={{ marginLeft: 8, fontSize: 12, opacity: 0.75 }}>({n.via})</span> : null}
                      </li>
                    );
                  })}
                </ul>
              ) : (
                <div style={{ marginTop: 8, fontSize: 13, opacity: 0.78 }}>Sem relações registradas para este nó.</div>
              )}

              <details style={{ marginTop: 14 }}>
                <summary style={{ cursor: "pointer", fontSize: 13, opacity: 0.85 }}>ver bruto</summary>
                <pre style={{ marginTop: 10, whiteSpace: "pre-wrap", lineHeight: 1.55, fontSize: 12, opacity: 0.92 }}>
{JSON.stringify(selectedNode.raw, null, 2)}
                </pre>
              </details>
            </div>
          )}
        </main>
      </div>
    </section>
  );
}