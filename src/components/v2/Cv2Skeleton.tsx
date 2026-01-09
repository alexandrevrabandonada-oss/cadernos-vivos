import React from "react";

export type SkelMode = "hub" | "list";

export function SkelCard(props: { lines?: number; className?: string }) {
  const lines = Math.max(1, Math.min(6, props.lines ?? 3));
  return (
    <div className={"cv2-skelCard " + (props.className ?? "")}>
      <div className="cv2-skelLine" style={{ width: "42%" }} />
      <div style={{ height: 10 }} />
      {Array.from({ length: lines }).map((_, i) => (
        <div key={i} style={{ marginTop: i === 0 ? 0 : 8 }}>
          <div className="cv2-skelLine" style={{ width: i === lines - 1 ? "58%" : "92%" }} />
        </div>
      ))}
    </div>
  );
}

export function SkelScreen(props: { title?: string; count?: number; mode?: SkelMode }) {
  const count = Math.max(1, Math.min(12, props.count ?? (props.mode === "hub" ? 6 : 8)));
  return (
    <div style={{ display: "grid", gap: 12, padding: 12 }}>
      {Array.from({ length: count }).map((_, i) => (
        <SkelCard key={i} lines={props.mode === "hub" ? 2 : 4} />
      ))}
    </div>
  );
}

export { SkelScreen as Cv2SkelScreen, SkelCard as Cv2SkelCard };
