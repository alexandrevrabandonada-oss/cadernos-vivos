import type { CoreNodesV2 } from "@/lib/v2/types";

export type DoorId = "hub" | "mapa" | "linha" | "linha-do-tempo" | "provas" | "trilhas" | "debate";
export type DoorDef = { id: DoorId; title: string; desc: string; href: (slug: string) => string };

export const DOORS: DoorDef[] = [
  { id: "hub", title: "Hub", desc: "Visão geral do universo.", href: (s) => "/c/" + encodeURIComponent(s) + "/v2" },
  { id: "mapa", title: "Mapa", desc: "A porta central (comece por aqui).", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/mapa" },
  { id: "linha", title: "Linha", desc: "Fatos em ordem e fio narrativo.", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/linha" },
  { id: "linha-do-tempo", title: "Linha do tempo", desc: "Marcos e sequência histórica.", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/linha-do-tempo" },
  { id: "provas", title: "Provas", desc: "Fontes, docs e evidências.", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/provas" },
  { id: "trilhas", title: "Trilhas", desc: "Caminhos guiados e prática.", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/trilhas" },
  { id: "debate", title: "Debate", desc: "Camadas de conversa e disputa.", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/debate" },
];

export const DOOR_SET = new Set<string>(DOORS.map((d) => d.id));

function isRecord(v: unknown): v is Record<string, unknown> {
  return !!v && typeof v === "object";
}

export function doorById(id: DoorId): DoorDef {
  const d = DOORS.find((x) => x.id === id);
  return d ? d : DOORS[1];
}

export function coreNodesToDoorOrder(coreNodes?: CoreNodesV2): DoorId[] {
  const base: DoorId[] = ["mapa","linha","provas","trilhas","debate"];
  if (!coreNodes || !coreNodes.length) return base;

  const out: DoorId[] = [];
  for (const v of coreNodes) {
    if (typeof v === "string") {
      const k = v.trim();
      if (DOOR_SET.has(k)) out.push(k as DoorId);
      continue;
    }
    if (isRecord(v)) {
      const idVal = v["id"];
      if (typeof idVal === "string") {
        const k = idVal.trim();
        if (DOOR_SET.has(k)) out.push(k as DoorId);
      }
    }
  }

  const seen = new Set<DoorId>();
  const dedup: DoorId[] = [];
  for (const d of out) {
    if (seen.has(d)) continue;
    seen.add(d);
    dedup.push(d);
  }
  return dedup.length ? dedup : base;
}

export function pickActiveDoor(active?: string, current?: string): DoorId {
  const raw = (active ? active : (current ? current : "")).toString();
  return DOOR_SET.has(raw) ? (raw as DoorId) : "mapa";
}

export function pickNextDoor(order: DoorId[], active: DoorId): DoorId {
  if (!order.length) return "mapa";
  const i = order.indexOf(active);
  if (i < 0) return order[0];
  const j = (i + 1) % order.length;
  const n = order[j];
  return n === active ? "mapa" : n;
}

export function pickRelatedDoors(order: DoorId[], active: DoorId, next: DoorId): DoorId[] {
  const out: DoorId[] = [];
  for (const d of order) {
    if (d === active) continue;
    if (d === next) continue;
    out.push(d);
  }
  for (const d of ["hub","mapa","linha","linha-do-tempo","provas","trilhas","debate"] as DoorId[]) {
    if (d === active || d === next) continue;
    if (out.includes(d)) continue;
    out.push(d);
  }
  return out.slice(0, 5);
}

