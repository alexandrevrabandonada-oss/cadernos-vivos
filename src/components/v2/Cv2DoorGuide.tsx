import Link from "next/link";
import type { CoreNodesV2 } from "@/lib/v2/types";
import { coreNodesToDoorOrder, doorById } from "@/lib/v2/doors";

type MetaLike = { coreNodes?: CoreNodesV2 };

const ALL = ["mapa", "linha", "linha-do-tempo", "provas", "trilhas", "debate"] as const;
type DoorId = typeof ALL[number];

type Props = {
  slug: string;
  active: string;
  coreNodes?: CoreNodesV2;
  meta?: MetaLike;
  relatedCount?: number;
};

function normalizeDoorOrder(order: string[]): DoorId[] {
  const out: DoorId[] = [];
  for (const raw of order) {
    const id = raw as DoorId;
    if ((ALL as readonly string[]).includes(id) && !out.includes(id)) out.push(id);
  }
  if (!out.includes("mapa")) out.unshift("mapa");
  for (const id of ALL) { if (!out.includes(id)) out.push(id); }
  return out;
}

function safeId(active: string): DoorId {
  const a = active as DoorId;
  if ((ALL as readonly string[]).includes(a)) return a;
  return "mapa";
}

function labelOf(id: DoorId): string {
  const d = doorById(id);
  return (d.title ? d.title : id);
}

function nextAfter(ids: DoorId[], active: DoorId): DoorId {
  const i = ids.indexOf(active);
  if (i >= 0 && i + 1 < ids.length) return ids[i + 1];
  if (ids.length > 0) return ids[0];
  return "mapa";
}

function pickRelated(ids: DoorId[], active: DoorId, count: number): DoorId[] {
  const out: DoorId[] = [];
  // regra: sempre tenta pôr "mapa" como âncora (se não for a ativa)
  if (active !== "mapa") out.push("mapa");
  // depois pega os próximos na ordem do núcleo
  const start = Math.max(0, ids.indexOf(active));
  for (let step = 1; step < ids.length && out.length < count; step++) {
    const id = ids[(start + step) % ids.length];
    if (id !== active && !out.includes(id)) out.push(id);
  }
  // completa com o resto
  for (const id of ids) {
    if (out.length >= count) break;
    if (id !== active && !out.includes(id)) out.push(id);
  }
  return out.slice(0, count);
}

export default function Cv2DoorGuide(props: Props) {
  const cn = props.coreNodes ?? props.meta?.coreNodes;
  const ids = normalizeDoorOrder(coreNodesToDoorOrder(cn));
  const active = safeId(props.active);
  const next = nextAfter(ids, active);
  const related = pickRelated(ids, active, props.relatedCount ?? 4);

  const mapHref = doorById("mapa").href(props.slug);
  const nextHref = doorById(next).href(props.slug);

  return (
    <section className="cv2-doorGuide" aria-label="Orientação do universo">
      <div className="cv2-doorGuide__row">
        <div className="cv2-doorGuide__here">
          <div className="cv2-doorGuide__kicker">Você está em</div>
          <div className="cv2-doorGuide__label">{labelOf(active)}</div>
        </div>
        <div className="cv2-doorGuide__actions">
          <Link className="cv2-doorGuide__btn is-primary" href={mapHref} title="Voltar para o mapa">
            Voltar pro Mapa
          </Link>
          <Link className="cv2-doorGuide__btn" href={nextHref} title="Próxima porta">
            Próxima: {labelOf(next)}
          </Link>
        </div>
      </div>

      <div className="cv2-doorGuide__related" role="navigation" aria-label="Relacionados">
        {related.map((id) => (
          <Link key={id} className="cv2-doorGuide__pill" href={doorById(id).href(props.slug)}>
            {labelOf(id)}
          </Link>
        ))}
      </div>
    </section>
  );
}
