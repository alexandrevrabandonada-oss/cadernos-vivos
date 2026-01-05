import Link from "next/link";
import { listCadernos } from "@/lib/cadernos-index";

type AccentStyle = React.CSSProperties & { ["--accent"]?: string };

export default async function Page() {
  const items = await listCadernos();

  return (
    <main className="space-y-6">
      <section className="card p-6">
        <div className="text-xs muted">Hub</div>
        <h1 className="text-2xl font-semibold mt-1">Cadernos Vivos</h1>
        <p className="muted mt-2">
          Um acervo vivo: leitura, prática, debate e registro. Cada caderno nasce do território.
        </p>
        <div className="mt-4 flex flex-wrap gap-2">
          <Link className="card px-3 py-2 hover:bg-white/10 transition" href="/c">
            <span className="accent">Ver índice</span>
          </Link>
        </div>
      </section>

      <section className="space-y-3">
        <div className="flex items-end justify-between">
          <h2 className="text-xl font-semibold">Cadernos</h2>
          <div className="text-sm muted">{items.length} encontrado(s)</div>
        </div>

        {items.length === 0 ? (
          <div className="card p-6">
            <div className="text-lg font-semibold">Nenhum caderno encontrado</div>
            <p className="muted mt-2">
              Crie uma pasta em content/cadernos/NOME e adicione caderno.json para aparecer aqui.
            </p>
          </div>
        ) : (
          <div className="grid gap-3">
            {items.map((c) => {
              const s: AccentStyle = c.accent ? { ["--accent"]: c.accent } : {};
              return (
                <Link
                  key={c.slug}
                  href={"/c/" + c.slug}
                  className="card p-6 hover:bg-white/5 transition"
                  style={s}
                >
                  <div className="text-xs muted">/c/{c.slug}</div>
                  <div className="text-xl font-semibold mt-1">{c.title}</div>
                  {c.subtitle ? <div className="muted mt-2">{c.subtitle}</div> : null}
                  <div className="mt-3 text-sm accent">Abrir caderno</div>
                </Link>
              );
            })}
          </div>
        )}
      </section>
    </main>
  );
}