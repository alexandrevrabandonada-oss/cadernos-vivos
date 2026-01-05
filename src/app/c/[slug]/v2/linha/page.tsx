import { getCaderno } from "@/lib/cadernos";
import V2Nav from "@/components/v2/V2Nav";
import LinhaV2 from "@/components/v2/LinhaV2";

type AnyParams = { slug: string } | Promise<{ slug: string }>;

async function getSlug(params: AnyParams): Promise<string> {
  const p = await Promise.resolve(params as unknown as { slug: string });
  return (p && p.slug) ? p.slug : "";
}

export default async function Page({ params }: { params: AnyParams }) {
  const slug = await getSlug(params);
  const caderno = await getCaderno(slug);
  const title = (caderno && (caderno as unknown as { title?: string }).title) ? (caderno as unknown as { title: string }).title : slug;

  return (
    <main style={{ padding: 18, maxWidth: 1100, margin: "0 auto" }}>
      <V2Nav slug={slug} active="linha" />
      <div style={{ marginTop: 12 }}>
        <LinhaV2 slug={slug} title={title} />
      </div>
    </main>
  );
}