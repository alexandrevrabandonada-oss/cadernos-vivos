import Link from "next/link";
import type { Cv2DoorId } from "@/components/v2/Cv2V2Nav";

type Props = {
  slug: string;
  active: Cv2DoorId;
  className?: string;
};

const ORDER: Cv2DoorId[] = ["hub", "mapa", "linha", "linha-do-tempo", "provas", "trilhas", "debate"];

function labelOf(id: Cv2DoorId): string {
  switch (id) {
    case "hub": return "Hub";
    case "mapa": return "Mapa";
    case "linha": return "Linha";
    case "linha-do-tempo": return "Linha do tempo";
    case "provas": return "Provas";
    case "trilhas": return "Trilhas";
    case "debate": return "Debate";
    default: return id;
  }
}

function nextOf(active: Cv2DoorId): Cv2DoorId {
  const i = ORDER.indexOf(active);
  if (i >= 0 && i + 1 < ORDER.length) return ORDER[i + 1];
  if (ORDER.length > 0) return ORDER[0];
  return "mapa";
}

function prevOf(active: Cv2DoorId): Cv2DoorId {
  const i = ORDER.indexOf(active);
  if (i > 0) return ORDER[i - 1];
  if (ORDER.length > 0) return ORDER[ORDER.length - 1];
  return "hub";
}

function hrefFor(slug: string, id: Cv2DoorId): string {
  const s = encodeURIComponent(slug);
  const base = "/c/" + s + "/v2";
  if (id === "hub") return base;
  return base + "/" + id;
}

export default function Cv2DoorGuide({ slug, active, className }: Props) {
  const prev = prevOf(active);
  const next = nextOf(active);

  return (
    <section data-cv2="door-guide" className={className} style={{ marginTop: 12 }}>
      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 10 }}>
        <div>
          <div style={{ fontSize: 12, opacity: 0.7 }}>Você está em</div>
          <div style={{ fontSize: 14, fontWeight: 700 }}>{labelOf(active)}</div>
        </div>
        <div style={{ display: "flex", gap: 8 }}>
          <Link className="cv2-btn" href={hrefFor(slug, prev)} aria-label={"Voltar: " + labelOf(prev)}>
            Voltar
          </Link>
          <Link className="cv2-btn cv2-btn--accent" href={hrefFor(slug, next)} aria-label={"Próxima: " + labelOf(next)}>
            Próxima porta
          </Link>
        </div>
      </div>
    </section>
  );
}
