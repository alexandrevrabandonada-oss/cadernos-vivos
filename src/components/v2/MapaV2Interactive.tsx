import type { CSSProperties } from "react";
import fs from "node:fs/promises";
import path from "node:path";
import MapaV2Client from "@/components/v2/MapaV2Client";

type AnyObj = Record<string, unknown>;

async function readOptional(fp: string): Promise<string | null> {
  try { return await fs.readFile(fp, "utf8"); } catch { return null; }
}

function isObj(v: unknown): v is AnyObj {
  return !!v && typeof v === "object" && !Array.isArray(v);
}

function safeJson(raw: string | null): unknown | null {
  if (!raw) return null;
  try { return JSON.parse(raw) as unknown; } catch { return null; }
}

export default async function MapaV2Interactive(props: { slug: string; title?: string; mapa?: unknown }) {
  const slug = props.slug;
  const title = props.title;
  const root = path.join(process.cwd(), "content", "cadernos", slug);

  const rawJson = await readOptional(path.join(root, "mapa.json"));
  const mapa = safeJson(rawJson);
  const rawText =
    (await readOptional(path.join(root, "mapa.md"))) ||
    (await readOptional(path.join(root, "mapa.mdx"))) ||
    (await readOptional(path.join(root, "mapa.txt")));

  const wrap: CSSProperties = { marginTop: 12 };

  return (
    <div style={wrap}>
      <MapaV2Client slug={slug} title={title} mapa={mapa && (isObj(mapa) || Array.isArray(mapa) ? mapa : null)} rawText={rawText} />
    </div>
  );
}