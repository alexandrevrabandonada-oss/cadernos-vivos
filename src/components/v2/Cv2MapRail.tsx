import Link from "next/link";
import type { CoreNodesV2 } from "@/lib/v2/types";
import { coreNodesToDoorOrder } from "@/lib/v2/doors";

type MetaLike = { coreNodes?: CoreNodesV2 };

type RailProps = {
  slug: string;
  title?: string;
  coreNodes?: CoreNodesV2;
  meta?: MetaLike;
};

type RailDoorId = "mapa" | "linha" | "linha-do-tempo" | "provas" | "trilhas" | "debate";
type RailPage = { id: RailDoorId; label: string; href: (slug: string) => string };

const PAGES: RailPage[] = [
  { id: "mapa", label: "Mapa", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/mapa" },
  { id: "linha", label: "Linha", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/linha" },
  { id: "linha-do-tempo", label: "Tempo", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/linha-do-tempo" },
  { id: "provas", label: "Provas", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/provas" },
  { id: "trilhas", label: "Trilhas", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/trilhas" },
  { id: "debate", label: "Debate", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/debate" },
];

function orderPages(coreNodes?: CoreNodesV2): RailPage[] {
  const order = coreNodesToDoorOrder(coreNodes);
  const out: RailPage[] = [];
  for (const id of order) {
    const p = PAGES.find((x) => x.id === id);
    if (p) out.push(p);
  }
  // garante o eixo (mapa) sempre presente
  if (!out.some((p) => p.id === "mapa")) out.unshift(PAGES[0]);
  // adiciona portas restantes (ex.: linha-do-tempo) mantendo ordem local
  for (const p of PAGES) {
    if (!out.some((x) => x.id === p.id)) out.push(p);
  }
  return out;
}

export function Cv2MapRail(props: RailProps) {
  const slug = props.slug;
  const title = props.title ? props.title : "Mapa";
  const cn = props.coreNodes ? props.coreNodes : (props.meta ? props.meta.coreNodes : undefined);
  const pages = orderPages(cn);

  return (
    <aside className="cv2-mapRail" aria-label="Corredor de portas">
      <div className="cv2-mapRail__inner">
        <div className="cv2-mapRail__title">
          <div className="cv2-mapRail__kicker">Eixo</div>
          <div className="cv2-mapRail__name">{title}</div>
        </div>

        <nav className="cv2-mapRail__nav" aria-label="Portas do universo">
          {pages.map((p) => (
            <Link key={p.id} className={"cv2-mapRail__a" + (p.id === "mapa" ? " is-axis" : "")} href={p.href(slug)}>
              <span className="cv2-mapRail__dot" aria-hidden="true" />
              <span className="cv2-mapRail__txt">{p.label}</span>
            </Link>
          ))}
        </nav>

        <div className="cv2-mapRail__hint">Mapa é o eixo. O resto são portas.</div>
      </div>
    </aside>
  );
}

export default Cv2MapRail;

