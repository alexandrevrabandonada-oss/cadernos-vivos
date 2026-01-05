import { notFound } from "next/navigation";
import V2Nav from "@/components/v2/V2Nav";
import { LinhaDoTempoV2 } from "@/components/v2/LinhaDoTempoV2";
import { loadCadernoV2 } from "@/lib/v2";

export default async function Page({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const data = await loadCadernoV2(slug);
  if (!data) return notFound();

  const anyData = data as unknown as Record<string, unknown>;
  const title0 = (typeof anyData.title === "string" && anyData.title) ? (anyData.title as string) : slug;
  const mapa = anyData.mapa ? anyData.mapa : anyData.data;
  const linha = anyData.linhaDoTempo ? anyData.linhaDoTempo : (anyData.timeline ? anyData.timeline : (mapa && typeof mapa === "object" ? (mapa as Record<string, unknown>).linhaDoTempo : undefined));

  return (
    <main className="min-h-screen">
      <V2Nav slug={slug} active="linha" />
      <LinhaDoTempoV2 slug={slug} title={title0} linha={linha} mapa={mapa} />
    </main>
  );
}