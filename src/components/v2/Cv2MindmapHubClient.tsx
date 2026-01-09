"use client";

import * as React from "react";

type NodeId = "mapa" | "linha" | "provas" | "trilhas" | "debate";
type NodeDef = {
  id: NodeId;
  label: string;
  desc: string;
  href: string;
  x: number;
  y: number;
};

export default function Cv2MindmapHubClient(props: { slug: string; title?: string }) {
  const slug = props.slug;
  const title = props.title ?? props.slug;

  const nodes: NodeDef[] = React.useMemo(() => ([
    { id: "mapa",   label: "Mapa",   desc: "Explorar por lugares e conexões", href: "/c/" + slug + "/v2/mapa",              x: 50, y: 44 },
    { id: "linha",  label: "Linha",  desc: "Narrativa em fluxo (o que levou ao quê)", href: "/c/" + slug + "/v2/linha",      x: 22, y: 52 },
    { id: "provas", label: "Provas", desc: "Fontes, documentos e checagens", href: "/c/" + slug + "/v2/provas",             x: 78, y: 52 },
    { id: "trilhas",label: "Trilhas",desc: "Caminhos de leitura (do básico ao avançado)", href: "/c/" + slug + "/v2/trilhas", x: 30, y: 74 },
    { id: "debate", label: "Debate", desc: "Perguntas e conversa em camadas", href: "/c/" + slug + "/v2/debate",             x: 70, y: 74 }
  ] as NodeDef[]), [slug]);

  const [active, setActive] = React.useState<number>(0);
  const refs = React.useRef<Array<HTMLAnchorElement | null>>([]);

    const focus = React.useCallback((i: number) => {
    const idx = (i + nodes.length) % nodes.length;
    setActive(idx);
    requestAnimationFrame(() => {
      const el = refs.current[idx];
      if (el) el.focus();
    });
  }, [nodes.length]);

  const onKeyDown = (e: React.KeyboardEvent) => {
    const k = e.key;
    if (k === "ArrowRight") { e.preventDefault(); focus(active + 1); }
    else if (k === "ArrowLeft") { e.preventDefault(); focus(active - 1); }
    else if (k === "ArrowUp") { e.preventDefault(); focus(0); }
    else if (k === "ArrowDown") { e.preventDefault(); focus(3); }
    else if (k === "Enter" || k === " ") {
      e.preventDefault();
      const el = refs.current[active];
      if (el) el.click();
    }
  };

  const cx = (base: string, isActive: boolean) => (isActive ? (base + " cv2-card--active") : base);

  const cx0 = 50;
  const cy0 = 22;

  return (
    <section className="cv2-mindmap" aria-label="Mapa mental do caderno">
      <div
        className="cv2-mindmapFrame"
        tabIndex={0}
        role="application"
        aria-roledescription="Mapa mental navegável"
        onKeyDown={onKeyDown}
      >
        <svg className="cv2-mindmapSvg" viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true">
          {nodes.map((n) => (
            <line key={n.id} x1={cx0} y1={cy0} x2={n.x} y2={n.y} className="cv2-mindmapLine" />
          ))}
          <circle cx={cx0} cy={cy0} r="1.6" className="cv2-mindmapDot" />
        </svg>

        <div className="cv2-mindmapCenter">
          <div className="cv2-card cv2-mindmapCenterCard">
            <div className="cv2-cardTitle">{title}</div>
            <div className="cv2-cardDesc">Escolha uma porta para entrar no universo</div>
            <div className="cv2-mindmapHint">Dica: setas navegam • Enter abre</div>
          </div>
        </div>

        {nodes.map((n, i) => (
          <div key={n.id} className="cv2-mindmapNode" style={{ left: n.x + "%", top: n.y + "%" }}>
            <a
              href={n.href}
              className={cx("cv2-card", i === active)}
              ref={(el) => { refs.current[i] = el; }}
              onFocus={() => setActive(i)}
              aria-label={n.label + ": " + n.desc}
            >
              <div className="cv2-cardTitle">{n.label}</div>
              <div className="cv2-cardDesc">{n.desc}</div>
            </a>
          </div>
        ))}
      </div>
    </section>
  );
}