"use client";

import { useMemo, useState } from "react";
import { useParams } from "next/navigation";

export type MapPoint = {
  id: string;
  title?: string;
  name?: string;
  label?: string;
  kind?: string;
  lat?: number;
  lng?: number;
  note?: string;
  tags?: string[];
};

type Params = Record<string, string | string[]>;
type Saved = { seen: Record<string, boolean> };

function pick(v: string | string[] | undefined): string {
  if (Array.isArray(v)) return v[0] || "";
  return v || "";
}

function keyFor(slug: string) {
  return "cv:" + slug + ":map:v1";
}

function load(k: string): Saved {
  try {
    const raw = localStorage.getItem(k);
    if (!raw) return { seen: {} };
    const parsed = JSON.parse(raw) as unknown;
    if (!parsed || typeof parsed !== "object") return { seen: {} };
    const obj = parsed as Partial<Saved>;
    return { seen: (obj.seen as Record<string, boolean>) || {} };
  } catch {
    return { seen: {} };
  }
}

function titleOf(p: MapPoint): string {
  return p.title || p.name || p.label || p.id;
}

export default function TerritoryMap({
  slug: slugProp,
  points,
}: {
  slug?: string;
  points: MapPoint[];
}) {
  const params = useParams() as Params;
  const inferred = pick(params ? params["slug"] : undefined);
  const slug = slugProp || inferred;

  const k = useMemo(() => (slug ? keyFor(slug) : ""), [slug]);
  const init = useMemo(() => (k ? load(k) : { seen: {} }), [k]);

  const [seen, setSeen] = useState<Record<string, boolean>>(() => init.seen);
  const [q, setQ] = useState("");

  const filtered = useMemo(() => {
    const qq = q.trim().toLowerCase();
    if (!qq) return points;
    return points.filter((p) => {
      const hay = (titleOf(p) + " " + (p.kind || "") + " " + (p.note || "")).toLowerCase();
      return hay.includes(qq);
    });
  }, [points, q]);

  const toggle = (id: string) => {
    setSeen((prev) => {
      const next = { ...prev, [id]: !prev[id] };
      if (k) {
        try { localStorage.setItem(k, JSON.stringify({ seen: next } as Saved)); } catch {}
      }
      return next;
    });
  };

  return (
    <section className="card p-5">
      <div className="flex items-center justify-between gap-4">
        <div>
          <h3 className="text-xl font-semibold">Mapa do território</h3>
          <div className="muted mt-1">Lista navegável + marcações locais (no seu aparelho).</div>
        </div>
        {slug ? <div className="text-xs muted">caderno: {slug}</div> : null}
      </div>

      <input
        className="mt-4 w-full rounded-xl border border-white/10 bg-black/20 p-3 outline-none focus:border-white/20"
        value={q}
        onChange={(e) => setQ(e.target.value)}
        placeholder="Buscar por nome, tipo ou nota..."
      />

      <div className="mt-4 grid gap-3">
        {filtered.map((p) => (
          <div key={p.id} className="card p-4">
            <div className="flex items-start justify-between gap-4">
              <div>
                <div className="text-sm font-semibold">{titleOf(p)}</div>
                <div className="text-xs muted mt-1">{p.kind ? p.kind : "ponto"}</div>
                {p.note ? <div className="muted mt-2 text-sm whitespace-pre-wrap">{p.note}</div> : null}
              </div>
              <button
                className="card px-3 py-2 hover:bg-white/10 transition text-sm"
                onClick={() => toggle(p.id)}
              >
                <span className="accent">{seen[p.id] ? "Marcado" : "Marcar"}</span>
              </button>
            </div>
            {typeof p.lat === "number" && typeof p.lng === "number" ? (
              <a
                className="muted text-xs mt-3 inline-block hover:text-white transition"
                target="_blank"
                rel="noreferrer"
                href={"https://www.google.com/maps?q=" + String(p.lat) + "," + String(p.lng)}
              >
                Abrir no mapa
              </a>
            ) : null}
          </div>
        ))}
      </div>
    </section>
  );
}