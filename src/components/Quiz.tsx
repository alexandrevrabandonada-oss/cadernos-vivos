"use client";
import { useMemo, useState } from "react";

type QuizQ = { q: string; choices: string[]; answer: number };

export default function Quiz({ qs }: { qs: QuizQ[] }) {
  const [picked, setPicked] = useState<Record<number, number>>({});
  const score = useMemo(() => {
    let s = 0;
    for (let idx = 0; idx < qs.length; idx++) {
      if (picked[idx] === qs[idx].answer) s++;
    }
    return s;
  }, [picked, qs]);

  if (!qs || qs.length === 0) return <div className="card p-5 muted">Sem quiz ainda.</div>;

  return (
    <div className="card p-5">
      <div className="text-sm muted">Pontuação: <span className="accent">{score}</span> / {qs.length}</div>
      <div className="mt-5 space-y-6">
        {qs.map((q, idx) => (
          <div key={idx} className="card p-4">
            <div className="font-semibold">{idx + 1}. {q.q}</div>
            <div className="mt-3 grid gap-2">
              {q.choices.map((c, ci) => {
                const isPicked = picked[idx] === ci;
                const isRight = q.answer === ci;
                const showState = picked[idx] !== undefined;
                const cls = showState
                  ? (isRight ? "border border-white/10" : (isPicked ? "border border-red-500/50" : "border border-white/10"))
                  : "border border-white/10";
                return (
                  <button
                    key={ci}
                    className={"text-left rounded-xl px-3 py-2 hover:bg-white/10 transition " + cls}
                    onClick={() => setPicked((prev) => ({ ...prev, [idx]: ci }))}
                  >
                    <span className={isRight && showState ? "accent" : ""}>{c}</span>
                  </button>
                );
              })}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
