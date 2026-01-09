// CV V2 — types estáveis (sem loop de JsonValue vs undefined).
// Estratégia: sem index-signature no MetaV2. Campos opcionais simplesmente podem não existir.

export type UiDefault = "v1" | "v2";


export type CoreNodeV2 = { id: string; title?: string; hint?: string };
export type CoreNodesV2 = Array<string | CoreNodeV2>;
export type JsonPrimitive = string | number | boolean | null;
export type JsonValue = JsonPrimitive | JsonValue[] | { [k: string]: JsonValue };

export type MetaV2 = {
  
  coreNodes?: CoreNodesV2;
slug: string;
  title: string;
  subtitle?: string;
  mood: string;
  accent?: string;
  ethos?: string;
  ui?: { default?: UiDefault };
  extra?: Record<string, JsonValue>;
};

// Aliases (facilitam imports sem quebrar build)
export type MapaV2 = JsonValue;
export type AcervoV2 = JsonValue;
export type DebateV2 = JsonValue;
export type RegistroV2 = JsonValue;

export type AulaV2 = {
  id: string;
  title: string;
  slug: string;
  md?: string;
  refs?: JsonValue;
};

// Contrato do loader/normalize V2 (superset; não interfere na V1)
export type CadernoV2 = {
  meta: MetaV2;
  panoramaMd: string;
  referenciasMd: string;
  mapa: MapaV2;
  acervo: AcervoV2;
  debate: DebateV2;
  registro: RegistroV2;
  aulas: AulaV2[];
};
