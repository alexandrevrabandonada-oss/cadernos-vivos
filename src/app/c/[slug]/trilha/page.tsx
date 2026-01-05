import type { CSSProperties } from "react";
import { getCaderno } from "@/lib/cadernos";
import Markdown from "@/components/Markdown";
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
<div className="card p-5">
        <h2 className="text-xl font-semibold">Trilha</h2>
        <p className="muted mt-2">Leitura guiada: do panorama ao chão da cidade. Sem excesso de burocracia.</p>
      </div>
      <div className="card p-5">
        {data.trilha ? <Markdown markdown={data.trilha} /> : <p className="muted">Sem trilha ainda. (Crie content/cadernos/[slug]/trilha.md)</p>}
      </div>
    </CadernoShell>
  );
}