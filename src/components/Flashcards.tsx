"use client";
import { useMemo, useState } from "react";

type Flashcard = { q: string; a: string };

export default function Flashcards({ cards }: { cards: Flashcard[] }) {
  const [i, setI] = useState(0);
  const [show, setShow] = useState(false);
  const shuffled = useMemo(() => cards, [cards]);
  const cur = shuffled[i] || { q: "Sem cards ainda.", a: "" };

  const next = () => { setShow(false); setI((v) => Math.min(v + 1, shuffled.length - 1)); };
  const prev = () => { setShow(false); setI((v) => Math.max(v - 1, 0)); };

  return (
    <div className="card p-5">
      <div className="text-xs muted">Flashcard {Math.min(i + 1, shuffled.length)} / {shuffled.length}</div>
      <div className="mt-3 text-lg font-semibold">{cur.q}</div>

      <button className="mt-4 card px-3 py-2 hover:bg-white/10 transition" onClick={() => setShow((v) => !v)}>
        <span className="accent">{show ? "Ocultar resposta" : "Mostrar resposta"}</span>
      </button>

      {show ? <div className="mt-4 muted whitespace-pre-wrap">{cur.a}</div> : null}

      <div className="mt-6 flex gap-2">
        <button className="card px-3 py-2 hover:bg-white/10 transition disabled:opacity-50" onClick={prev} disabled={i === 0}>Anterior</button>
        <button className="card px-3 py-2 hover:bg-white/10 transition disabled:opacity-50" onClick={next} disabled={i >= shuffled.length - 1}>Próximo</button>
      </div>
    </div>
  );
}
