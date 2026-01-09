import Link from "next/link";

type Props = {
  slug: string;
  current?: string;
  title?: string;
};

export default function Cv2MapFirstCta(props: Props) {
  const current = (props.current || "").trim();
  if (current === "mapa") return null;
  const href = "/c/" + props.slug + "/v2/mapa";
  return (
    <div className="cv2-mapfirst" role="note" aria-label="Comece pelo Mapa">
      <div className="cv2-mapfirst__inner">
        <div className="cv2-mapfirst__mark" aria-hidden="true">◎</div>
        <div className="cv2-mapfirst__text">
          <div className="cv2-mapfirst__title">Comece pelo Mapa</div>
          <div className="cv2-mapfirst__sub">É onde as portas se conectam e a história ganha chão.</div>
        </div>
        <div className="cv2-mapfirst__actions">
          <Link className="cv2-mapfirst__btn" href={href}>Abrir mapa</Link>
        </div>
      </div>
    </div>
  );
}
