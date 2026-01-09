import Link from "next/link";
import type { CoreNodesV2 } from "@/lib/v2/types";

type Props = { slug: string; title?: string; coreNodes?: CoreNodesV2 };
type Resolved = { id: string; title: string; hint?: string; href: string };

const DOOR_KEYS = new Set(["mapa","linha","linha-do-tempo","provas","trilhas","debate","hub"]);

function isRecord(v: unknown): v is Record<string, unknown> {
  return !!v && typeof v === "object";
}

function resolveHref(slug: string, id: string): string {
  const s = encodeURIComponent(slug);
  if (id === "hub") return "/c/" + s + "/v2";
  if (DOOR_KEYS.has(id)) return "/c/" + s + "/v2/" + encodeURIComponent(id);
  return "/c/" + s + "/v2/mapa?focus=" + encodeURIComponent(id);
}

function resolveCoreNodes(slug: string, coreNodes?: CoreNodesV2): Resolved[] {
  if (!coreNodes || !coreNodes.length) return [];
  const out: Resolved[] = [];
  for (const v of coreNodes) {
    if (typeof v === "string") {
      const id = v.trim();
      if (!id) continue;
      out.push({ id, title: id, href: resolveHref(slug, id) });
      continue;
    }
    if (isRecord(v)) {
      const id = typeof v["id"] === "string" ? (v["id"] as string).trim() : "";
      if (!id) continue;
      const title = (typeof v["title"] === "string" && (v["title"] as string).trim()) ? (v["title"] as string).trim() : id;
      const hint = (typeof v["hint"] === "string" && (v["hint"] as string).trim()) ? (v["hint"] as string).trim() : undefined;
      out.push({ id, title, hint, href: resolveHref(slug, id) });
    }
  }
  const seen = new Set<string>();
  const dedup: Resolved[] = [];
  for (const n of out) {
    if (seen.has(n.id)) continue;
    seen.add(n.id);
    dedup.push(n);
    if (dedup.length >= 9) break;
  }
  return dedup;
}

export default function Cv2CoreNodes(props: Props) {
  const nodes = resolveCoreNodes(props.slug, props.coreNodes);
  if (!nodes.length) return null;
  return (
    <section className="cv2-core" aria-label="Núcleo do caderno">
      <div className="cv2-core__head">
        <div className="cv2-core__kicker">Núcleo</div>
        <div className="cv2-core__title">{props.title ? props.title : "5–9 nós centrais"}</div>
        <div className="cv2-core__sub">Portas e nós-chave — comece pelo mapa e atravesse o universo.</div>
      </div>
      <div className="cv2-core__pills">
        {nodes.map((n) => (
          <Link key={n.id} className="cv2-pill" href={n.href} title={n.hint ? n.hint : n.id}>
            {n.title}
          </Link>
        ))}
      </div>
    </section>
  );
}
