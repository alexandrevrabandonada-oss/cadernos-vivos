"use client";

import { useEffect, useMemo, useState, useSyncExternalStore } from "react";

type DomainRow = { domain: string; total: number; shown: number };
type Snapshot = { total: number; shown: number; domains: DomainRow[] };

type Listener = () => void;
type Unsub = () => void;

function createStore(initial: Snapshot) {
  let snap: Snapshot = initial;
  const listeners = new Set<Listener>();
  return {
    getSnapshot: () => snap,
    subscribe: (l: Listener): Unsub => {
      listeners.add(l);
      return () => { listeners.delete(l); };
    },
    publish: (next: Snapshot) => {
      snap = next;
      for (const l of listeners) l();
    },
  };
}

const store = createStore({ total: 0, shown: 0, domains: [] });

function foldText(input: unknown): string {
  const raw = input == null ? "" : String(input);
  const lower = raw.toLowerCase();
  try {
    return lower.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
  } catch {
    return lower;
  }
}

function safeHost(href: string): string {
  try {
    const base = typeof window !== "undefined" ? window.location.href : "http://localhost";
    const u = new URL(href, base);
    return u.hostname || "";
  } catch {
    return "";
  }
}

function depthOf(el: Element): number {
  let d = 0;
  let cur: Element | null = el;
  while (cur) { d += 1; cur = cur.parentElement; }
  return d;
}

function uniqOuterMost(list: Element[]): Element[] {
  const byDepth = list.slice().sort((a, b) => depthOf(a) - depthOf(b));
  const out: Element[] = [];
  for (const el of byDepth) {
    if (out.some((p) => p.contains(el))) continue;
    out.push(el);
  }
  return out;
}

function pickItems(root: HTMLElement, skipSelector: string, forcedSelector?: string): Element[] {
  const candidates = forcedSelector
    ? [forcedSelector]
    : [
        '[data-cv2-item="1"]',
        '[data-cv2-proof="1"]',
        '[data-cv2-prova="1"]',
        "article",
        "li",
        ".cv2-card",
      ];

  for (const sel of candidates) {
    const raw = Array.from(root.querySelectorAll(sel));
    const filtered = raw
      .filter((el) => !el.closest(skipSelector))
      .filter((el) => !!el.querySelector("a[href]"));
    if (filtered.length > 0) return uniqOuterMost(filtered);
  }
  return [];
}

async function copyText(text: string): Promise<boolean> {
  try {
    if (navigator.clipboard && typeof navigator.clipboard.writeText === "function") {
      await navigator.clipboard.writeText(text);
      return true;
    }
  } catch {
    // ignore
  }
  try {
    const ta = document.createElement("textarea");
    ta.value = text;
    ta.setAttribute("readonly", "true");
    ta.style.position = "fixed";
    ta.style.left = "-9999px";
    ta.style.top = "0";
    document.body.appendChild(ta);
    ta.select();
    const ok = document.execCommand("copy");
    document.body.removeChild(ta);
    return ok;
  } catch {
    return false;
  }
}

export type Cv2DomFilterClientProps = {
  rootId: string;
  itemSelector?: string;
  skipSelector?: string;
  placeholder?: string;
  copyLabel?: string;
  chipsLabel?: string;
};

export default function Cv2DomFilterClient(props: Cv2DomFilterClientProps) {
  const [q, setQ] = useState<string>("");
  const [domain, setDomain] = useState<string>("");
  const [toast, setToast] = useState<string>("");

  const snap = useSyncExternalStore(store.subscribe, store.getSnapshot, store.getSnapshot);
  const qFold = useMemo(() => foldText(q).trim(), [q]);
  const activeDomain = useMemo(() => domain.trim(), [domain]);

  const skipSelector = useMemo(() => props.skipSelector || '[data-cv2-filter-ui="1"]', [props.skipSelector]);

  useEffect(() => {
    const root = document.getElementById(props.rootId) as HTMLElement | null;
    if (!root) { store.publish({ total: 0, shown: 0, domains: [] }); return; }

    const items = pickItems(root, skipSelector, props.itemSelector);
    const domainTotals = new Map<string, { total: number; shown: number }>();
    let shown = 0;

    for (const el of items) {
      const text = foldText(el.textContent || "");
      const okText = qFold.length === 0 ? true : text.includes(qFold);

      const a = el.querySelector("a[href]") as HTMLAnchorElement | null;
      const href = a ? (a.href || a.getAttribute("href") || "") : "";
      const host = href ? safeHost(href) : "";

      if (!domainTotals.has(host)) domainTotals.set(host, { total: 0, shown: 0 });
      domainTotals.get(host)!.total += 1;

      const okDomain = activeDomain.length === 0 ? true : host === activeDomain;
      const ok = okText && okDomain;

      if (ok) { el.removeAttribute("hidden"); shown += 1; domainTotals.get(host)!.shown += 1; }
      if (!ok) { el.setAttribute("hidden", ""); }
    }

    const domains: DomainRow[] = Array.from(domainTotals.entries())
      .map(([d, c]) => ({ domain: d, total: c.total, shown: c.shown }))
      .filter((r) => r.domain && r.total > 0)
      .sort((a, b) => (b.total - a.total) || a.domain.localeCompare(b.domain));

    store.publish({ total: items.length, shown, domains });
  }, [props.rootId, props.itemSelector, props.skipSelector, qFold, activeDomain, skipSelector]);

  function collectVisibleLinks(): Array<{ href: string; text: string }> {
    const root = document.getElementById(props.rootId) as HTMLElement | null;
    if (!root) return [];
    const items = pickItems(root, skipSelector, props.itemSelector);
    const out: Array<{ href: string; text: string }> = [];
    const seen = new Set<string>();
    for (const el of items) {
      if (el.hasAttribute("hidden")) continue;
      const a = el.querySelector("a[href]") as HTMLAnchorElement | null;
      if (!a) continue;
      const href = a.href || a.getAttribute("href") || "";
      if (!href || href.startsWith("#")) continue;
      if (seen.has(href)) continue;
      seen.add(href);
      const text = (a.textContent || el.textContent || "").replace(/\s+/g, " ").trim().slice(0, 200);
      out.push({ href, text });
    }
    return out;
  }

  async function onCopy(kind: "plain" | "md") {
    const links = collectVisibleLinks();
    const text = kind === "plain"
      ? links.map((l) => l.href).join("\n")
      : links.map((l) => "- [" + (l.text || l.href) + "](" + l.href + ")").join("\n");
    if (!text) return;
    const ok = await copyText(text);
    setToast(ok ? "Copiado!" : "Falhou ao copiar");
    window.setTimeout(() => setToast(""), 1200);
  }

  return (
    <div className="cv2-filter" data-cv2-filter-ui="1">
      <div className="cv2-filter__row">
        <label className="cv2-filter__label" htmlFor={props.rootId + "__q"}>Filtrar</label>
        <input
          id={props.rootId + "__q"}
          className="cv2-filter__input"
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder={props.placeholder || "busca rápida..."}
        />
        <button type="button" className="cv2-filter__btn" onClick={() => setQ("")} disabled={q.length === 0}>Limpar</button>
        <button type="button" className="cv2-filter__btn" onClick={() => void onCopy("plain")}>{props.copyLabel || "Copiar links"}</button>
        <button type="button" className="cv2-filter__btn" onClick={() => void onCopy("md")}>Copiar MD</button>
        <div className="cv2-filter__stats" aria-live="polite">{snap.shown}/{snap.total}</div>
      </div>

      {snap.domains.length > 0 ? (
        <div className="cv2-filter__chips" role="list" aria-label={props.chipsLabel || "Domínios"}>
          <button type="button" className={"cv2-chip" + (domain === "" ? " is-active" : "")} onClick={() => setDomain("")}>
            <span className="cv2-chip__text">Tudo</span>
            <span className="cv2-chip__count">{snap.shown}</span>
          </button>
          {snap.domains.slice(0, 14).map((d) => (
            <button
              key={d.domain}
              type="button"
              className={"cv2-chip" + (domain === d.domain ? " is-active" : "")}
              onClick={() => setDomain(d.domain)}
              title={d.shown + "/" + d.total}
            >
              <span className="cv2-chip__text">{d.domain}</span>
              <span className="cv2-chip__count">{d.shown}</span>
            </button>
          ))}
          {toast ? <span className="cv2-filter__toast">{toast}</span> : null}
        </div>
      ) : null}
    </div>
  );
}


export { Cv2DomFilterClient };