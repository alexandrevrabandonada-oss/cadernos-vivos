"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import React from "react";

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

function extractSlug(pathname: string): string | null {
  const parts = pathname.split("/").filter(Boolean);
  const i = parts.indexOf("c");
  if (i < 0) return null;
  if (i + 1 >= parts.length) return null;
  const slug = parts[i + 1] || "";
  return slug.trim().length ? slug : null;
}

function currentDoor(pathname: string): DoorKey {
  const p = pathname || "";
  if (p.includes("/v2/mapa")) return "mapa";
  if (p.includes("/v2/linha-do-tempo")) return "linha-do-tempo";
  if (p.includes("/v2/linha")) return "linha";
  if (p.includes("/v2/provas")) return "provas";
  if (p.includes("/v2/trilhas/") || p.endsWith("/v2/trilhas")) return "trilhas";
  if (p.includes("/v2/debate")) return "debate";
  return "hub";
}

export default function V2QuickNav() {
  const pathname = usePathname() || "";
  const slug = extractSlug(pathname);
  if (!slug) return null;

  const base = "/c/" + slug + "/v2";
  const active = currentDoor(pathname);

  return (
    <nav aria-label="Portas rápidas" data-cv2="quicknav">
      <div
        style={{
          display: "flex",
          gap: 8,
          alignItems: "center",
          overflowX: "auto",
          padding: "10px 12px",
          WebkitOverflowScrolling: "touch",
        }}
      >
        {DOORS.map((d, idx) => {
          const href = base + d.path;
          const isActive = active === d.key;
          return (
            <React.Fragment key={d.key}>
              <Link
                href={href}
                data-active={isActive ? "1" : "0"}
                aria-current={isActive ? "page" : undefined}
                style={{
                  display: "inline-flex",
                  alignItems: "center",
                  borderRadius: 999,
                  padding: "6px 10px",
                  border: "1px solid rgba(255,255,255,0.16)",
                  background: isActive ? "rgba(255,255,255,0.10)" : "rgba(0,0,0,0.10)",
                  whiteSpace: "nowrap",
                  fontSize: 13,
                  lineHeight: "18px",
                  textDecoration: "none",
                  color: "inherit",
                }}
              >
                {d.label}
              </Link>
              {idx < DOORS.length - 1 ? (
                <span aria-hidden="true" style={{ opacity: 0.35, padding: "0 2px" }}>
                  ›
                </span>
              ) : null}
            </React.Fragment>
          );
        })}
      </div>
    </nav>
  );
}