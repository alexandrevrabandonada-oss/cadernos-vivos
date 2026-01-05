import type {
  AcervoV2, CadernoV2, DebateV2, JsonValue, MapaV2, MetaV2, RegistroV2, UiDefault
} from "./types";

function asObj(v: unknown): Record<string, unknown> | null {
  if (!v || typeof v !== "object") return null;
  return v as Record<string, unknown>;
}
function asStr(v: unknown): string | undefined {
  return typeof v === "string" ? v : undefined;
}
function asJson(v: unknown): JsonValue {
  // best-effort: se não for JSON "valido", devolve null
  if (v === null) return null;
  const t = typeof v;
  if (t === "string" || t === "number" || t === "boolean") return v as JsonValue;
  if (Array.isArray(v)) return v.map(asJson) as JsonValue;
  if (t === "object") {
    const o = v as Record<string, unknown>;
    const out: Record<string, JsonValue> = {};
    for (const k of Object.keys(o)) out[k] = asJson(o[k]);
    return out;
  }
  return null;
}

export function normalizeMetaV2(raw: unknown, fallbackSlug: string): MetaV2 {
  const o = asObj(raw) || {};
  const slug = asStr(o["slug"]) || fallbackSlug;
  const title = asStr(o["title"]) || slug;
  const subtitle = asStr(o["subtitle"]);
  const mood = asStr(o["mood"]) || "urban";
  const accent = asStr(o["accent"]);
  const ethos = asStr(o["ethos"]);

  const uiObj = asObj(o["ui"]);
  const uiDefRaw = uiObj ? asStr(uiObj["default"]) : undefined;
  const uiDefault = (uiDefRaw as UiDefault | undefined) || "v1";

  const meta: MetaV2 = { slug, title, mood, ui: { default: uiDefault } };
  if (subtitle) meta.subtitle = subtitle;
  if (accent) meta.accent = accent;
  if (ethos) meta.ethos = ethos;

  // extra: guarda chaves desconhecidas sem index-signature
  const known = new Set(["slug","title","subtitle","mood","accent","ethos","ui"]);
  const extra: Record<string, JsonValue> = {};
  for (const k of Object.keys(o)) {
    if (!known.has(k)) extra[k] = asJson(o[k]);
  }
  if (Object.keys(extra).length > 0) meta.extra = extra;

  return meta;
}

export function normalizeCadernoV2(input: unknown, fallbackSlug: string): CadernoV2 {
  const o = asObj(input) || {};
  const meta = normalizeMetaV2(o["meta"], fallbackSlug);

  const panoramaMd = asStr(o["panoramaMd"]) || "";
  const referenciasMd = asStr(o["referenciasMd"]) || "";

  const mapa = asJson(o["mapa"]) as MapaV2;
  const acervo = asJson(o["acervo"]) as AcervoV2;
  const debate = asJson(o["debate"]) as DebateV2;
  const registro = asJson(o["registro"]) as RegistroV2;

  const aulasRaw = Array.isArray(o["aulas"]) ? (o["aulas"] as unknown[]) : [];
  const aulas = aulasRaw.map((x, i) => {
    const ax = asObj(x) || {};
    const id = asStr(ax["id"]) || String(i + 1);
    const title = asStr(ax["title"]) || ("Aula " + (i + 1));
    const slug = asStr(ax["slug"]) || ("aula-" + (i + 1));
    const md = asStr(ax["md"]);
    const refs = ax["refs"] !== undefined ? asJson(ax["refs"]) : undefined;
    return refs !== undefined ? { id, title, slug, md, refs } : { id, title, slug, md };
  });

  return { meta, panoramaMd, referenciasMd, mapa, acervo, debate, registro, aulas };
}
