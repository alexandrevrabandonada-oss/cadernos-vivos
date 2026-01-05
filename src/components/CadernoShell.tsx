import type { ReactNode, CSSProperties } from "react";

import CadernoHeader from "@/components/CadernoHeader";
import NavPills from "@/components/NavPills";

type AccentVars = { ["--accent"]?: string };

export default function CadernoShell({
  title,
  subtitle,
  ethos,
  accent,
  style,
  children,
}: {
  title: string;
  subtitle?: string;
  ethos?: string;
  accent?: string;
  style?: CSSProperties;
  children: ReactNode;
}) {
  const finalStyle = {
    ...(style ?? {}),
    ...(accent ? ({ ["--accent"]: accent } as AccentVars) : {}),
  } as CSSProperties & AccentVars;

  return (
    <main className="space-y-5" style={finalStyle}>
      <a
        href="#conteudo"
        className="sr-only focus:not-sr-only card px-3 py-2 inline-block"
      >
        Pular para o conteúdo
      </a>

      <CadernoHeader title={title} subtitle={subtitle} ethos={ethos} />
      <NavPills />

      <div id="conteudo">{children}</div>
    </main>
  );
}