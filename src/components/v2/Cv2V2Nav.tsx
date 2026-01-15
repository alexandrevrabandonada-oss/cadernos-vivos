import Link from "next/link";

export type Cv2DoorId = "hub" | "mapa" | "linha" | "linha-do-tempo" | "provas" | "trilhas" | "debate";

export default function Cv2V2Nav(props: { slug: string; active: Cv2DoorId }) {
  const s = encodeURIComponent(props.slug);
  const base = "/c/" + s + "/v2";
  const items: { id: Cv2DoorId; label: string; href: string }[] = [
    { id: "hub", label: "Hub", href: base },
    { id: "mapa", label: "Mapa", href: base + "/mapa" },
    { id: "linha", label: "Linha", href: base + "/linha" },
    { id: "linha-do-tempo", label: "Linha do tempo", href: base + "/linha-do-tempo" },
    { id: "provas", label: "Provas", href: base + "/provas" },
    { id: "trilhas", label: "Trilhas", href: base + "/trilhas" },
    { id: "debate", label: "Debate", href: base + "/debate" },
  ];

  return (
    <nav className="cv2-doors" aria-label="Portas do universo" data-cv2="doors-nav">
      {items.map((it) => {
        const on = it.id === props.active;
        return (
          <Link
            key={it.id}
            href={it.href}
            className={on ? "cv2-door cv2-door--active" : "cv2-door"}
            aria-current={on ? "page" : undefined}
          >
            {it.label}
          </Link>
        );
      })}
    </nav>
  );
}
