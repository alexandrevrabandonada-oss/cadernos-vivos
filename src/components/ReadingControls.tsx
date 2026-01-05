"use client";

import React, { useEffect, useMemo, useRef, useSyncExternalStore, useState } from "react";

type Prefs = { reading: boolean; scale: number };
const KEY = "cv:prefs";

const clamp = (n: number, a: number, b: number) => Math.max(a, Math.min(b, n));

function parsePrefs(raw: string): Prefs {
  const base: Prefs = { reading: false, scale: 1 };
  if (!raw || typeof raw !== "string") return base;
  try {
    const obj = JSON.parse(raw) as unknown;
    if (typeof obj !== "object" || obj === null) return base;
    const r = obj as { reading?: unknown; scale?: unknown };
    const reading = typeof r.reading === "boolean" ? r.reading : base.reading;
    const scale = typeof r.scale === "number" ? clamp(r.scale, 0.8, 1.6) : base.scale;
    return { reading, scale };
  } catch {
    return base;
  }
}

function getPrefsRaw(): string {
  if (typeof window === "undefined") return "";
  try {
    return window.localStorage.getItem(KEY) ?? "";
  } catch {
    return "";
  }
}

function setPrefs(p: Prefs) {
  if (typeof window === "undefined") return;
  try {
    window.localStorage.setItem(KEY, JSON.stringify(p));
  } catch {
    // noop
  }
  try {
    window.dispatchEvent(new Event("cv:prefs"));
  } catch {
    // noop
  }
}

function subscribePrefs(cb: () => void) {
  if (typeof window === "undefined") return () => {};
  const asAny = cb as unknown as EventListener;
  window.addEventListener("storage", asAny);
  window.addEventListener("cv:prefs", asAny);
  return () => {
    window.removeEventListener("storage", asAny);
    window.removeEventListener("cv:prefs", asAny);
  };
}

function getHydratedSnapshot(): boolean {
  if (typeof window === "undefined") return false;
  const w = window as unknown as { __cvHydrated?: boolean };
  return w.__cvHydrated === true;
}

function subscribeHydrated(cb: () => void) {
  if (typeof window === "undefined") return () => {};
  const w = window as unknown as { __cvHydrated?: boolean };
  if (w.__cvHydrated === true) return () => {};
  const t = setTimeout(() => {
    (window as unknown as { __cvHydrated?: boolean }).__cvHydrated = true;
    cb();
  }, 0);
  return () => clearTimeout(t);
}

export default function ReadingControls() {
  // SSR e primeiro render do client: false. Depois vira true via store externo (sem setState em effect).
  const hydrated = useSyncExternalStore(subscribeHydrated, getHydratedSnapshot, () => false);

  const raw = useSyncExternalStore(subscribePrefs, getPrefsRaw, () => "");
  const prefs = useMemo(() => parsePrefs(raw), [raw]);

  useEffect(() => {
    if (!hydrated) return;
    try {
      document.documentElement.style.setProperty("--cv-scale", String(prefs.scale));
    } catch {
      // noop
    }
  }, [hydrated, prefs.scale]);

  const canSpeak = hydrated && typeof window !== "undefined" && typeof (window as unknown as { speechSynthesis?: unknown }).speechSynthesis !== "undefined";
  const utterRef = useRef<SpeechSynthesisUtterance | null>(null);
  const [speaking, setSpeaking] = useState(false);

  function getSpeakText(): string {
    if (typeof document === "undefined") return "";
    const root = (document.querySelector("[data-cv-content]") as HTMLElement | null) ?? (document.querySelector("main") as HTMLElement | null) ?? document.body;
    const t = root?.innerText ?? root?.textContent ?? "";
    return String(t).replace(/\\s+/g, " ").trim();
  }

  function onSpeak() {
    if (!canSpeak) return;
    try {
      const ss = window.speechSynthesis;
      if (!ss) return;
      ss.cancel();
      const txt = getSpeakText();
      if (!txt) return;
      const u = new SpeechSynthesisUtterance(txt);
      utterRef.current = u;
      u.onend = () => setSpeaking(false);
      u.onerror = () => setSpeaking(false);
      setSpeaking(true);
      ss.speak(u);
    } catch {
      setSpeaking(false);
    }
  }

  function onStop() {
    if (!canSpeak) return;
    try {
      window.speechSynthesis.cancel();
    } catch {
      // noop
    }
    setSpeaking(false);
  }

  function bumpScale(delta: number) {
    const next = clamp((prefs.scale ?? 1) + delta, 0.8, 1.6);
    setPrefs({ reading: prefs.reading, scale: next });
  }

  const btnClass = "card px-3 py-2 hover:bg-white/10 transition";
  const label = hydrated ? (canSpeak ? "Ouvir" : "Ouvir (indisponivel)") : "Ouvir";
  const disabledSpeak = hydrated ? (!canSpeak) : true;

  return (
    <section className="card p-4 flex flex-wrap gap-2 items-center" aria-label="Controles de leitura">
      <button type="button" className={btnClass} onClick={onSpeak} disabled={disabledSpeak} aria-label="Ouvir a pagina">
        {label}
      </button>
      <button type="button" className={btnClass} onClick={onStop} disabled={!hydrated || !canSpeak || !speaking} aria-label="Parar leitura">
        Parar
      </button>

      <div className="flex items-center gap-2 ml-auto">
        <button type="button" className={btnClass} onClick={() => bumpScale(-0.1)} aria-label="Diminuir texto">A-</button>
        <button type="button" className={btnClass} onClick={() => bumpScale(0.1)} aria-label="Aumentar texto">A+</button>
        <span className="opacity-70 text-sm">{Math.round((prefs.scale ?? 1) * 100)}%</span>
      </div>
    </section>
  );
}