import type { CSSProperties } from "react";
import { getCaderno } from "@/lib/cadernos";
import V2Nav from "@/components/v2/V2Nav";
import ProvasV2 from "@/components/v2/ProvasV2";

type AnyParams = { slug: string } | Promise<{ slug: string }>; 
type AnyObj = Record<string, unknown>;

function isObj(v: unknown): v is AnyObj {
  return !!v && typeof v === "object" && !Array.isArray(v);
}

async function getSlug(params: AnyParams): Promise<string> {
  const p = await Promise.resolve(params as unknown as { slug: string });
  return (p && p.slug) ? p.slug : "";
}

export default async function Page({ params }: { params: AnyParams }) {
  const slug = await getSlug(params);
  const data = await getCaderno(slug);

  const title = (data && (data as unknown as { title?: string }).title) ? (data as unknown as { title: string }).title : slug;
  const meta = (data && (data as unknown as { meta?: unknown }).meta !== undefined) ? (data as unknown as { meta?: unknown }).meta : null;

  const accent = (isObj(meta) && typeof meta["accent"] === "string") ? String(meta["accent"]) : "#F5C400";
  const bar: CSSProperties = { height: 3, borderRadius: 999, background: accent, opacity: 0.9 };

  return (
    <main style={{ padding: 18, maxWidth: 1100, margin: "0 auto" }}>
      <div style={bar} />
      <V2Nav slug={slug} active={"provas"} />
      <div style={{ marginTop: 12 }}>
        <ProvasV2 slug={slug} title={title} />
      </div>
    </main>
  );
}