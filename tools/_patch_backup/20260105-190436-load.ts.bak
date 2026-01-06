import path from "node:path";
import fs from "node:fs/promises";
import type { JsonValue, CadernoV2 } from "./types";
import { normalizeCadernoV2 } from "./normalize";

const CONTENT_ROOT = path.join(process.cwd(), "content", "cadernos");

async function readText(p: string): Promise<string> {
  try { return await fs.readFile(p, "utf8"); } catch { return ""; }
}
async function readJson(p: string): Promise<JsonValue> {
  try {
    const s = await fs.readFile(p, "utf8");
    return JSON.parse(s) as JsonValue;
  } catch {
    return {} as JsonValue;
  }
}

export async function loadCadernoV2(slug: string): Promise<CadernoV2> {
  const base = path.join(CONTENT_ROOT, slug);
  const meta = await readJson(path.join(base, "meta.json"));
  const panoramaMd = await readText(path.join(base, "panorama.md"));
  const referenciasMd = await readText(path.join(base, "referencias.md"));
  const mapa = await readJson(path.join(base, "mapa.json"));
  const acervo = await readJson(path.join(base, "acervo.json"));
  const debate = await readJson(path.join(base, "debate.json"));
  const registro = await readJson(path.join(base, "registro.json"));

  // aulas V2: por enquanto vazio (não mexe no pipeline V1 existente)
  const input = { meta, panoramaMd, referenciasMd, mapa, acervo, debate, registro, aulas: [] as unknown[] };
  return normalizeCadernoV2(input, slug);
}
