import type { ReactNode } from "react";

export default function V2Layout({ children }: { children: ReactNode }) {
  return <div className="cv-v2">{children}</div>;
}