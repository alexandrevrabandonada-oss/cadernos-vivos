import fs from "fs/promises";
import path from "path";

export type AcervoItem = {
  file: string;
  title: string;
  kind: string;
  tags?: string[];
  source?: string;
};

function isRecord(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null;
}

function asString(v: unknown, fallback = ""): string {
  return typeof v === "string" ? v : fallback;
}

function asStringArray(v: unknown): string[] | undefined {
  if (!Array.isArray(v)) return undefined;
  const out = v.filter((x) => typeof x === "string") as string[];
  return out.length ? out : undefined;
}

export async function getAcervo(slug: string): Promise<AcervoItem[]> {
  const p = path.join(process.cwd(), "content", "cadernos", slug, "acervo.json");
  try {
    const raw = await fs.readFile(p, "utf8");
    const data: unknown = JSON.parse(raw);
    if (!Array.isArray(data)) return [];
    const items: AcervoItem[] = [];
    for (const it of data) {
      if (!isRecord(it)) continue;
      const file = asString(it.file);
      const title = asString(it.title, file);
      const kind = asString(it.kind, "file");
      if (!file) continue;
      items.push({
        file,
        title,
        kind,
        tags: asStringArray(it.tags),
        source: asString(it.source, ""),
      });
    }
    return items;
  } catch {
    return [];
  }
}