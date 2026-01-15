import Link from "next/link";

type Action = { label: string; href: string };

export default function Cv2EmptyState(props: {
  title?: string;
  subtitle?: string;
  hint?: string;
  actions?: Action[];
}) {
  const title = props.title ?? "V2 em construção";
  const subtitle = props.subtitle ?? "Ainda não há conteúdo renderizado aqui.";
  const hint = props.hint ?? "Dica: use as portas abaixo para explorar o universo.";
  const actions = props.actions ?? [];

  return (
    <section className="cv2-empty" data-cv2="empty-state">
      <div className="cv2-empty__title">{title}</div>
      <div className="cv2-empty__subtitle">{subtitle}</div>
      <div className="cv2-empty__hint">{hint}</div>
      {actions.length > 0 ? (
        <div className="cv2-empty__actions">
          {actions.map((a) => (
            <Link key={a.href} href={a.href} className="cv2-door">
              {a.label}
            </Link>
          ))}
        </div>
      ) : null}
    </section>
  );
}
