import type { CSSProperties } from "react";
import { getCaderno } from "@/lib/cadernos";
import Flashcards from "@/components/Flashcards";
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
        <h2 className="text-xl font-semibold">Prática</h2>
        <p className="muted mt-2">Flashcards pra estudar sem ansiedade: pergunta boa, resposta curta, repetição leve.</p>
      </div>
      <Flashcards cards={data.flashcards} />
    </CadernoShell>
  );
}