import V2Nav from "@/components/v2/V2Nav";
import V2QuickNav from "@/components/v2/V2QuickNav";
import TrilhasV2 from "@/components/v2/TrilhasV2";
import { loadCadernoV2 } from "@/lib/v2";
import type { Metadata } from "next";
import { cvReadMetaLoose } from "@/lib/v2/load";
import Cv2DomFilterClient from "@/components/v2/Cv2DomFilterClient";
import V2Portals from "@/components/v2/V2Portals";
import Cv2MapFirstCta from "@/components/v2/Cv2MapFirstCta";

type SlugParams = { slug: string };

async function getSlug(params: unknown): Promise<string> {
  const p = (await Promise.resolve(params)) as Partial<SlugParams>;
  return typeof p?.slug === "string" ? p.slug : "";
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
export default async function Page({ params }: { params: unknown }) {
  const slug = await getSlug(params);
  const caderno = await loadCadernoV2(slug);
  const title = (caderno && (caderno as unknown as { title?: string }).title) ? (caderno as unknown as { title: string }).title : slug;

  return (
    <div id="cv2-trilhas-root">
      <Cv2DomFilterClient rootId="cv2-trilhas-root" placeholder="Filtrar trilhas..." pageSize={24} enablePager />
    <main style={{ padding: 18, maxWidth: 1100, margin: "0 auto" }}>
      <V2Nav slug={slug} active="trilhas"  />
      <V2QuickNav />
      <Cv2MapFirstCta slug={slug} current="trilhas" />
      <div style={{ marginTop: 12 }}>
        <TrilhasV2 slug={slug} title={title} />
      </div>
      <V2Portals slug={slug} active="trilhas" />
    </main>
    </div>
  );
}
