"use client";

import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";

type Props = {
  rootId: string;
  placeholder?: string;
  selector?: string;
  skipSelector?: string;
  pageSize?: number;
  enablePager?: boolean;
};

function norm(s: string): string {
  return (s || "").toLowerCase().replace(/\s+/g, " ").trim();
}

export default function Cv2DomFilterClient(props: Props) {
  const pageSize = Math.max(6, Math.min(200, props.pageSize ?? 24));
  const enablePager = props.enablePager ?? true;

  const [q, setQ] = useState("");
  const [limit, setLimit] = useState(pageSize);
  const [total, setTotal] = useState(0);
  const [shown, setShown] = useState(0);

  const qNorm = useMemo(() => norm(q), [q]);
  const limitEff = useMemo(() => (limit < pageSize ? pageSize : limit), [limit, pageSize]);

  const skipSelector = useMemo(() => (props.skipSelector && props.skipSelector.trim().length)
    ? props.skipSelector.trim()
    : '[data-cv2-filter-ui="1"],[data-cv2-provas-tools="1"]'
  , [props.skipSelector]);

  const selectors = useMemo(() => {
    const forced = (props.selector ?? "").trim();
    if (forced.length) return [forced];
    return [
      '[data-cv2-item="1"]',
      '[data-cv2-proof="1"]',
      '[data-cv2-prova="1"]',
      "article",
      ".cv2-card",
      "li"
    ];
  }, [props.selector]);

  const rafRef = useRef<number | null>(null);

  const apply = useCallback(() => {
    const root = document.getElementById(props.rootId);
    if (!root) return;

    let items: Element[] = [];
    for (const sel of selectors) {
      try {
        const got = Array.from(root.querySelectorAll(sel));
        for (const el of got) items.push(el);
      } catch {
        // selector inválido: ignora
      }
    }

    // remove duplicados preservando ordem
    const seen = new Set<Element>();
    items = items.filter((el) => {
      if (seen.has(el)) return false;
      seen.add(el);
      return true;
    });

    // remove UI do filtro / tools
    items = items.filter((el) => {
      try { return !(el instanceof HTMLElement) ? true : !el.matches(skipSelector); } catch { return true }
    });

    const totalNow = items.length;
    setTotal(totalNow);

    const pagerActive = enablePager && qNorm.length === 0;
    let shownNow = 0;

    for (let i = 0; i < items.length; i++) {
      const el = items[i] as HTMLElement;
      const txt = norm(el.textContent || "");
      const pass = (qNorm.length === 0) ? true : (txt.includes(qNorm));

      let visible = pass;
      if (pagerActive && visible) {
        visible = (shownNow < limitEff);
      }

      if (visible) {
        el.style.removeProperty("display");
        shownNow++;
      } else {
        el.style.display = "none";
      }
    }

    setShown(shownNow);
  }, [props.rootId, selectors, skipSelector, qNorm, limitEff, enablePager]);

  const scheduleApply = useCallback(() => {
    if (rafRef.current) cancelAnimationFrame(rafRef.current);
    rafRef.current = requestAnimationFrame(() => {
      rafRef.current = null;
      apply();
    });
  }, [apply]);

  useEffect(() => {
    scheduleApply();
    const root = document.getElementById(props.rootId) as HTMLElement | null;
    if (!root) return;
    const obs = new MutationObserver(() => scheduleApply());
    obs.observe(root, { childList: true, subtree: true });
    return () => obs.disconnect();
  }, [props.rootId, scheduleApply]);

  const canLoadMore = enablePager && qNorm.length === 0 && total > limitEff && shown >= limitEff;

  return (
    <div data-cv2-filter-ui="1" style={{ display: "grid", gap: 8, padding: "10px 0" }}>
      <input
        data-cv2-filter-ui="1"
        value={q}
        onChange={(e) => {
          const v = e.target.value;
          setQ(v);
          // reset do pager via evento (lint-friendly)
          if (enablePager) setLimit(pageSize);
        }}
        placeholder={props.placeholder ?? "Filtrar..."}
        style={{
          width: "100%",
          padding: "10px 12px",
          borderRadius: 12,
          border: "1px solid rgba(255,255,255,0.14)",
          background: "rgba(0,0,0,0.22)"
        }}
      />

      <div data-cv2-filter-ui="1" style={{ display: "flex", justifyContent: "space-between", gap: 10, alignItems: "center" }}>
        <div data-cv2-filter-ui="1" style={{ fontSize: 12, opacity: 0.75 }}>
          {qNorm.length ? `${shown} visíveis (filtrado)` : `${Math.min(shown, total)} / ${total}`}
        </div>

        {canLoadMore ? (
          <button
            data-cv2-filter-ui="1"
            type="button"
            onClick={() => setLimit((v) => v + pageSize)}
            style={{
              padding: "8px 10px",
              borderRadius: 12,
              border: "1px solid rgba(255,255,255,0.14)",
              background: "rgba(255,255,255,0.06)"
            }}
          >
            Carregar mais
          </button>
        ) : null}
      </div>
    </div>
  );
}
