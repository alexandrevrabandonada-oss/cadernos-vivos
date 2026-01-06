import { getCaderno } from "@/lib/cadernos";
import V2Nav from "@/components/v2/V2Nav";
import TrilhasV2 from "@/components/v2/TrilhasV2";

type SlugParams = { slug: string };

async function getSlug(params: unknown): Promise<string> {
  const p = (await Promise.resolve(params)) as Partial<SlugParams>;
  return typeof p?.slug === "string" ? p.slug : "";
}

export default async function Page({ params }: { params: unknown }) {
  const slug = await getSlug(params);
  const caderno = await getCaderno(slug);
  const title = (caderno && (caderno as unknown as { title?: string }).title) ? (caderno as unknown as { title: string }).title : slug;

  return (
    <main style={{ padding: 18, maxWidth: 1100, margin: "0 auto" }}>
      <V2Nav slug={slug} active="trilhas" />
      <div style={{ marginTop: 12 }}>
        <TrilhasV2 slug={slug} title={title} />
      </div>
    </main>
  );
}