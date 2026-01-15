import Link from "next/link";
import type { CoreNodesV2 } from "@/lib/v2/types";
import { coreNodesToDoorOrder, doorById, pickActiveDoor, pickNextDoor, pickRelatedDoors } from "@/lib/v2/doors";

function isRecord(v: unknown): v is Record<string, unknown> {
  return !!v && typeof v === "object" && !Array.isArray(v);
}
type Props = { slug: string; active?: string; current?: string; coreNodes?: CoreNodesV2; meta?: unknown };

export default function Cv2PortalsCurated(props: Props) {
  const active = pickActiveDoor(props.active, props.current);
  const coreNodes =
  props.coreNodes ??
  (isRecord(props.meta) ? (props.meta["coreNodes"] as CoreNodesV2 | undefined) : undefined);
const order = coreNodesToDoorOrder(coreNodes);
  const next = pickNextDoor(order, active);
  const rel = pickRelatedDoors(order, active, next);
  const nextDoor = doorById(next);

  return (
    <section className="cv2-portals-curated" aria-label="Portais do universo" data-cv2="portals-curated">
      <div className="cv2-portals-curated__head">
        <div className="cv2-portals-curated__kicker">Portais</div>
        <div className="cv2-portals-curated__title">Próxima porta</div>
        <div className="cv2-portals-curated__sub">Siga o fio: atravessar é aprender.</div>
      </div>

      <div className="cv2-portals-curated__next">
        <Link className="cv2-portal-card cv2-portal-card--next" href={nextDoor.href(props.slug)}>
          <div className="cv2-portal-card__title">{nextDoor.title}</div>
          <div className="cv2-portal-card__desc">{nextDoor.desc}</div>
        </Link>

        {active !== "mapa" ? (
          <Link className="cv2-portal-pill" href={doorById("mapa").href(props.slug)} title="Comece pelo mapa">
            Comece pelo Mapa
          </Link>
        ) : null}
      </div>

      <div className="cv2-portals-curated__relHead">Relacionados</div>
      <div className="cv2-portals-curated__grid">
        {rel.map((id) => {
          const d = doorById(id);
          return (
            <Link key={d.id} className="cv2-portal-card" href={d.href(props.slug)}>
              <div className="cv2-portal-card__title">{d.title}</div>
              <div className="cv2-portal-card__desc">{d.desc}</div>
            </Link>
          );
        })}
      </div>
    </section>
  );
}

