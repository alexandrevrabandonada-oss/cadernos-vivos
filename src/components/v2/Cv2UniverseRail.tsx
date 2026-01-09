import Link from "next/link";

type DoorKey = "hub" | "mapa" | "linha" | "linha-do-tempo" | "provas" | "trilhas" | "debate";

type Door = {
  key: DoorKey;
  label: string;
  hint: string;
  href: (slug: string) => string;
};

const DOORS: Door[] = [
  { key: "hub", label: "Hub", hint: "Visão geral do universo", href: (slug) => "/c/" + slug + "/v2" },
  { key: "mapa", label: "Mapa", hint: "Eixo de exploração (map-first)", href: (slug) => "/c/" + slug + "/v2/mapa" },
  { key: "linha", label: "Linha", hint: "Narrativa em blocos", href: (slug) => "/c/" + slug + "/v2/linha" },
  { key: "linha-do-tempo", label: "Tempo", hint: "Cronologia e eventos", href: (slug) => "/c/" + slug + "/v2/linha-do-tempo" },
  { key: "provas", label: "Provas", hint: "Fontes, anexos, evidências", href: (slug) => "/c/" + slug + "/v2/provas" },
  { key: "trilhas", label: "Trilhas", hint: "Caminhos guiados", href: (slug) => "/c/" + slug + "/v2/trilhas" },
  { key: "debate", label: "Debate", hint: "Camadas de conversa", href: (slug) => "/c/" + slug + "/v2/debate" },
];

export default function Cv2UniverseRail(props: { slug: string; active?: string; current?: string; title?: string }) {
  const activeRaw = (props.active ?? props.current ?? "hub").toString();
  const active = (DOORS.some(d => d.key === (activeRaw as DoorKey)) ? (activeRaw as DoorKey) : "hub");
  const idx = Math.max(0, DOORS.findIndex(d => d.key === active));
  const prev = idx > 0 ? DOORS[idx - 1] : undefined;
  const next = idx >= 0 && idx < DOORS.length - 1 ? DOORS[idx + 1] : undefined;

  return (
    <aside className="cv2-rail" data-cv2-static="1" aria-label="Navegação do universo">
      <div className="cv2-rail__top">
        <div className="cv2-rail__kicker">Concreto Zen</div>
        <div className="cv2-rail__title">{props.title ? props.title : "Universo"}</div>
      </div>

      <nav className="cv2-rail__nav">
        {DOORS.map((d) => {
          const on = d.key === active;
          const cls = on ? "cv2-rail__link cv2-rail__link--on" : "cv2-rail__link";
          return (
            <Link key={d.key} className={cls} href={d.href(props.slug)} title={d.hint}>
              <span className="cv2-rail__dot" aria-hidden="true" />
              <span className="cv2-rail__label">{d.label}</span>
              <span className="cv2-rail__hint">{d.hint}</span>
            </Link>
          );
        })}
      </nav>

      <div className="cv2-rail__cta">
        <Link className="cv2-rail__ctaLink" href={"/c/" + props.slug + "/v2/mapa"}>
          Mapa é o eixo →
        </Link>
      </div>

      <div className="cv2-rail__next">
        <div className="cv2-rail__nextTitle">Próximas portas</div>
        <div className="cv2-rail__nextRow">
          {prev ? <Link className="cv2-rail__pill" href={prev.href(props.slug)}>← {prev.label}</Link> : <span className="cv2-rail__pill cv2-rail__pill--off">←</span>}
          {next ? <Link className="cv2-rail__pill" href={next.href(props.slug)}>{next.label} →</Link> : <span className="cv2-rail__pill cv2-rail__pill--off">→</span>}
        </div>
      </div>
    </aside>
  );
}
