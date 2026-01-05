import Link from "next/link";
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
    const items = (parsed as AnyObj)["items"]; if (Array.isArray(items)) return items;
    const threads = (parsed as AnyObj)["threads"]; if (Array.isArray(threads)) return threads;
    const debate = (parsed as AnyObj)["debate"]; if (Array.isArray(debate)) return debate;
  }
  return null;
}

function textOf(v: unknown): string {
  if (typeof v === "string") return v;
  if (typeof v === "number") return String(v);
  if (typeof v === "boolean") return v ? "true" : "false";
  return "";
}

function safeTitle(item: AnyObj): string {
  const t = textOf(item["title"]) || textOf(item["name"]) || textOf(item["id"]);
  return t || "Tópico";
}

function safeBody(item: AnyObj): string {
  const b = textOf(item["body"]) || textOf(item["text"]) || textOf(item["content"]) || "";
  return b;
}

const card: CSSProperties = {
  border: "1px solid rgba(255,255,255,0.12)",
  borderRadius: 14,
  padding: 14,
  background: "rgba(0,0,0,0.22)",
};

export default async function DebateV2(props: { slug: string; title?: string }) {
  const { slug } = props;
  const root = path.join(process.cwd(), "content", "cadernos", slug);

  const md = (await readOptional(path.join(root, "debate.md"))) || (await readOptional(path.join(root, "debate.mdx"))) || (await readOptional(path.join(root, "debate.txt")));
  const rawJson = await readOptional(path.join(root, "debate.json"));

  let jsonItems: unknown[] | null = null;
  if (rawJson) {
    try { jsonItems = pickArray(JSON.parse(rawJson) as unknown); } catch { jsonItems = null; }
  }

  const wrap: CSSProperties = { marginTop: 12, display: "grid", gap: 12 };
  const small: CSSProperties = { fontSize: 12, opacity: 0.78 };
  const h2: CSSProperties = { fontSize: 18, fontWeight: 900, letterSpacing: "-0.2px", marginTop: 2 };

  return (
    <section aria-label="Debate V2" style={wrap}>
      <div style={card}>
        <div style={{ fontSize: 12, opacity: 0.75 }}>Concreto Zen • Debate</div>
        <div style={{ fontSize: 22, fontWeight: 950, letterSpacing: "-0.4px", marginTop: 6 }}>Debate em camadas</div>
        <div style={{ marginTop: 8, fontSize: 13, opacity: 0.82 }}>
          Aqui a gente vai evoluir para tópicos, respostas e camadas (tipo mapa mental + thread). Por enquanto, carregamos o que existir em <code>debate.md</code> ou <code>debate.json</code>.
        </div>
        <div style={{ marginTop: 12, display: "flex", gap: 10, flexWrap: "wrap" }}>
          <Link href={"/c/" + slug + "/debate"} style={{ padding: "8px 10px", borderRadius: 10, border: "1px solid rgba(255,255,255,0.14)", textDecoration: "none", color: "inherit", background: "rgba(255,255,255,0.06)" }}>Abrir Debate V1</Link>
          <Link href={"/c/" + slug + "/v2/mapa"} style={{ padding: "8px 10px", borderRadius: 10, border: "1px solid rgba(255,255,255,0.14)", textDecoration: "none", color: "inherit", background: "rgba(0,0,0,0.18)" }}>Ir pro Mapa V2</Link>
        </div>
      </div>

      {md ? (
        <article style={card}>
          <div style={small}>Fonte: debate.md / debate.mdx</div>
          <div style={h2}>Texto-base</div>
          <pre style={{ marginTop: 12, whiteSpace: "pre-wrap", lineHeight: 1.55, fontSize: 13, opacity: 0.92 }}>{md}</pre>
        </article>
      ) : null}

      {(!md && jsonItems && jsonItems.length) ? (
        <article style={card}>
          <div style={small}>Fonte: debate.json</div>
          <div style={h2}>Tópicos</div>
          <div style={{ display: "grid", gap: 10, marginTop: 12 }}>
            {jsonItems.map((it, idx) => {
              const obj = isObj(it) ? (it as AnyObj) : ({ text: String(it) } as AnyObj);
              const title = safeTitle(obj);
              const body = safeBody(obj);
              return (
                <div key={String((obj as AnyObj)["id"] || idx)} style={{ padding: 12, borderRadius: 12, border: "1px solid rgba(255,255,255,0.10)", background: "rgba(0,0,0,0.18)" }}>
                  <div style={{ fontSize: 14, fontWeight: 850 }}>{title}</div>
                  {body ? <div style={{ marginTop: 6, fontSize: 13, opacity: 0.86, whiteSpace: "pre-wrap" }}>{body}</div> : null}
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
            Crie <code>{"content/cadernos/" + slug + "/debate.md"}</code> ou <code>{"content/cadernos/" + slug + "/debate.json"}</code> para alimentar esta tela.
          </div>
        </div>
      ) : null}
    </section>
  );
}