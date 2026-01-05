"use client";

import { useMemo, useState } from "react";
import { useParams } from "next/navigation";
import type { MapPoint } from "@/components/TerritoryMap";

type Params = Record<string, string | string[]>;
type Saved = { notes: string; pointId?: string };

function pick(v: string | string[] | undefined): string {
  if (Array.isArray(v)) return v[0] || "";
  return v || "";
}

function keyFor(slug: string) {
  return "cv:" + slug + ":registro:v1";
}

function load(k: string): Saved {
  try {
    const raw = localStorage.getItem(k);
    if (!raw) return { notes: "" };
    const parsed = JSON.parse(raw) as unknown;
    if (!parsed || typeof parsed !== "object") return { notes: "" };
    const obj = parsed as Partial<Saved>;
    return { notes: obj.notes || "", pointId: obj.pointId };
  } catch {
    return { notes: "" };
  }
}

export default function RegistroPanel({
  slug: slugProp,
  points,
}: {
  slug?: string;
  points?: MapPoint[];
}) {
  const params = useParams() as Params;
  const inferred = pick(params ? params["slug"] : undefined);
  const slug = slugProp || inferred;

  const k = useMemo(() => (slug ? keyFor(slug) : ""), [slug]);
  const init = useMemo(() => (k ? load(k) : { notes: "" }), [k]);

  const [pointId, setPointId] = useState<string>(() => init.pointId || "");
  const [notes, setNotes] = useState<string>(() => init.notes);
  const [status, setStatus] = useState<"" | "salvo" | "copiado">("");

  const save = () => {
    if (!k) return;
    try {
      const payload: Saved = { notes, pointId: pointId || undefined };
      localStorage.setItem(k, JSON.stringify(payload));
      setStatus("salvo");
      setTimeout(() => setStatus(""), 1200);
    } catch {}
  };

  const copy = async () => {
    try {
      const payload = { slug, pointId: pointId || undefined, notes };
      await navigator.clipboard.writeText(JSON.stringify(payload, null, 2));
      setStatus("copiado");
      setTimeout(() => setStatus(""), 1200);
    } catch {}
  };

  return (
    <section className="card p-5">
      <h3 className="text-xl font-semibold">Registro</h3>
      <div className="muted mt-1">Anotações locais (no seu aparelho). Sem backend por enquanto.</div>

      {points && points.length ? (
        <div className="mt-4">
          <div className="text-sm muted">Vincular a um ponto do mapa (opcional)</div>
          <select
            className="mt-2 w-full rounded-xl border border-white/10 bg-black/20 p-3 outline-none focus:border-white/20"
            value={pointId}
            onChange={(e) => setPointId(e.target.value)}
          >
            <option value="">(sem ponto)</option>
            {points.map((p) => (
              <option key={p.id} value={p.id}>
                {(p.title || p.name || p.label || p.id) + (p.kind ? " — " + p.kind : "")}
              </option>
            ))}
          </select>
        </div>
      ) : null}

      <div className="mt-4">
        <div className="text-sm muted">Notas</div>
        <textarea
          className="mt-2 w-full rounded-xl border border-white/10 bg-black/20 p-3 outline-none focus:border-white/20"
          rows={8}
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          placeholder="O que foi visto? Onde? Quando? Qual pedido concreto? Qual micro-ação possível?"
        />
      </div>

      <div className="mt-4 flex flex-wrap gap-2">
        <button className="card px-3 py-2 hover:bg-white/10 transition" onClick={save}>
          <span className="accent">{status === "salvo" ? "Salvo!" : "Salvar"}</span>
        </button>
        <button className="card px-3 py-2 hover:bg-white/10 transition" onClick={copy}>
          <span className="accent">{status === "copiado" ? "Copiado!" : "Copiar JSON"}</span>
        </button>
      </div>
    </section>
  );
}