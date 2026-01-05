import fs from "fs/promises";
import path from "path";
import type { CSSProperties } from "react";
import { getCaderno } from "@/lib/cadernos";
import TerritoryMap from "@/components/TerritoryMap";
import type { MapPoint } from "@/components/TerritoryMap";
import CadernoShell from "@/components/CadernoShell";
import { notFound } from "next/navigation";
type AccentStyle = CSSProperties & { ["--accent"]?: string };
async function readPoints(slug: string): Promise<MapPoint[]> {
  const p = path.join(process.cwd(), "content", "cadernos", slug, "mapa.json");
  try {
    const raw = await fs.readFile(p, "utf8");
    const data = JSON.parse(raw) as unknown;
    if (!Array.isArray(data)) return [];
    return data as MapPoint[];
  } catch {
    return [];
  }
}
export default async function Page({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  let data: Awaited<ReturnType<typeof getCaderno>>;
  try {
  data = await getCaderno(slug);
  } catch (e) {
  const err = e as { code?: string };
  if (err && err.code === "ENOENT") return notFound();
  throw e;
  }
  const points = await readPoints(slug);
  const s: AccentStyle = { ["--accent"]: data.meta.accent };
  return (
    <CadernoShell title={data.meta.title} subtitle={data.meta.subtitle} ethos={data.meta.ethos} style={s}>
<TerritoryMap slug={slug} points={points} />
    </CadernoShell>
  );
}