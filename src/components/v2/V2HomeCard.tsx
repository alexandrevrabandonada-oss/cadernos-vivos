import Link from "next/link";

export function V2HomeCard(props: { href: string; title: string; desc: string; kicker?: string }) {
  const p = props;
  return (
    <Link
      href={p.href}
      style={{
        display: "block",
        border: "1px solid rgba(255,255,255,0.12)",
        borderRadius: 16,
        padding: 14,
        textDecoration: "none",
        color: "white",
        background: "linear-gradient(180deg, rgba(255,255,255,0.05), rgba(0,0,0,0.22))",
        boxShadow: "0 0 0 1px rgba(0,0,0,0.15) inset",
      }}
    >
      {p.kicker ? (
        <div style={{ opacity: 0.75, fontSize: 12, letterSpacing: 0.4, textTransform: "uppercase" }}>{p.kicker}</div>
      ) : null}
      <div style={{ marginTop: p.kicker ? 6 : 0, fontWeight: 900, fontSize: 18 }}>{p.title}</div>
      <div style={{ marginTop: 6, opacity: 0.85, lineHeight: 1.35 }}>{p.desc}</div>
      <div style={{ marginTop: 10, opacity: 0.9, textDecoration: "underline", fontWeight: 700 }}>Abrir</div>
    </Link>
  );
}