import V2Nav from "@/components/v2/V2Nav";


import Cv2MindmapHubClient from "@/components/v2/Cv2MindmapHubClient";








import V2QuickNav from "@/components/v2/V2QuickNav";
import { loadCadernoV2 } from "@/lib/v2";








import { cvReadMetaLoose } from "@/lib/v2/load";








import type { Metadata } from "next";
import Cv2CoreNodes from "@/components/v2/Cv2CoreNodes";
import V2Portals from "@/components/v2/V2Portals";
import Cv2MapFirstCta from "@/components/v2/Cv2MapFirstCta";
import Cv2UniverseRail from "@/components/v2/Cv2UniverseRail";

















type AnyParams = { slug: string } | Promise<{ slug: string }>;

















async function getSlug(params: AnyParams): Promise<string> {








  const p = await Promise.resolve(params as unknown as { slug: string });








  return p && typeof p.slug === "string" ? p.slug : "";








}

















export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }): Promise<Metadata> {








  const slug = await getSlug(params);








  const meta = await cvReadMetaLoose(slug);








  const title0 = typeof meta.title === "string" && meta.title.trim().length ? meta.title.trim() : slug;








  const m = meta as unknown as Record<string, unknown>;








  const rawDesc = typeof m["description"] === "string" ? (m["description"] as string) : "";








  const description = rawDesc.trim().length ? rawDesc.trim() : undefined;








  return { title: title0 + " • Cadernos Vivos", description };








}

















export default async function Page({ params }: { params: AnyParams }) {








  const slug = await getSlug(params);








  const caderno = await loadCadernoV2(slug);








  const title0 =








    caderno && typeof (caderno as unknown as { title?: string }).title === "string"








      ? (caderno as unknown as { title: string }).title








      : slug;

















  return (








    <div id="cv2-hub-root">








      <div className="cv2-layout">
  <Cv2UniverseRail slug={slug} active="hub" />
  <main style={{ padding: 18, maxWidth: 1100, margin: "0 auto" }}>








        <V2Nav slug={slug} active="hub" />








        <V2QuickNav />
        <Cv2MapFirstCta slug={slug} current="hub" />

        {/* Núcleo do universo (Concreto Zen) */}
        <Cv2CoreNodes slug={slug} title={title0} />
      {/* CV2_MINDMAP_HUB */}
      <Cv2MindmapHubClient slug={slug} />

















        <div style={{ marginTop: 10 }}>








          <h1 style={{ fontSize: 22, margin: "8px 0 0" }}>{title0}</h1>








      {/* CV2_LEGACY_HUB_REMOVIDO 20260108-192304 */}








        </div>

















        <div style={{ marginTop: 14 }}>
















        </div>








            {/* CV2_PORTALS */}
      <V2Portals slug={slug} active="hub" />
</main>
</div>








    </div>








  );








}
