import type { CSSProperties } from "react";
import { getCaderno } from "@/lib/cadernos";
import DebateBoard from "@/components/DebateBoard";
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
  const prompts = (data.debate && data.debate.length) ? data.debate : [
    { id: "P1", title: "O que está acontecendo?", prompt: "Descreva o fenômeno sem moralismo (estrutura, território, rotina)." },
    { id: "P2", title: "Quem paga o custo?", prompt: "Exposição • vulnerabilidade • proteção: onde pesa mais e por quê." },
    { id: "P3", title: "Que dado falta?", prompt: "O que você precisaria medir/confirmar (sem travar na ausência)." },
  ];
  return (
    <CadernoShell title={data.meta.title} subtitle={data.meta.subtitle} ethos={data.meta.ethos} style={s}>
<div className="card p-5">
        <h2 className="text-xl font-semibold">Debate</h2>
        <p className="muted mt-2">Quadro de síntese (salva no seu aparelho). Fecha com pedido concreto + ajuda mútua.</p>
      </div>
      <DebateBoard slug={slug} prompts={prompts} />
    </CadernoShell>
  );
}