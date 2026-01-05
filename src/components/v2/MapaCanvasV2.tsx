"use client";

import React, { useEffect, useMemo, useState } from "react";

type NodeItem = {
  id: string;
  title: string;
  kind?: string;
  tags?: string[];
  x?: number;
  y?: number;
};

function isRecord(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null;
}

function asString(v: unknown): string | undefined {
  return typeof v === "string" ? v : undefined;
}

function asNumber(v: unknown): number | undefined {
  return typeof v === "number" && Number.isFinite(v) ? v : undefined;
}

function asStringArray(v: unknown): string[] | undefined {
  if (!Array.isArray(v)) return undefined;
  const out: string[] = [];
  for (const x of v) if (typeof x === "string") out.push(x);
  return out.length ? out : undefined;
}

function pickArray(obj: Record<string, unknown>, keys: string[]): unknown[] | undefined {
  for (const k of keys) {
    const v = obj[k];
    if (Array.isArray(v)) return v as unknown[];
  }
  return undefined;
}

function pickString(obj: Record<string, unknown>, keys: string[]): string | undefined {
  for (const k of keys) {
    const s = asString(obj[k]);
    if (s && s.trim()) return s;
  }
  return undefined;
}

function safeIdFrom(title: string, i: number): string {
  const base = title.toLowerCase().trim()
    .replace(/[^a-z0-9\\s_-]+/g, "")
    .replace(/\\s+/g, "-")
    .slice(0, 48);
  return (base ? base : "no") + "-" + String(i + 1);
}

function normalizeNodes(input: unknown): NodeItem[] {
  let arr: unknown[] | undefined;
  if (Array.isArray(input)) {
    arr = input;
  } else if (isRecord(input)) {
    arr = pickArray(input, ["nodes","items","list","entries","mapa","mindmap"]);
    if (!arr) {
      const m = input["mapa"];
      if (Array.isArray(m)) arr = m as unknown[];
      if (!arr && isRecord(m)) arr = pickArray(m, ["nodes","items","list","entries"]);
    }
  }
  if (!arr) return [];

  const out: NodeItem[] = [];
  for (let i = 0; i < arr.length; i++) {
    const it = arr[i];
    if (!isRecord(it)) continue;
    const title = pickString(it, ["title","titulo","name","nome","label"]) ?? ("No " + String(i + 1));
    const id = pickString(it, ["id","slug","key"]) ?? safeIdFrom(title, i);
    const kind = pickString(it, ["kind","type","tipo"]);
    const tags = asStringArray(it["tags"]) ?? asStringArray(it["tag"]);
    const x = asNumber(it["x"]) ?? asNumber(it["px"]) ?? asNumber(it["posX"]);
    const y = asNumber(it["y"]) ?? asNumber(it["py"]) ?? asNumber(it["posY"]);
    out.push({ id, title, kind, tags, x, y });
  }
  return out;
}

function clamp(n: number, a: number, b: number) {
  return Math.max(a, Math.min(b, n));
}

function readHashId(): string {
  if (typeof window === "undefined") return "";
  const h = window.location.hash || "";
  return h.startsWith("#") ? h.slice(1) : h;
}

export default function MapaCanvasV2(props: { mapa: unknown }) {
  const nodes = useMemo(() => normalizeNodes(props.mapa), [props.mapa]);
  const [selectedId, setSelectedId] = useState<string>("");

  useEffect(() => {
    const onHash = () => setSelectedId(readHashId());
    window.addEventListener("hashchange", onHash);
    const t = setTimeout(onHash, 0);
    const onSel = (ev: Event) => {
      const ce = ev as CustomEvent<{ id?: string }>;
      const id = ce.detail?.id;
      if (id) setSelectedId(id);
    };
    window.addEventListener("cv:mapa-select", onSel as unknown as EventListener);
    return () => {
      clearTimeout(t);
      window.removeEventListener("hashchange", onHash);
      window.removeEventListener("cv:mapa-select", onSel as unknown as EventListener);
    };
  }, []);

  const hasCoords = useMemo(() => {
    if (!nodes.length) return false;
    let ok = 0;
    for (const n of nodes) if (typeof n.x === "number" && typeof n.y === "number") ok++;
    return ok >= Math.ceil(nodes.length / 2);
  }, [nodes]);

  function posFor(i: number, n: NodeItem) {
    if (hasCoords && typeof n.x === "number" && typeof n.y === "number") {
      const x = (n.x >= 0 && n.x <= 1) ? n.x : (Math.abs(n.x) % 100) / 100;
      const y = (n.y >= 0 && n.y <= 1) ? n.y : (Math.abs(n.y) % 100) / 100;
      return { left: (clamp(x, 0.05, 0.95) * 100) + "%", top: (clamp(y, 0.08, 0.92) * 100) + "%" };
    }
    const angle = i * 1.7;
    const r = clamp(0.14 + i * 0.02, 0.14, 0.43);
    const x = 0.5 + r * Math.cos(angle);
    const y = 0.5 + r * Math.sin(angle);
    return { left: (clamp(x, 0.06, 0.94) * 100) + "%", top: (clamp(y, 0.10, 0.90) * 100) + "%" };
  }

  function select(id: string) {
    try {
      history.replaceState(null, "", "#" + id);
    } catch {
      // noop
    }
    try {
      window.dispatchEvent(new CustomEvent("cv:mapa-select", { detail: { id } }));
    } catch {
      // noop
    }
  }

  return (
    <div style={{
      position: "relative",
      minHeight: 520,
      borderRadius: 16,
      border: "1px solid rgba(255,255,255,0.10)",
      background: "linear-gradient(180deg, rgba(0,0,0,0.22), rgba(0,0,0,0.35))",
      overflow: "hidden",
    }}>
      <div style={{
        position: "absolute", inset: 0,
        backgroundImage: "radial-gradient(rgba(255,255,255,0.06) 1px, transparent 1px)",
        backgroundSize: "22px 22px",
        opacity: 0.35,
        pointerEvents: "none",
      }} />

      <div style={{ position: "absolute", left: 12, top: 12, zIndex: 2, display: "flex", gap: 8, flexWrap: "wrap" }}>
        <span style={{ fontSize: 12, opacity: 0.8, padding: "4px 10px", borderRadius: 999, border: "1px solid rgba(255,255,255,0.14)", background: "rgba(0,0,0,0.25)" }}>
          mapa vivo
        </span>
        <span style={{ fontSize: 12, opacity: 0.8, padding: "4px 10px", borderRadius: 999, border: "1px solid rgba(255,255,255,0.14)", background: "rgba(0,0,0,0.25)" }}>
          clique em um no para focar
        </span>
      </div>

      {nodes.map((n, i) => {
        const pos = posFor(i, n);
        const on = selectedId === n.id;
        return (
          <button
            key={n.id + "-" + String(i)}
            type="button"
            onClick={() => select(n.id)}
            style={{
              position: "absolute",
              transform: "translate(-50%, -50%)",
              left: pos.left,
              top: pos.top,
              zIndex: on ? 3 : 2,
              maxWidth: 220,
              textAlign: "left",
              borderRadius: 999,
              padding: "10px 12px",
              border: on ? "1px solid rgba(255,215,0,0.55)" : "1px solid rgba(255,255,255,0.14)",
              background: on ? "rgba(255,215,0,0.10)" : "rgba(0,0,0,0.22)",
              color: "white",
              cursor: "pointer",
              boxShadow: on ? "0 0 0 2px rgba(0,0,0,0.25)" : "none",
            }}
            aria-label={"No: " + n.title}
          >
            <div style={{ fontWeight: 800, fontSize: 13, lineHeight: 1.15 }}>
              {n.title}
            </div>
            <div style={{ opacity: 0.72, fontSize: 11, marginTop: 2 }}>
              {(n.kind ? n.kind : "ideia") + (n.tags?.length ? " • " + n.tags.slice(0,2).join(", ") : "")}
            </div>
          </button>
        );
      })}

      {!nodes.length ? (
        <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", opacity: 0.75, padding: 18 }}>
          Nenhum no encontrado no mapa deste caderno.
        </div>
      ) : null}
    </div>
  );
}