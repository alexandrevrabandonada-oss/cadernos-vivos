import { notFound } from "next/navigation";
import V2Nav from "@/components/v2/V2Nav";
import V2QuickNav from "@/components/v2/V2QuickNav";
import { LinhaDoTempoV2 } from "@/components/v2/LinhaDoTempoV2";
import { loadCadernoV2 } from "@/lib/v2";
import type { Metadata } from "next";
import { cvReadMetaLoose } from "@/lib/v2/load";
import Cv2DomFilterClient from "@/components/v2/Cv2DomFilterClient";
import Cv2MapFirstCta from "@/components/v2/Cv2MapFirstCta";
import Cv2CoreNodes from "@/components/v2/Cv2CoreNodes";
import Cv2PortalsCurated from "@/components/v2/Cv2PortalsCurated";
import Cv2DoorGuide from "@/components/v2/Cv2DoorGuide";
async function getSlug(params: Promise<{ slug: string }>): Promise<string> {
  try {
    const p = await params;
    const slug = p && typeof p["slug"] === "string" ? (p["slug"] as string) : "";
    return slug;
  } catch {
    const p = params as unknown as Record<string, unknown>;
    const slug = p && typeof p["slug"] === "string" ? (p["slug"] as string) : "";
    return slug;
  }
}
export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }): Promise<Metadata> {
  const slug = await getSlug(params);
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
  const { slug } = await Promise.resolve(params);
  const data = await loadCadernoV2(slug);
  if (!data) return notFound();
  const anyData = data as unknown as Record<string, unknown>;
  const title0 = (typeof anyData.title === "string" && anyData.title) ? (anyData.title as string) : slug;
  const mapa = anyData.mapa ? anyData.mapa : anyData.data;
  const linha = anyData.linhaDoTempo ? anyData.linhaDoTempo : (anyData.timeline ? anyData.timeline : (mapa && typeof mapa === "object" ? (mapa as Record<string, unknown>).linhaDoTempo : undefined));

  return (
    <div id="cv2-linha-do-tempo-root">
      <Cv2DomFilterClient rootId="cv2-linha-do-tempo-root" placeholder="Filtrar linha do tempo..." pageSize={24} enablePager />
    <main className="min-h-screen">
      <V2Nav slug={slug} active="linha"  />
      <Cv2DoorGuide slug={slug} active="linha-do-tempo" meta={data.meta} />
      <V2QuickNav />
      <Cv2MapFirstCta slug={slug} current="linha-do-tempo" />
      <LinhaDoTempoV2 slug={slug} title={title0} linha={linha} mapa={mapa} />
      <Cv2CoreNodes slug={slug} coreNodes={data.meta.coreNodes} />

      <Cv2PortalsCurated slug={slug} active="linha-do-tempo" />
    </main>
    </div>
  );
}
