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
    const timeline = (parsed as AnyObj)["timeline"]; if (Array.isArray(timeline)) return timeline;
    const events = (parsed as AnyObj)["events"]; if (Array.isArray(events)) return events;
  }
  return null;
}

function textOf(v: unknown): string {
  if (typeof v === "string") return v;
  if (typeof v === "number") return String(v);
  if (typeof v === "boolean") return v ? "true" : "false";
  return "";
}

function pick(item: AnyObj, keys: string[]): string {
  for (const k of keys) {
    const t = textOf(item[k]).trim();
    if (t) return t;
  }
  return "";
}

type TimelineItem = { id: string; date?: string; title: string; body?: string; kind?: string; };

function normalize(items: unknown[]): TimelineItem[] {
  const out: TimelineItem[] = [];
  for (let i = 0; i < items.length; i++) {
    const it = items[i];
    const obj: AnyObj = isObj(it) ? (it as AnyObj) : ({ text: String(it) } as AnyObj);
    const id = pick(obj, ["id", "key", "slug"]) || String(i);
    const date = pick(obj, ["date", "when", "year"]);
    const title = pick(obj, ["title", "name"]) || "Marco";
    const body = pick(obj, ["body", "text", "content", "desc", "description"]);
    const kind = pick(obj, ["kind", "type"]);
    out.push({ id, date: date || undefined, title, body: body || undefined, kind: kind || undefined });
  }
  return out;
}

const card: CSSProperties = {
  border: "1px solid rgba(255,255,255,0.12)",
  borderRadius: 14,
  padding: 14,
  background: "rgba(0,0,0,0.22)",
};

const chip: CSSProperties = {
  display: "inline-flex",
  alignItems: "center",
  gap: 8,
  padding: "6px 10px",
  borderRadius: 999,
  border: "1px solid rgba(255,255,255,0.14)",
  textDecoration: "none",
  color: "inherit",
  background: "rgba(255,255,255,0.06)",
  fontSize: 12,
};

export default async function LinhaV2(props: { slug: string; title?: string }) {
  const { slug } = props;
  const root = path.join(process.cwd(), "content", "cadernos", slug);

  const md =
    (await readOptional(path.join(root, "linha.md"))) ||
    (await readOptional(path.join(root, "linha.mdx"))) ||
    (await readOptional(path.join(root, "linha.txt"))) ||
    (await readOptional(path.join(root, "timeline.md"))) ||
    (await readOptional(path.join(root, "timeline.txt")));

  const rawJson = (await readOptional(path.join(root, "linha.json"))) || (await readOptional(path.join(root, "timeline.json")));
  let items: TimelineItem[] = [];
  if (rawJson) {
    try {
      const arr = pickArray(JSON.parse(rawJson) as unknown);
      if (arr && arr.length) items = normalize(arr);
    } catch {
      items = [];
    }
  }

  const wrap: CSSProperties = { marginTop: 12, display: "grid", gap: 12 };
  const small: CSSProperties = { fontSize: 12, opacity: 0.78 };
  const h2: CSSProperties = { fontSize: 18, fontWeight: 900, letterSpacing: "-0.2px", marginTop: 2 };

  return (
    <section aria-label="Linha V2" style={wrap}>
      <div style={card}>
        <div style={{ fontSize: 12, opacity: 0.75 }}>Concreto Zen • Linha</div>
        <div style={{ fontSize: 22, fontWeight: 950, letterSpacing: "-0.4px", marginTop: 6 }}>Linha do tempo</div>
        <div style={{ marginTop: 8, fontSize: 13, opacity: 0.82 }}>
          Aqui entram marcos, eventos, etapas e viradas do caderno. Por enquanto, lê <code>linha.md</code> / <code>linha.json</code> (ou <code>timeline.*</code>).
        </div>
        <div style={{ marginTop: 12, display: "flex", gap: 10, flexWrap: "wrap" }}>
          <Link href={"/c/" + slug} style={chip}>Abrir V1</Link>
          <Link href={"/c/" + slug + "/v2/mapa"} style={{ ...chip, background: "rgba(0,0,0,0.18)" }}>Ir pro Mapa V2</Link>
        </div>
      </div>

      {md ? (
        <article style={card}>
          <div style={small}>Fonte: linha.md / timeline.md</div>
          <div style={h2}>Texto-base</div>
          <pre style={{ marginTop: 12, whiteSpace: "pre-wrap", lineHeight: 1.55, fontSize: 13, opacity: 0.92 }}>{md}</pre>
        </article>
      ) : null}

      {(!md && items.length) ? (
        <article style={card}>
          <div style={small}>Fonte: linha.json / timeline.json</div>
          <div style={h2}>Marcos</div>
          <div style={{ display: "grid", gap: 10, marginTop: 12 }}>
            {items.map((it, idx) => (
              <div key={it.id || String(idx)} style={{ padding: 12, borderRadius: 12, border: "1px solid rgba(255,255,255,0.10)", background: "rgba(0,0,0,0.18)" }}>
                <div style={{ display: "flex", gap: 10, flexWrap: "wrap", alignItems: "baseline" }}>
                  <div style={{ fontSize: 14, fontWeight: 850 }}>{it.title}</div>
                  {it.kind ? <span style={{ fontSize: 12, opacity: 0.75 }}>• {it.kind}</span> : null}
                  {it.date ? <span style={{ fontSize: 12, opacity: 0.75 }}>• {it.date}</span> : null}
                </div>
                {it.body ? <div style={{ marginTop: 6, fontSize: 13, opacity: 0.86, whiteSpace: "pre-wrap" }}>{it.body}</div> : null}
              </div>
            ))}
          </div>
        </article>
      ) : null}

      {(!md && items.length === 0) ? (
        <div style={card}>
          <div style={h2}>Ainda vazio</div>
          <div style={{ marginTop: 8, fontSize: 13, opacity: 0.82 }}>
            Crie <code>{"content/cadernos/" + slug + "/linha.md"}</code> ou <code>{"content/cadernos/" + slug + "/linha.json"}</code> para alimentar esta tela.
          </div>
        </div>
      ) : null}
    </section>
  );
}