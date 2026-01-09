import Link from "next/link";

type Item = { key: string; href: (slug: string) => string; title: string; desc: string };

const CORE: Item[] = [
  { key: "mapa", href: (s) => "/c/" + s + "/v2/mapa", title: "Mapa", desc: "O eixo do universo: lugares, conexões e portas." },
  { key: "linha", href: (s) => "/c/" + s + "/v2/linha", title: "Linha", desc: "Nós do universo: temas, cenas, atores e tensões." },
  { key: "linha-do-tempo", href: (s) => "/c/" + s + "/v2/linha-do-tempo", title: "Linha do tempo", desc: "Sequência, memória e viradas da história." },
  { key: "provas", href: (s) => "/c/" + s + "/v2/provas", title: "Provas", desc: "Fontes, links, documentos e rastros." },
  { key: "trilhas", href: (s) => "/c/" + s + "/v2/trilhas", title: "Trilhas", desc: "Caminhos guiados: do básico ao profundo." },
  { key: "debate", href: (s) => "/c/" + s + "/v2/debate", title: "Debate", desc: "Conversa em camadas: crítica + cuidado." },
];

export default function V2CoreNodes({ slug }: { slug: string }) {
  return (
    <section aria-label="Núcleo do universo">
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", gap: 12, flexWrap: "wrap" }}>
        <h2 style={{ fontSize: 16, margin: 0 }}>Núcleo do universo</h2>
        <div style={{ fontSize: 12, opacity: 0.7 }}>{CORE.length} portas essenciais</div>
      </div>

      <div style={{ display: "grid", gap: 10, gridTemplateColumns: "repeat(auto-fit, minmax(230px, 1fr))", marginTop: 10 }}>
        {CORE.map((x) => {
          const isPrimary = x.key === "mapa";
          const cls = "cv2-card" + (isPrimary ? " cv2-card--primary" : "");
          return (
            <Link key={x.key} href={x.href(slug)} className={cls}>
              <div style={{ display: "flex", alignItems: "baseline", justifyContent: "space-between", gap: 10 }}>
                <div className="cv2-cardTitle">{x.title}</div>
                {isPrimary ? <span className="cv2-pill">Comece aqui</span> : null}
              </div>
              <div className="cv2-cardDesc">{x.desc}</div>
            </Link>
          );
        })}
      </div>
    </section>
  );
}
