import fs from "fs/promises";
import path from "path";

export type CadernoMeta = {
  slug: string;
  title: string;
  subtitle?: string;
  accent?: string;
  ethos?: string;
};

type CadernoJson = {
  title?: string;
  subtitle?: string;
  accent?: string;
  ethos?: string;
};

function contentRoot(): string {
  return path.join(process.cwd(), "content", "cadernos");
}

function humanize(slug: string): string {
  const s = slug.replace(/[-_]/g, " ");
  return s.replace(/\b\w/g, (m) => m.toUpperCase());
}

async function readMeta(slug: string): Promise<CadernoMeta> {
  const root = contentRoot();
  const metaPath = path.join(root, slug, "caderno.json");
  try {
    const raw = await fs.readFile(metaPath, "utf8");
    const meta = JSON.parse(raw) as CadernoJson;
    return {
      slug,
      title: meta.title ?? humanize(slug),
      subtitle: meta.subtitle,
      accent: meta.accent,
      ethos: meta.ethos,
    };
  } catch {
    return { slug, title: humanize(slug) };
  }
}

export async function listCadernos(): Promise<CadernoMeta[]> {
  const root = contentRoot();
  let slugs: string[] = [];
  try {
    const dirents = await fs.readdir(root, { withFileTypes: true });
    slugs = dirents.filter((d) => d.isDirectory()).map((d) => d.name);
  } catch {
    return [];
  }

  const items: CadernoMeta[] = [];
  for (const slug of slugs) {
    items.push(await readMeta(slug));
  }

  items.sort((a, b) => a.title.localeCompare(b.title, "pt-BR"));
  return items;
}