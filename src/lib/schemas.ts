import { z } from "zod";

// ---- base helpers ----
function parseJson<T>(raw: string, schema: z.ZodType<T>, label: string): T {
  let obj: unknown;
  try {
    obj = JSON.parse(raw);
  } catch {
    throw new Error("JSON invalido em " + label);
  }
  const r = schema.safeParse(obj);
  if (!r.success) {
    const msg = r.error.issues.map((i) => i.path.join(".") + ": " + i.message).join("; ");
    throw new Error("Schema invalido em " + label + ": " + msg);
  }
  return r.data;
}

// ---- caderno.json ----
export const CadernoMetaSchema = z.object({
  title: z.string().min(1),
  subtitle: z.string().optional(),
  ethos: z.string().optional(),
  accent: z.string().optional(),
}).passthrough();

export const CadernoSchema = z.object({
  meta: CadernoMetaSchema,
}).passthrough();

export type CadernoData = z.infer<typeof CadernoSchema>;

export function parseCadernoJson(raw: string): CadernoData {
  return parseJson(raw, CadernoSchema, "caderno.json");
}

// ---- mapa.json ----
export const MapPointSchema = z.object({
  id: z.string().min(1),
  title: z.string().optional(),
  label: z.string().optional(),
  name: z.string().optional(),
  lat: z.number(),
  lng: z.number(),
  kind: z.string().optional(),
  notes: z.string().optional(),
  tags: z.array(z.string()).optional(),
}).passthrough();

export const MapSchema = z.object({
  points: z.array(MapPointSchema).default([]),
}).passthrough();

export type MapPoint = z.infer<typeof MapPointSchema>;
export type MapData = z.infer<typeof MapSchema>;

export function parseMapaJson(raw: string): MapData {
  return parseJson(raw, MapSchema, "mapa.json");
}

// ---- debate.json ----
export const DebatePromptSchema = z.object({
  id: z.string().min(1),
  title: z.string().min(1),
  prompt: z.string().min(1),
}).passthrough();

export const DebateSchema = z.union([
  z.object({ prompts: z.array(DebatePromptSchema) }).passthrough(),
  z.array(DebatePromptSchema).transform((prompts) => ({ prompts })),
]);

export type DebateData = z.infer<typeof DebateSchema>;
export type DebatePrompt = z.infer<typeof DebatePromptSchema>;

export function parseDebateJson(raw: string): { prompts: DebatePrompt[] } {
  const data = parseJson(raw, DebateSchema, "debate.json");
  // union garante objeto com prompts
  return (data as unknown) as { prompts: DebatePrompt[] };
}

// ---- acervo.json ----
export const AcervoItemSchema = z.object({
  file: z.string().min(1),
  title: z.string().min(1),
  kind: z.string().min(1),
  tags: z.array(z.string()).default([]),
}).passthrough();

export const AcervoSchema = z.array(AcervoItemSchema);
export type AcervoItem = z.infer<typeof AcervoItemSchema>;
export type AcervoData = z.infer<typeof AcervoSchema>;

export function parseAcervoJson(raw: string): AcervoData {
  return parseJson(raw, AcervoSchema, "acervo.json");
}