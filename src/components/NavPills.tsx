"use client";

import React from "react";
import Link from "next/link";
import { useParams, usePathname } from "next/navigation";

type Props = { slug?: string };

function asSlug(v: unknown): string {
  if (!v) return "";
  if (Array.isArray(v)) return v.length ? String(v[0]) : "";
  return String(v);
}

export default function NavPills({ slug }: Props) {
  const params = useParams() as Record<string, unknown>;
  const pathname = usePathname();
  const s = (slug && String(slug)) ? String(slug) : asSlug(params["slug"]);

  const items = React.useMemo(() => {
    if (!s) return [];
    return [
      { key: "home", label: "Caderno", href: "/c/" + s },
      { key: "aulas", label: "Aulas", href: "/c/" + s + "/a/1" },
      { key: "trilha", label: "Trilha", href: "/c/" + s + "/trilha" },
      { key: "pratica", label: "Prática", href: "/c/" + s + "/pratica" },
      { key: "quiz", label: "Quiz", href: "/c/" + s + "/quiz" },
      { key: "acervo", label: "Acervo", href: "/c/" + s + "/acervo" },
      { key: "debate", label: "Debate", href: "/c/" + s + "/debate" },
      { key: "mapa", label: "Mapa", href: "/c/" + s + "/mapa" },
      { key: "registro", label: "Registro", href: "/c/" + s + "/registro" },
      { key: "status", label: "Status", href: "/c/" + s + "/status" },
    ];
  }, [s]);

  if (!items.length) return null;

  return (
    <nav aria-label="Seções do caderno" className="my-3">
      <div className="flex flex-wrap gap-2">
        {items.map((it) => {
          const active = !!pathname && (pathname === it.href || pathname.startsWith(it.href + "/"));
          const cls = active
            ? "px-3 py-1 rounded-full border text-sm font-semibold"
            : "px-3 py-1 rounded-full border text-sm";
          return (
            <Link
              key={it.key}
              href={it.href}
              aria-current={active ? "page" : undefined}
              className={cls}
            >
              {it.label}
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
