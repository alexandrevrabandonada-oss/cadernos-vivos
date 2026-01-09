import Link from "next/link";

type Props = {
  slug: string;
  active?: string;
  current?: string;
  title?: string;
};

type DoorKey =
  | "hub"
  | "mapa"
  | "linha"
  | "linha-do-tempo"
  | "provas"
  | "trilhas"
  | "debate";

type Door = { key: DoorKey; label: string; path: string };

const DOORS: Door[] = [
  { key: "hub", label: "Hub", path: "" },
  { key: "mapa", label: "Mapa", path: "/mapa" },
  { key: "linha", label: "Linha", path: "/linha" },
  { key: "linha-do-tempo", label: "Linha do tempo", path: "/linha-do-tempo" },
  { key: "provas", label: "Provas", path: "/provas" },
  { key: "trilhas", label: "Trilhas", path: "/trilhas" },
  { key: "debate", label: "Debate", path: "/debate" },
];

function normKey(v: string | undefined): DoorKey {
  const x = (v || "").trim();
  if (x === "mapa") return "mapa";
  if (x === "linha") return "linha";
  if (x === "linha-do-tempo" || x === "linha_do_tempo" || x === "timeline") return "linha-do-tempo";
  if (x === "provas") return "provas";
  if (x === "trilhas") return "trilhas";
  if (x === "debate") return "debate";
  return "hub";
}

export default function V2Nav(props: Props) {
  const active = normKey(props.active || props.current);
  const base = "/c/" + props.slug + "/v2";

  const cta =
    active === "mapa"
      ? { label: "Voltar ao Hub", href: base, kind: "hub" as const }
      : { label: "Comece pelo Mapa →", href: base + "/mapa", kind: "mapa" as const };

  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        gap: 12,
        justifyContent: "space-between",
        flexWrap: "wrap",
      }}
    >
      <nav aria-label="Navegação V2">
        <div style={{ display: "flex", gap: 10, alignItems: "center", flexWrap: "wrap" }}>
          {DOORS.map((d) => {
            const href = base + d.path;
            const isActive = active === d.key;
            const isMapa = d.key === "mapa";
            return (
              <Link
                key={d.key}
                href={href}
                aria-current={isActive ? "page" : undefined}
                style={{
                  display: "inline-flex",
                  alignItems: "center",
                  gap: 8,
                  borderRadius: 999,
                  padding: "8px 12px",
                  border: "1px solid rgba(255,255,255,0.16)",
                  background: isActive ? "rgba(255,255,255,0.12)" : "rgba(0,0,0,0.10)",
                  whiteSpace: "nowrap",
                  fontSize: 14,
                  lineHeight: "18px",
                  textDecoration: "none",
                  color: "inherit",
                }}
              >
                <span style={{ fontWeight: isActive ? 800 : 650 }}>{d.label}</span>
                {isMapa && active !== "mapa" ? (
                  <span
                    style={{
                      fontSize: 12,
                      padding: "2px 8px",
                      borderRadius: 999,
                      border: "1px solid rgba(255,255,255,0.22)",
                      background: "rgba(255,255,255,0.08)",
                      opacity: 0.9,
                    }}
                  >
                    comece aqui
                  </span>
                ) : null}
              </Link>
            );
          })}
        </div>
      </nav>

      <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
        <Link
          href={cta.href}
          style={{
            display: "inline-flex",
            alignItems: "center",
            borderRadius: 999,
            padding: "8px 12px",
            border: "1px solid rgba(255,255,255,0.22)",
            background: cta.kind === "mapa" ? "rgba(255,255,255,0.10)" : "rgba(0,0,0,0.12)",
            textDecoration: "none",
            color: "inherit",
            fontSize: 13,
            fontWeight: 750,
            whiteSpace: "nowrap",
          }}
        >
          {cta.label}
        </Link>
      </div>
    </div>
  );
}