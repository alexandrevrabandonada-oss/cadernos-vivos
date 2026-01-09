import Link from "next/link";

export type PortaisV2Props = {
  slug: string;
};

type Portal = {
  key: string;
  title: string;
  desc: string;
  href: (slug: string) => string;
};

const PORTAIS: Portal[] = [
  { key: "mapa",   title: "Mapa",   desc: "Entrar pelo território. Ver nós, rotas e portas.", href: (slug) => "/c/" + slug + "/v2/mapa" },
  { key: "linha",  title: "Linha",  desc: "Linha do tempo. O que aconteceu, quando, e o que conecta.", href: (slug) => "/c/" + slug + "/v2/linha" },
  { key: "provas", title: "Provas", desc: "Acervo e evidências. Documentos, recortes, registros.", href: (slug) => "/c/" + slug + "/v2/provas" },
  { key: "trilhas",title: "Trilhas",desc: "Caminhos guiados. Do básico ao avançado.", href: (slug) => "/c/" + slug + "/v2/trilhas" },
  { key: "debate", title: "Debate", desc: "Perguntas e respostas. Sínteses e disputas.", href: (slug) => "/c/" + slug + "/v2/debate" },
];

export function PortaisV2(props: PortaisV2Props) {
  const slug = props.slug;
  return (
    <section className="mb-8 rounded-2xl border border-neutral-800 bg-neutral-900/30 p-4">
      <div className="flex items-start justify-between gap-3">
        <div>
          <h2 className="text-sm font-bold tracking-wide text-neutral-100">Portais</h2>
          <p className="mt-1 text-xs text-neutral-300">Próximas portas do universo. Escolha um caminho.</p>
        </div>
        <span className="rounded-full border border-neutral-700 bg-neutral-950 px-2 py-1 text-[10px] text-neutral-400">
          map-first
        </span>
      </div>

      <div className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-2">
        {PORTAIS.map((p) => (
          <Link
            key={p.key}
            href={p.href(slug)}
            className="rounded-xl border border-neutral-800 bg-neutral-950/40 p-4 transition hover:border-neutral-600"
          >
            <div className="flex items-center justify-between gap-3">
              <span className="text-sm font-extrabold text-neutral-50">{p.title}</span>
              <span className="text-xs text-yellow-300">→</span>
            </div>
            <p className="mt-2 text-xs text-neutral-300">{p.desc}</p>
          </Link>
        ))}
      </div>
    </section>
  );
}