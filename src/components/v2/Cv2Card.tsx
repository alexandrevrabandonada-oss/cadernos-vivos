import Link from "next/link";
import type { ReactNode } from "react";

type Props = {
  href: string;
  title: string;
  description?: string;
  right?: ReactNode;
  className?: string;
};

export function Cv2Card({ href, title, description, right, className }: Props) {
  const cls = ["cv2-card", "cv2-cardInteractive", className].filter(Boolean).join(" ");
  return (
    <Link className={cls} href={href}>
      <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", gap: "12px" }}>
        <div>
          <div className="cv2-cardTitle">{title}</div>
          {description ? <div className="cv2-cardDesc" style={{ marginTop: "6px" }}>{description}</div> : null}
        </div>
        {right ? <div aria-hidden="true">{right}</div> : null}
      </div>
    </Link>
  );
}