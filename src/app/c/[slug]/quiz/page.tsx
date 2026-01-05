import type { CSSProperties } from "react";
import { getCaderno } from "@/lib/cadernos";
import Quiz from "@/components/Quiz";
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
        <h2 className="text-xl font-semibold">Quiz</h2>
        <p className="muted mt-2">Sem tribunal: o quiz é só ferramenta de revisão.</p>
      </div>
      <Quiz qs={data.quiz} />
    </CadernoShell>
  );
}