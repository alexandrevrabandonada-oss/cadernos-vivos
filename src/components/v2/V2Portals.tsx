import Link from "next/link";

type DoorId = "hub" | "mapa" | "linha" | "linha-do-tempo" | "provas" | "trilhas" | "debate";

type Props = {
  slug?: string;
  /** use este */
  active?: DoorId | string;
  /** alias (legacy) */
  current?: DoorId | string;
  title?: string;
};

type Door = { id: DoorId; label: string; href: (slug: string) => string; hint: string };

const DOORS: Door[] = [
  { id: "hub", label: "Hub", href: (slug) => ("/c/" + slug + "/v2"), hint: "Núcleo do universo." },
  { id: "mapa", label: "Mapa", href: (slug) => ("/c/" + slug + "/v2/mapa"), hint: "Lugares, conexões e portas." },
  { id: "linha", label: "Linha", href: (slug) => ("/c/" + slug + "/v2/linha"), hint: "Nós do universo: temas e tensões." },
  { id: "linha-do-tempo", label: "Linha do tempo", href: (slug) => ("/c/" + slug + "/v2/linha-do-tempo"), hint: "Sequência e viradas." },
  { id: "provas", label: "Provas", href: (slug) => ("/c/" + slug + "/v2/provas"), hint: "Fontes, links e rastros." },
  { id: "trilhas", label: "Trilhas", href: (slug) => ("/c/" + slug + "/v2/trilhas"), hint: "Caminhos guiados." },
  { id: "debate", label: "Debate", href: (slug) => ("/c/" + slug + "/v2/debate"), hint: "Conversa em camadas." },
];

const ORDER: DoorId[] = ["mapa","linha","linha-do-tempo","provas","trilhas","debate"];

function normDoor(x: string | undefined): DoorId {
  const v = (x || "").trim().toLowerCase();
  if (v === "hub") return "hub";
  if (v === "mapa") return "mapa";
  if (v === "linha") return "linha";
  if (v === "linha-do-tempo" || v === "linhadotempo") return "linha-do-tempo";
  if (v === "provas") return "provas";
  if (v === "trilhas") return "trilhas";
  if (v === "debate") return "debate";
  return "hub";
}

function nextDoors(current: DoorId): DoorId[] {
  if (current === "hub") return ["mapa","linha","provas"];
  const i = ORDER.indexOf(current);
  if (i < 0) return ["mapa","linha","provas"];
  const a = ORDER[(i + 1) % ORDER.length];
  const b = ORDER[(i + 2) % ORDER.length];
  const c = ORDER[(i + 3) % ORDER.length];
  return [a,b,c];
}

export default function V2Portals(props: Props) {
  const slug = (props.slug || "").trim();
  if (!slug) return null;

  const current = normDoor((props.active as string) || (props.current as string));
  const next = nextDoors(current);
  const pick = (id: DoorId) => DOORS.find(d => d.id === id)!;

  return (
    <section className="cv2-portals" aria-label="Portais">
      <div className="cv2-portals__top">
        <div className="cv2-portals__title">
          <div className="cv2-portals__kicker">Portais</div>
          <div className="cv2-portals__h">Próximas portas</div>
          <div className="cv2-portals__p">Mapa primeiro. Depois Linha → Provas → Trilhas → Debate.</div>
        </div>

        <div className="cv2-portals__chiprow">
          <Link className="cv2-chip" href={pick("hub").href(slug)}>Voltar ao Hub</Link>
          <Link className="cv2-chip cv2-chip--accent" href={pick("mapa").href(slug)}>Começar pelo Mapa →</Link>
        </div>
      </div>

      <div className="cv2-portals__grid">
        {next.map((id) => {
          const d = pick(id);
          const isCur = current === id;
          return (
            <Link key={id} href={d.href(slug)} className={"cv2-portal" + (isCur ? " cv2-portal--current" : "")}>
              <div className="cv2-portal__row">
                <div className="cv2-portal__label">{d.label}</div>
                <div className="cv2-portal__btn">abrir</div>
              </div>
              <div className="cv2-portal__hint">{d.hint}</div>
            </Link>
          );
        })}
      </div>

      <div className="cv2-portals__foot">Você está em <b>{pick(current).label}</b>. Use os portais para navegar sem se perder.</div>
    </section>
  );
}