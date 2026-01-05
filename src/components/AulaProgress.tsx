"use client";

import { useParams } from "next/navigation";

type Params = Record<string, string | string[]>;

function pick(v: string | string[] | undefined): string {
  if (Array.isArray(v)) return v[0] || "";
  return v || "";
}

export default function AulaProgress({
  slug: slugProp,
  total,
  current,
}: {
  slug?: string;
  total: number;
  current: number;
}) {
  const params = useParams() as Params;
  const inferred = pick(params ? params["slug"] : undefined);
  const slug = slugProp || inferred;

  const safeTotal = total > 0 ? total : 1;
  const pct = Math.max(0, Math.min(100, Math.round((current / safeTotal) * 100)));

  return (
    <section className="card p-5">
      <div className="flex items-center justify-between gap-4">
        <div>
          <div className="text-xs muted">Progresso</div>
          <div className="text-lg font-semibold mt-1">{String(current)} / {String(total)}</div>
          {slug ? <div className="text-xs muted mt-1">caderno: {slug}</div> : null}
        </div>
        <div className="text-2xl font-bold accent">{String(pct)}%</div>
      </div>
      <div className="mt-4 h-2 w-full rounded-full bg-white/10 overflow-hidden">
        <div className="h-full bg-[var(--accent)]" style={{ width: pct + "%" }} />
      </div>
    </section>
  );
}