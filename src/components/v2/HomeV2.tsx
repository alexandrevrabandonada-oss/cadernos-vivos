import Link from "next/link";

type Card = { k: string; href: string; title: string; desc: string };
type Chip = { k: string; href: string; label: string };

export function HomeV2(props: { slug: string; title: string; summary?: string }) {
  const base = "/c/" + props.slug;

  const big: Card[] = [
    {
      k: "mapa",
      href: base + "/v2/mapa",
      title: "Mapa vivo",
      desc: "Conecta temas, lugares e relações. O caderno como território navegável.",
    },
    {
      k: "provas",
      href: base + "/v2/provas",
      title: "Provas e acervo",
      desc: "Documentos, recortes e evidências. Memória organizada (sem perder o fio).",
    },
    {
      k: "debate",
      href: base + "/v2/debate",
      title: "Debate guiado",
      desc: "Perguntas-ferramenta: impacto, contexto, crítica, humanização e convocação.",
    },
  ];

  const chips: Chip[] = [
    { k: "linha", href: base + "/v2/linha-do-tempo", label: "Linha do tempo" },
    { k: "trilhas", href: base + "/v2/trilhas", label: "Trilhas" },
  ];

  return (
    <div style={{ display: "grid", gap: 12 }}>
      <header
        style={{
          border: "1px solid rgba(255,255,255,0.10)",
          borderRadius: 16,
          padding: 14,
          background: "rgba(0,0,0,0.22)",
        }}
      >
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 12 }}>
          <div style={{ display: "flex", flexDirection: "column", gap: 4 }}>
            <div style={{ fontSize: 12, opacity: 0.75, fontWeight: 800 }}>Caderno Vivo — V2</div>
            <div style={{ fontSize: 20, fontWeight: 950, letterSpacing: -0.2 }}>{props.title}</div>
          </div>
          <div
            style={{
              width: 34,
              height: 34,
              borderRadius: 999,
              border: "1px solid rgba(255,255,255,0.12)",
              background: "rgba(255,255,255,0.04)",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
            }}
            title="Assinatura do caderno (accent)"
          >
            <div style={{ width: 14, height: 14, borderRadius: 999, background: "var(--accent)" }} />
          </div>
        </div>

        {props.summary ? (
          <div style={{ marginTop: 10, fontSize: 13, lineHeight: 1.45, opacity: 0.92 }}>
            {props.summary}
          </div>
        ) : null}

        <div style={{ display: "flex", gap: 8, flexWrap: "wrap", marginTop: 12, alignItems: "center" }}>
          {chips.map((c) => (
            <Link
              key={c.k}
              href={c.href}
              style={{
                textDecoration: "none",
                color: "inherit",
                fontSize: 12,
                fontWeight: 850,
                padding: "8px 10px",
                borderRadius: 999,
                background: "rgba(255,255,255,0.06)",
                border: "1px solid rgba(255,255,255,0.12)",
              }}
              title={c.label}
            >
              {c.label}
            </Link>
          ))}
          <span style={{ opacity: 0.35, fontSize: 12 }}>•</span>
          <Link
            href={base}
            style={{
              textDecoration: "none",
              color: "inherit",
              fontSize: 12,
              fontWeight: 850,
              padding: "8px 10px",
              borderRadius: 999,
              background: "rgba(255,255,255,0.04)",
              border: "1px solid rgba(255,255,255,0.10)",
            }}
            title="Abrir a versão V1 deste caderno"
          >
            Abrir V1
          </Link>
        </div>
      </header>

      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(240px, 1fr))",
          gap: 12,
        }}
      >
        {big.map((c) => (
          <Link
            key={c.k}
            href={c.href}
            style={{ textDecoration: "none", color: "inherit" }}
            title={c.title}
          >
            <div
              style={{
                borderRadius: 16,
                padding: 14,
                border: "1px solid rgba(255,255,255,0.10)",
                background: "rgba(0,0,0,0.18)",
                minHeight: 128,
                display: "flex",
                flexDirection: "column",
                gap: 10,
              }}
            >
              <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 10 }}>
                <div style={{ fontSize: 12, opacity: 0.75, fontWeight: 900, letterSpacing: 0.6 }}>
                  {c.k.toUpperCase()}
                </div>
                <div style={{ width: 10, height: 10, borderRadius: 999, background: "var(--accent)" }} />
              </div>
              <div style={{ fontSize: 18, fontWeight: 950, letterSpacing: -0.2 }}>{c.title}</div>
              <div style={{ fontSize: 13, opacity: 0.9, lineHeight: 1.35 }}>{c.desc}</div>
            </div>
          </Link>
        ))}
      </div>
    </div>
  );
}