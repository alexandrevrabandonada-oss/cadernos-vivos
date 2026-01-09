
import Link from "next/link";
import React from "react";

type MetaLike = Record<string, unknown> | null | undefined;

type RailProps = {
  slug: string;
  title?: string;
  meta?: MetaLike | unknown;
};

type RailPage = {
  id: string;
  label: string;
  href: (slug: string) => string;
};

const PAGES: RailPage[] = [
  { id: "hub", label: "Hub", href: (s) => "/c/" + encodeURIComponent(s) + "/v2" },
  { id: "mapa", label: "Mapa", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/mapa" },
  { id: "linha", label: "Linha", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/linha" },
  { id: "linha-do-tempo", label: "Tempo", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/linha-do-tempo" },
  { id: "provas", label: "Provas", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/provas" },
  { id: "trilhas", label: "Trilhas", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/trilhas" },
  { id: "debate", label: "Debate", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/debate" },
];

function safeSlug(v: unknown): string {
  return (typeof v === "string" ? v : "").trim();
}

export function Cv2MapRail(props: RailProps) {
  const slug = safeSlug(props.slug);
  if (!slug) return null;
  const title = (typeof props.title === "string" && props.title.trim().length) ? props.title.trim() : slug;

  return (
    <aside className="cv2-mapRail" aria-label="Corredor de portas">
      <div className="cv2-mapRail__inner">
        <div className="cv2-mapRail__title">
          <div className="cv2-mapRail__kicker">Eixo</div>
          <div className="cv2-mapRail__name">{title}</div>
        </div>

        <nav className="cv2-mapRail__nav" aria-label="Portas do universo">
          {PAGES.map((p) => (
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
