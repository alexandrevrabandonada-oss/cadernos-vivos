import Link from "next/link";

type CoreNode = {
  key: string;
  href: string;
  label: string;
  desc: string;
  badge?: string;
  primary?: boolean;
};

function buildNodes(slug: string): CoreNode[] {
  const base = "/c/" + slug + "/v2";
  return [
    { key: "mapa", href: base + "/mapa", label: "Mapa", desc: "Começar por aqui: visão geral do universo.", badge: "Eixo", primary: true },
    { key: "linha", href: base + "/linha", label: "Linha", desc: "Fatos, tópicos e entradas conectadas.", badge: "Rastro" },
    { key: "linha-do-tempo", href: base + "/linha-do-tempo", label: "Linha do tempo", desc: "Cronologia e memória em camadas." },
    { key: "provas", href: base + "/provas", label: "Provas", desc: "Evidências, fontes e checagens." },
    { key: "trilhas", href: base + "/trilhas", label: "Trilhas", desc: "Percursos guiados: do básico ao profundo.", badge: "Guia" },
    { key: "debate", href: base + "/debate", label: "Debate", desc: "Discussão e sínteses do coletivo." },
  ];
}

export default function Cv2CoreNodes(props: { slug: string; title?: string }) {
  const slug = props.slug;
  const title = props.title;
  const nodes = buildNodes(slug);

  return (
    <section className="cv2-coreWrap" aria-label="Núcleo do universo">
      <div className="cv2-coreHead">
        <div className="cv2-coreTitle">Núcleo do universo</div>
        <div className="cv2-coreSub">{title ? title : slug}</div>
      </div>

      <div className="cv2-coreGrid">
        {nodes.map((n) => (
          <Link
            key={n.key}
            href={n.href}
            prefetch={false}
            className={n.primary ? "cv2-coreCard cv2-coreCard--primary" : "cv2-coreCard"}
          >
            <div className="cv2-coreCardTop">
              <div className="cv2-coreCardLabel">{n.label}</div>
              {n.badge ? <div className="cv2-coreBadge">{n.badge}</div> : null}
            </div>
            <div className="cv2-coreCardDesc">{n.desc}</div>
            {n.primary ? <div className="cv2-coreCta">Começar pelo Mapa →</div> : <div className="cv2-coreCta">Abrir →</div>}
          </Link>
        ))}
      </div>
    </section>
  );
}