import type { CSSProperties } from "react";
import fs from "node:fs/promises";
import path from "node:path";

type AnyObj = Record<string, unknown>;

async function readOptional(fp: string): Promise<string | null> {
  try { return await fs.readFile(fp, "utf8"); } catch { return null; }
}

function isObj(v: unknown): v is AnyObj {
  return !!v && typeof v === "object" && !Array.isArray(v);
}

function pickArray(parsed: unknown): unknown[] | null {
  if (Array.isArray(parsed)) return parsed;
  if (isObj(parsed)) {
    const items = parsed["items"];
    if (Array.isArray(items)) return items;
    const proofs = parsed["proofs"];
    if (Array.isArray(proofs)) return proofs;
    const sources = parsed["sources"];
    if (Array.isArray(sources)) return sources;
    const refs = parsed["refs"];
    if (Array.isArray(refs)) return refs;
  }
  return null;
}

function textOf(v: unknown): string {
  if (typeof v === "string") return v;
  if (typeof v === "number") return String(v);
  if (typeof v === "boolean") return v ? "true" : "false";
  return "";
}

function safeTitle(item: AnyObj, idx: number): string {
  const t = textOf(item["title"]) || textOf(item["name"]) || textOf(item["label"]);
  return t || ("Fonte " + String(idx + 1));
}

function safeUrl(item: AnyObj): string {
  const u = textOf(item["url"]) || textOf(item["href"]) || textOf(item["link"]);
  return u;
}

function safeNote(item: AnyObj): string {
  const n = textOf(item["note"]) || textOf(item["desc"]) || textOf(item["summary"]) || textOf(item["text"]);
  return n;
}

function safeKind(item: AnyObj): string {
  const k = textOf(item["kind"]) || textOf(item["type"]) || textOf(item["categoria"]);
  return k;
}

const card: CSSProperties = {
  border: "1px solid rgba(255,255,255,0.12)",
  borderRadius: 14,
  padding: 14,
  background: "rgba(0,0,0,0.22)",
};

export default async function ProvasV2(props: { slug: string; title?: string }) {
  const { slug } = props;
  const root = path.join(process.cwd(), "content", "cadernos", slug);

  const md =
    (await readOptional(path.join(root, "provas.md"))) ||
    (await readOptional(path.join(root, "provas.mdx"))) ||
    (await readOptional(path.join(root, "provas.txt")));

  const rawJson = await readOptional(path.join(root, "provas.json"));
  let jsonItems: unknown[] | null = null;
  if (rawJson) {
    try { jsonItems = pickArray(JSON.parse(rawJson) as unknown); } catch { jsonItems = null; }
  }

  const wrap: CSSProperties = { marginTop: 12, display: "grid", gap: 12 };
  const small: CSSProperties = { fontSize: 12, opacity: 0.78 };
  const h2: CSSProperties = { fontSize: 18, fontWeight: 900, letterSpacing: "-0.2px", marginTop: 2 };

  return (
    <section aria-label="Provas V2" style={wrap}>
      <div style={card}>
        <div style={{ fontSize: 12, opacity: 0.75 }}>Concreto Zen • Provas</div>
        <div style={{ fontSize: 22, fontWeight: 950, letterSpacing: "-0.4px", marginTop: 6 }}>Fontes e evidências</div>
        <div style={{ marginTop: 8, fontSize: 13, opacity: 0.82 }}>
          Aqui entram links, documentos, prints, artigos e qualquer evidência que sustenta o caderno.
          Por enquanto, carregamos o que existir em <code>provas.md</code> ou <code>provas.json</code>.
        </div>
      </div>

      {md ? (
        <article style={card}>
          <div style={small}>Fonte: provas.md / provas.mdx</div>
          <div style={h2}>Texto-base</div>
          <pre style={{ marginTop: 12, whiteSpace: "pre-wrap", lineHeight: 1.55, fontSize: 13, opacity: 0.92 }}>{md}</pre>
        </article>
      ) : null}

      {(!md && jsonItems && jsonItems.length) ? (
        <article style={card}>
          <div style={small}>Fonte: provas.json</div>
          <div style={h2}>Itens</div>
          <div style={{ display: "grid", gap: 10, marginTop: 12 }}>
            {jsonItems.map((it, idx) => {
              const obj: AnyObj = isObj(it) ? (it as AnyObj) : ({ text: String(it) } as AnyObj);
              const title = safeTitle(obj, idx);
              const url = safeUrl(obj);
              const note = safeNote(obj);
              const kind = safeKind(obj);
              const key = String(obj["id"] || obj["key"] || idx);
              return (
                <div key={key} style={{ padding: 12, borderRadius: 12, border: "1px solid rgba(255,255,255,0.10)", background: "rgba(0,0,0,0.18)" }}>
                  <div style={{ display: "flex", gap: 10, alignItems: "baseline", flexWrap: "wrap" }}>
                    <div style={{ fontSize: 14, fontWeight: 900 }}>{title}</div>
                    {kind ? <span style={{ fontSize: 12, opacity: 0.72 }}>({kind})</span> : null}
                  </div>
                  {url ? (
                    <div style={{ marginTop: 6, fontSize: 13 }}>
                      <a href={url} target="_blank" rel="noreferrer" style={{ color: "inherit", textDecoration: "underline" }}>{url}</a>
                    </div>
                  ) : null}
                  {note ? <div style={{ marginTop: 6, fontSize: 13, opacity: 0.86, whiteSpace: "pre-wrap" }}>{note}</div> : null}
                </div>
              );
            })}
          </div>
        </article>
      ) : null}

      {(!md && (!jsonItems || jsonItems.length === 0)) ? (
        <div style={card}>
          <div style={h2}>Ainda vazio</div>
          <div style={{ marginTop: 8, fontSize: 13, opacity: 0.82 }}>
            Crie <code>{"content/cadernos/" + slug + "/provas.md"}</code> ou <code>{"content/cadernos/" + slug + "/provas.json"}</code> para alimentar esta tela.
          </div>
        </div>
      ) : null}
    </section>
  );
}