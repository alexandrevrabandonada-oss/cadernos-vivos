import type { CSSProperties } from "react";
import Link from "next/link";

export type AccentStyle = CSSProperties & { ["--accent"]?: string };

export function CadernoHeader({
  title,
  subtitle,
  ethos,
}: {
  title: string;
  subtitle?: string;
  ethos?: string;
}) {
  return (
    <header className="card p-5" style={{ ["--accent"]: "#facc15" } as AccentStyle}>
      <div className="flex flex-col gap-2">
        <div className="flex items-center justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold">{title}</h1>
            {subtitle ? <div className="muted mt-1">{subtitle}</div> : null}
          </div>
          <Link href="/" className="text-sm muted hover:text-white transition">
            Hub
          </Link>
        </div>
        {ethos ? <div className="text-sm muted mt-2">{ethos}</div> : null}
      </div>
    </header>
  );
}

export default CadernoHeader;