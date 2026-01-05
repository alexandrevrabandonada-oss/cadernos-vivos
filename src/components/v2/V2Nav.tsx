import Link from "next/link";
import type { CSSProperties } from "react";

type NavItem = { key: string; label: string; href: (slug: string) => string };

const items: NavItem[] = [
  { key: "home", label: "Hub", href: (slug) => "/c/" + slug + "/v2" },
  { key: "mapa", label: "Mapa", href: (slug) => "/c/" + slug + "/v2/mapa" },
  { key: "linha", label: "Linha", href: (slug) => "/c/" + slug + "/v2/linha" },
  { key: "debate", label: "Debate", href: (slug) => "/c/" + slug + "/v2/debate" },
  { key: "provas", label: "Provas", href: (slug) => "/c/" + slug + "/v2/provas" },
  { key: "trilhas", label: "Trilhas", href: (slug) => "/c/" + slug + "/v2/trilhas" },
];

export default function V2Nav(props: { slug: string; active?: string }) {
  const { slug, active } = props;

  const wrap: CSSProperties = {
    display: "flex",
    gap: 10,
    flexWrap: "wrap",
    marginTop: 12,
    alignItems: "center",
  };

  const base: CSSProperties = {
    display: "inline-flex",
    alignItems: "center",
    padding: "8px 10px",
    borderRadius: 999,
    border: "1px solid rgba(255,255,255,0.14)",
    textDecoration: "none",
    color: "inherit",
    fontSize: 12,
    background: "rgba(0,0,0,0.18)",
  };

  const on: CSSProperties = {
    ...base,
    background: "rgba(255,255,255,0.08)",
  };

  return (
    <nav aria-label="Navegação V2" style={wrap}>
      {items.map((it) => {
        const isOn = (active ? active === it.key : it.key === "home");
        return (
          <Link key={it.key} href={it.href(slug)} style={isOn ? on : base}>
            {it.label}
          </Link>
        );
      })}
    </nav>
  );
}