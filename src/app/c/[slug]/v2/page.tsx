import { notFound } from "next/navigation";
import type { CSSProperties } from "react";
import { getCaderno } from "@/lib/cadernos";
import V2Nav from "@/components/v2/V2Nav";
import HomeV2Hub from "@/components/v2/HomeV2Hub";

type HubStats = Record<string, unknown>;
type AccentStyle = CSSProperties & Record<"--accent", string>;
type AnyObj = Record<string, unknown>;

function isObj(v: unknown): v is AnyObj {
  return !!v && typeof v === "object" && !Array.isArray(v);
}

function pickObj(o: unknown, key: string): AnyObj | null {
  if (!isObj(o)) return null;
  const v = o[key];
  return isObj(v) ? v : null;
}

function pickArr(o: unknown, key: string): unknown[] {
  if (!isObj(o)) return [];
  const v = o[key];
  return Array.isArray(v) ? v : [];
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

  const meta = (data as unknown as { meta?: unknown }).meta;
  const title = isObj(meta) && typeof meta["title"] === "string" ? (meta["title"] as string) : slug;
  const accent = isObj(meta) && typeof meta["accent"] === "string" ? (meta["accent"] as string) : "#F7C600";
  const s: AccentStyle = { ["--accent"]: accent } as AccentStyle;

  const dataObj = data as unknown as AnyObj;
  const mapa = pickObj(dataObj, "mapa") ?? pickObj(dataObj, "mapaV2") ?? (dataObj["mapa"] as unknown) ?? null;
  const mapaNodes = isObj(mapa) ? (Array.isArray(mapa["nodes"]) ? (mapa["nodes"] as unknown[]) : []) : (Array.isArray(mapa) ? mapa : []);

  const stats: HubStats = {
    nodes: mapaNodes.length,
    provas: pickArr(dataObj, "acervo").length,
    debate: pickArr(dataObj, "debate").length,
    trilhas: pickArr(dataObj, "trilhas").length,
  };

  return (
    <main style={{ padding: 14, maxWidth: 1100, margin: "0 auto", ...s }}>
      <V2Nav slug={slug} active="mapa" />
      <div style={{ marginTop: 12 }}>
        <HomeV2Hub slug={slug} title={title} mapa={mapa} stats={stats} />
      </div>
    </main>
  );
}