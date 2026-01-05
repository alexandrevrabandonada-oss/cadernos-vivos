import type { CSSProperties } from "react";
import { getCaderno } from "@/lib/cadernos";
import RegistroPanel from "@/components/RegistroPanel";
import CadernoShell from "@/components/CadernoShell";
import { notFound } from "next/navigation";
type AccentStyle = CSSProperties & { ["--accent"]?: string };
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
  const s: AccentStyle = { ["--accent"]: data.meta.accent };
  return (
    <CadernoShell title={data.meta.title} subtitle={data.meta.subtitle} ethos={data.meta.ethos} style={s}>
<RegistroPanel slug={slug} />
    </CadernoShell>
  );
}