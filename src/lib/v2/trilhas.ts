
export type TrailV2 = {
  id: string;
  title: string;
  summary?: string;
  steps?: string[];
  tags?: string[];
};

function isObj(v: unknown): v is Record<string, unknown> {
  return !!v && typeof v === "object" && !Array.isArray(v);
}

function asStr(v: unknown): string {
  return typeof v === "string" ? v : "";
}

function asStrArr(v: unknown): string[] {
  if (!Array.isArray(v)) return [];
  return v.filter((x) => typeof x === "string").map((x) => String(x).trim()).filter(Boolean);
}

function normTrail(raw: unknown): TrailV2 | null {
  if (!isObj(raw)) return null;
  const id = asStr(raw["id"]) || asStr(raw["slug"]) || asStr(raw["key"]);
  const title = asStr(raw["title"]) || asStr(raw["name"]) || id;
  if (!id) return null;
  const summary = asStr(raw["summary"]) || asStr(raw["desc"]) || asStr(raw["description"]);
  const steps = asStrArr(raw["steps"]);
  const tags = asStrArr(raw["tags"]);
  return { id, title, summary: summary || undefined, steps: steps.length ? steps : undefined, tags: tags.length ? tags : undefined };
}

function trailsFromArray(v: unknown): TrailV2[] {
  if (!Array.isArray(v)) return [];
  const out: TrailV2[] = [];
  for (const it of v) {
    const t = normTrail(it);
    if (t) out.push(t);
  }
  return out;
}

function trailsFromMapNodes(mapa: unknown): TrailV2[] {
  if (!isObj(mapa)) return [];
  const nodes = mapa["nodes"];
  if (!Array.isArray(nodes)) return [];
  const out: TrailV2[] = [];
  for (const n of nodes) {
    if (!isObj(n)) continue;
    const tp = asStr(n["type"]);
    if (tp !== "trail") continue;
    const t = normTrail(n);
    if (t) out.push(t);
  }
  return out;
}

export function getTrailsV2(caderno: unknown): TrailV2[] {
  if (!isObj(caderno)) return [];

  // Preferências: caderno.trilhas → panorama.trilhas → meta.trilhas → mapa.nodes(type:"trail")
  const direct = trailsFromArray(caderno["trilhas"]);
  if (direct.length) return direct;

  const panorama = caderno["panorama"];
  if (isObj(panorama)) {
    const p = trailsFromArray(panorama["trilhas"]);
    if (p.length) return p;
  }

  const meta = caderno["meta"];
  if (isObj(meta)) {
    const m = trailsFromArray(meta["trilhas"]);
    if (m.length) return m;
  }

  const mapa = caderno["mapa"];
  const fromNodes = trailsFromMapNodes(mapa);
  return fromNodes;
}

export function getTrailByIdV2(caderno: unknown, id: string): TrailV2 | null {
  const list = getTrailsV2(caderno);
  const hit = list.find((t) => t.id === id);
  return hit || null;
}