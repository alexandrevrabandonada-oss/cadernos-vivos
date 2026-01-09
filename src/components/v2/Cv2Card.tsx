import React from "react";

export type Cv2CardProps = {
  title?: React.ReactNode;
  subtitle?: React.ReactNode;
  icon?: React.ReactNode;
  actions?: React.ReactNode;
  children?: React.ReactNode;
  className?: string;
  style?: React.CSSProperties;
  "data-cv2-card"?: string;
};

export function Cv2Card(props: Cv2CardProps) {
  const cls = ["cv2-card", props.className].filter(Boolean).join(" ");
  return (
    <section className={cls} style={props.style} data-cv2-card={props["data-cv2-card"]}>
      {(props.title || props.subtitle || props.icon || props.actions) ? (
        <header className="cv2-card__hd">
          {props.icon ? <div className="cv2-card__icon">{props.icon}</div> : null}
          <div className="cv2-card__titles">
            {props.title ? <div className="cv2-card__title">{props.title}</div> : null}
            {props.subtitle ? <div className="cv2-card__sub">{props.subtitle}</div> : null}
          </div>
          {props.actions ? <div className="cv2-card__actions">{props.actions}</div> : null}
        </header>
      ) : null}
      {props.children ? <div className="cv2-card__bd">{props.children}</div> : null}
    </section>
  );
}

export function Cv2Stack(props: { children?: React.ReactNode; className?: string; style?: React.CSSProperties }) {
  const cls = ["cv2-stack", props.className].filter(Boolean).join(" ");
  return (
    <div className={cls} style={props.style}>
      {props.children}
    </div>
  );
}