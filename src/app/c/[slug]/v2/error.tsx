"use client";
import React from "react";

export default function Error({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return (
    <div style={{ padding: 12 }}>
      <h1 style={{ margin: 0, fontSize: 18 }}>Ops…</h1>
      <p style={{ marginTop: 8, opacity: 0.8 }}>Deu ruim ao carregar esta página do caderno.</p>
      <button
        onClick={() => reset()}
        style={{ marginTop: 12, padding: "10px 12px", borderRadius: 10 }}
      >
        Tentar de novo
      </button>
      <pre style={{ marginTop: 12, whiteSpace: "pre-wrap", opacity: 0.65, fontSize: 12 }}>
        {String(error?.message || error)}
      </pre>
    </div>
  );
}
