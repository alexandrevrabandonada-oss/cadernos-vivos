type SkelCardProps = {
  className?: string;
  lines?: number;
};

export function Cv2SkelCard({ className, lines = 3 }: SkelCardProps) {
  const cls = ["cv2-card", "cv2-skel", "cv2-skelPad", className].filter(Boolean).join(" ");
  const items = Array.from({ length: lines }).map((_, i) => i);
  return (
    <div className={cls} aria-hidden="true">
      <div className="cv2-skelStack">
        <div className="cv2-skelLine lg" style={{ width: "70%" }} />
        {items.map((i) => (
          <div key={i} className={"cv2-skelLine" + (i === items.length - 1 ? " sm" : "")} style={{ width: i === items.length - 1 ? "55%" : "88%" }} />
        ))}
      </div>
    </div>
  );
}

type ScreenProps = {
  title?: string;
  count?: number;
  mode?: "hub" | "list";
};

export function Cv2SkelScreen({ title = "Carregando…", count = 5, mode = "list" }: ScreenProps) {
  const items = Array.from({ length: count }).map((_, i) => i);
  const wrapCls = mode === "hub" ? "cv2-hubMap" : "";
  const wrapAttr = mode === "hub" ? { "data-cv2-hub": "map" as const } : {};
  return (
    <div className={wrapCls} {...wrapAttr} role="status" aria-live="polite" aria-busy="true">
      <div className="cv2-muted" style={{ marginBottom: "12px" }}>{title}</div>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(240px, 1fr))", gap: "14px" }}>
        {items.map((i) => (
          <Cv2SkelCard key={i} />
        ))}
      </div>
    </div>
  );
}