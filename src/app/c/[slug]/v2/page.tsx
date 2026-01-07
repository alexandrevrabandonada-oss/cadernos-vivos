import { notFound } from "next/navigation";
import type { CSSProperties } from "react";
import V2Nav from "@/components/v2/V2Nav";
import HomeV2Hub from "@/components/v2/HomeV2Hub";
import { loadCadernoV2 } from "@/lib/v2";
import type { Metadata } from "next";
import { cvReadMetaLoose } from "@/lib/v2/load";

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


export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }): Promise<Metadata> {
  const { slug } = await params;

  const meta = await cvReadMetaLoose(slug);
  const title = (typeof meta.title === "string" && meta.title.trim().length) ? meta.title.trim() : slug;
  const m = meta as unknown as Record<string, unknown>;
  const rawDesc = (typeof m["description"] === "string") ? (m["description"] as string) : "";
  const description = rawDesc.trim().length ? rawDesc.trim() : undefined;

  return {
    title: title + " • Cadernos Vivos",
    description,
  };
}
export default async function Page({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;

  let data: Awaited<ReturnType<typeof loadCadernoV2>>;
  try {
    data = await loadCadernoV2(slug);
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