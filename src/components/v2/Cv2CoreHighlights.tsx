import Link from "next/link";

type CoreCard = {
  id: string;
  label: string;
  href: string;
  hint?: string;
};

function isRecord(v: unknown): v is Record<string, unknown> {
  return !!v && typeof v === "object" && !Array.isArray(v);
}

function asStr(v: unknown): string | null {
  return typeof v === "string" ? v : null;
}

function pickStr(o: Record<string, unknown>, keys: string[]): string | null {
  for (const k of keys) {
    const s = asStr(o[k]);
    if (s && s.trim()) return s.trim();
  }
  return null;
}

function routeFromId(idRaw: string): string {
  const id = idRaw.toLowerCase().trim();
  const map: Record<string, string> = {
    hub: "",
    mapa: "mapa",
    map: "mapa",
    linha: "linha",
    line: "linha",
    provas: "provas",
    evidencias: "provas",
    trilhas: "trilhas",
    trilha: "trilhas",
    debate: "debate",
    tempo: "linha-do-tempo",
    "linha-do-tempo": "linha-do-tempo",
    timeline: "linha-do-tempo",
  };
  return map[id] ?? id;
}

function normalizeCoreCards(meta: unknown, slug: string): CoreCard[] {
  const m = isRecord(meta) ? meta : {};
  const raw = m["coreNodes"];
  const list: unknown[] = Array.isArray(raw) ? raw : [];

  const out: CoreCard[] = [];
  for (const it of list) {
    if (typeof it === "string") {
      const id = it;
      const seg = routeFromId(id);
      const href = seg ? `/c/${slug}/v2/${seg}` : `/c/${slug}/v2`;
      out.push({ id, label: id, href });
      continue;
    }
    if (!isRecord(it)) continue;
    const id = pickStr(it, ["id","key","door","slug","name","title","label"]) ?? "node";
    const label = pickStr(it, ["label","title","name"]) ?? id;
    const hint = pickStr(it, ["hint","summary","desc","description","oneLiner"]) ?? undefined;
    const seg = routeFromId(pickStr(it, ["door","key","id","slug"]) ?? id);
    const href = seg ? `/c/${slug}/v2/${seg}` : `/c/${slug}/v2`;
    out.push({ id, label, href, hint });
  }

  if (out.length === 0) {
    const base: Array<{id: string; label: string; seg: string}> = [
      { id: "mapa", label: "Mapa", seg: "mapa" },
      { id: "linha", label: "Linha", seg: "linha" },
      { id: "provas", label: "Provas", seg: "provas" },
      { id: "debate", label: "Debate", seg: "debate" },
      { id: "trilhas", label: "Trilhas", seg: "trilhas" },
      { id: "tempo", label: "Linha do tempo", seg: "linha-do-tempo" },
    ];
    for (const b of base) out.push({ id: b.id, label: b.label, href: `/c/${slug}/v2/${b.seg}` });
  }

  const seen = new Set<string>();
  const uniq: CoreCard[] = [];
  for (const c of out) {
    if (seen.has(c.href)) continue;
    seen.add(c.href);
    uniq.push(c);
  }
  return uniq.slice(0, 9);
}

export function Cv2CoreHighlights(props: { slug: string; meta?: unknown; current?: string }) {
  const cards = normalizeCoreCards(props.meta, props.slug);
  const current = (props.current ?? "").toLowerCase().trim();
  return (
    <section className="cv2-core-highlights" data-cv2-core-highlights="1" data-cv2="core-highlights">
      <div className="cv2-core-highlights__head">
        <div className="cv2-core-highlights__title">Destaques do Núcleo</div>
        <div className="cv2-core-highlights__sub">Portas principais do universo — escolha uma rota.</div>
      </div>
      <div className="cv2-core-highlights__grid">
        {cards.map((c) => {
          const idNorm = routeFromId(c.id);
          const active = idNorm === current || c.id.toLowerCase() === current;
          return (
            <Link key={c.href} href={c.href} className={"cv2-core-highlights__card" + (active ? " is-active" : "")}>
              <div className="cv2-core-highlights__left">
                <div className="cv2-core-highlights__label">{c.label}</div>
                {c.hint ? <div className="cv2-core-highlights__hint">{c.hint}</div> : null}
              </div>
              <div className="cv2-core-highlights__go">Entrar</div>
            </Link>
          );
        })}
      </div>
    </section>
  );
}
