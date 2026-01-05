import fs from "node:fs/promises";
import path from "node:path";

export async function getAulaMarkdown(slug: string, aula: number | string): Promise<string> {
  const s = String(slug || "");
  const n = String(aula || "");
  const base = path.join(process.cwd(), "content", "cadernos");
  const file = path.join(base, s, "aulas", n + ".md");
  try {
    return await fs.readFile(file, "utf8");
  } catch {
    return "# Aula " + n + "\\n\\n(arquivo não encontrado)";
  }
}