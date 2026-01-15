import Link from "next/link";
import Cv2V2Nav, { type Cv2DoorId } from "@/components/v2/Cv2V2Nav";
import Cv2DoorGuide from "@/components/v2/Cv2DoorGuide";
import Cv2PortalsCurated from "@/components/v2/Cv2PortalsCurated";
import type { CoreNodesV2 } from "@/lib/v2/types";

export type ShellV2Props = {
  slug: string;
  active: Cv2DoorId;
  title?: string;
  subtitle?: string;
  current?: string;
  coreNodes?: CoreNodesV2;
  showPortals?: boolean;
  children: React.ReactNode;
};

export function ShellV2(props: ShellV2Props) {
  const slug = props.slug;
  const s = encodeURIComponent(slug);
  const active = props.active;

  return (
    <div className="min-h-screen w-full bg-neutral-950 text-neutral-50" data-cv2="shell-v2">
      <header className="sticky top-0 z-40 border-b border-neutral-800 bg-neutral-950/85 backdrop-blur">
        <div className="mx-auto max-w-5xl px-4 py-3">
          <div className="flex items-center justify-between gap-3">
            <div className="flex items-center gap-3">
              <Link href={"/c/" + s + "/v2"} className="text-sm font-semibold tracking-wide hover:opacity-90">
                ⟵ Voltar ao Hub
              </Link>
              <span className="text-xs text-neutral-400">/</span>
              <span className="text-xs text-neutral-300">Concreto Zen · V2</span>
            </div>
            <div className="text-xs text-neutral-400">#{active}</div>
          </div>

          <div className="mt-3">
            <Cv2V2Nav slug={slug} active={active} />
            <Cv2DoorGuide slug={slug} active={active} />
          </div>

          {(props.title || props.subtitle) ? (
            <div className="mt-4">
              {props.title ? <h1 className="text-xl font-extrabold tracking-tight">{props.title}</h1> : null}
              {props.subtitle ? <p className="mt-1 text-sm text-neutral-300">{props.subtitle}</p> : null}
            </div>
          ) : null}
        </div>
      </header>

      <main className="mx-auto max-w-5xl px-4 py-8">
        {props.children}
        {(props.showPortals === false) ? null : (
          <div className="mt-10">
            <Cv2PortalsCurated slug={slug} active={active} current={props.current} coreNodes={props.coreNodes} />
          </div>
        )}
      </main>

      <footer className="border-t border-neutral-800 bg-neutral-950">
        <div className="mx-auto max-w-5xl px-4 py-6 text-xs text-neutral-500">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <span>V2 · Concreto Zen · orientação constante</span>
            <span>Escutar • Cuidar • Organizar</span>
          </div>
        </div>
      </footer>
    </div>
  );
}

export default ShellV2;
