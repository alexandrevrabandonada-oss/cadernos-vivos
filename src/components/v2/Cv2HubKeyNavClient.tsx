"use client";

import { useEffect } from "react";

type Props = {
  rootId: string;
};

function asArray<T extends Element>(list: NodeListOf<T>): T[] {
  const out: T[] = [];
  list.forEach((x) => out.push(x));
  return out;
}

export function Cv2HubKeyNavClient({ rootId }: Props) {
  useEffect(() => {
    const root = document.getElementById(rootId);
    if (!root) return;

    const selector = "a.cv2-cardInteractive, a.cv2-card";
    const items = asArray(root.querySelectorAll<HTMLAnchorElement>(selector));
    if (!items.length) return;

    let index = 0;

    const apply = () => {
      items.forEach((el, i) => {
        el.tabIndex = i === index ? 0 : -1;
        if (i === index) el.setAttribute("data-cv2-active", "1");
        else el.removeAttribute("data-cv2-active");
      });
    };

    const clamp = (n: number) => {
      if (n < 0) return 0;
      if (n >= items.length) return items.length - 1;
      return n;
    };

    const setIndex = (n: number, focus: boolean) => {
      index = clamp(n);
      apply();
      if (focus) {
        const el = items[index];
        if (el) el.focus();
      }
    };

    const onFocusIn = (ev: FocusEvent) => {
      const t = ev.target as Element | null;
      if (!t) return;
      const a = t.closest(selector) as HTMLAnchorElement | null;
      if (!a) return;
      const idx = items.indexOf(a);
      if (idx >= 0) {
        index = idx;
        apply();
      }
    };

    const onKeyDown = (ev: KeyboardEvent) => {
      const key = ev.key;
      const active = document.activeElement as Element | null;
      if (!active) return;
      if (!root.contains(active)) return;

      if (key === "ArrowRight" || key === "ArrowDown") {
        ev.preventDefault();
        setIndex(index + 1, true);
        return;
      }
      if (key === "ArrowLeft" || key === "ArrowUp") {
        ev.preventDefault();
        setIndex(index - 1, true);
        return;
      }
      if (key === "Home") {
        ev.preventDefault();
        setIndex(0, true);
        return;
      }
      if (key === "End") {
        ev.preventDefault();
        setIndex(items.length - 1, true);
        return;
      }
      if (key === "Enter" || key === " ") {
        const a = active.closest(selector) as HTMLAnchorElement | null;
        if (a) {
          ev.preventDefault();
          a.click();
        }
      }
    };

    // init: roving tabindex
    apply();

    root.addEventListener("focusin", onFocusIn);
    root.addEventListener("keydown", onKeyDown);

    return () => {
      root.removeEventListener("focusin", onFocusIn);
      root.removeEventListener("keydown", onKeyDown);
    };
  }, [rootId]);

  return null;
}