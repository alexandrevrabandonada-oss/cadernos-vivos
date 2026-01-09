import Link from "next/link";

export type V2NavKey = "hub" | "mapa" | "linha" | "provas" | "trilhas" | "debate";

type NavItem = { key: V2NavKey; label: string; href: (slug: string) => string; hint?: string };

const NAV: NavItem[] = [
  { key: "hub",    label: "Hub",    href: (slug) => "/c/" + slug + "/v2",              hint: "porta de entrada" },
  { key: "mapa",   label: "Mapa",   href: (slug) => "/c/" + slug + "/v2/mapa",         hint: "território / nós" },
  { key: "linha",  label: "Linha",  href: (slug) => "/c/" + slug + "/v2/linha",        hint: "cronologia" },
  { key: "provas", label: "Provas", href: (slug) => "/c/" + slug + "/v2/provas",       hint: "acervo / evidências" },
  { key: "trilhas",label: "Trilhas",href: (slug) => "/c/" + slug + "/v2/trilhas",      hint: "sequências guiadas" },
  { key: "debate", label: "Debate", href: (slug) => "/c/" + slug + "/v2/debate",       hint: "conversas" },
];

export type ShellV2Props = {
  slug: string;
  active: V2NavKey;
  title?: string;
  subtitle?: string;
  children: React.ReactNode;
};

export function ShellV2(props: ShellV2Props) {
  const slug = props.slug;
  const active = props.active;

  return (
    <div className="min-h-screen w-full bg-neutral-950 text-neutral-50">
      <header className="sticky top-0 z-40 border-b border-neutral-800 bg-neutral-950/85 backdrop-blur">
        <div className="mx-auto max-w-5xl px-4 py-3">
          <div className="flex items-center justify-between gap-3">
            <div className="flex items-center gap-3">
              <Link href={"/c/" + slug + "/v2"} className="text-sm font-semibold tracking-wide hover:opacity-90">
                ⟵ Voltar ao Hub
              </Link>
              <span className="text-xs text-neutral-400">/</span>
              <span className="text-xs text-neutral-300">Concreto Zen · V2</span>
            </div>
            <div className="text-xs text-neutral-400">#{active}</div>
          </div>

          <nav className="mt-3 flex flex-wrap gap-2">
            {NAV.map((it) => {
              const on = it.key === active;
              return (
                <Link
                  key={it.key}
                  href={it.href(slug)}
                  className={
                    "rounded-full border px-3 py-1 text-xs transition " +
                    (on
                      ? "border-yellow-300 bg-yellow-300 text-neutral-950"
                      : "border-neutral-800 bg-neutral-900/40 text-neutral-200 hover:border-neutral-600")
                  }
                  aria-current={on ? "page" : undefined}
                  title={it.hint || it.label}
                >
                  {it.label}
                </Link>
              );
            })}
          </nav>

          {(props.title || props.subtitle) ? (
            <div className="mt-4">
              {props.title ? <h1 className="text-xl font-extrabold tracking-tight">{props.title}</h1> : null}
              {props.subtitle ? <p className="mt-1 text-sm text-neutral-300">{props.subtitle}</p> : null}
            </div>
          ) : null}
        </div>
      </header>

      <main className="mx-auto max-w-5xl px-4 py-8">
        {props.children}
      </main>

      <footer className="border-t border-neutral-800 bg-neutral-950">
        <div className="mx-auto max-w-5xl px-4 py-6 text-xs text-neutral-500">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <span>V2 · Concreto Zen · orientação constante</span>
            <span>Escutar • Cuidar • Organizar</span>
          </div>
        </div>
      </footer>
    </div>
  );
}