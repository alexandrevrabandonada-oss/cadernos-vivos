'use client';

import * as React from "react";
import { usePathname } from "next/navigation";

type NavPin = {
  id: string;
  label: string;
  x: number; // percent
  y: number; // percent
  href: string;
  hint?: string;
};

function slugFromPath(pathname: string): string | undefined {
  const m = pathname.match(/^\/c\/([^\/]+)\/v2\/mapa(?:\/)?/);
  if (!m) return undefined;
  try {
    return decodeURIComponent(m[1]);
  } catch {
    return m[1];
  }
}

function buildPins(slug: string): NavPin[] {
  const base = "/c/" + encodeURIComponent(slug) + "/v2";
  return [
    { id: "hub", label: "Hub", x: 50, y: 28, href: base, hint: "Visao geral" },
    { id: "debate", label: "Debate", x: 18, y: 44, href: base + "/debate" },
    { id: "linha", label: "Linha", x: 50, y: 56, href: base + "/linha" },
    { id: "linha-do-tempo", label: "Linha do tempo", x: 82, y: 44, href: base + "/linha-do-tempo" },
    { id: "provas", label: "Provas", x: 26, y: 74, href: base + "/provas" },
    { id: "trilhas", label: "Trilhas", x: 74, y: 74, href: base + "/trilhas" }
  ];
}

export function Cv2MapNavPinsClient(): React.JSX.Element | null {
  const pathname = usePathname();
  const slug = pathname ? slugFromPath(pathname) : undefined;
  const pins = React.useMemo(() => (slug ? buildPins(slug) : []), [slug]);

  if (!slug || pins.length === 0) return null;

  return (
    <div className="cv2-map-navpins" aria-label="Navegacao do mapa">
      {pins.map((p) => (
        <a
          key={p.id}
          className="cv2-map-navpin"
          href={p.href}
          style={{ left: p.x + "%", top: p.y + "%" }}
          aria-label={p.label}
          title={p.hint ?? p.label}
        >
          <span className="cv2-map-navpin__dot" aria-hidden="true" />
          <span className="cv2-map-navpin__label">{p.label}</span>
        </a>
      ))}
    </div>
  );
}
