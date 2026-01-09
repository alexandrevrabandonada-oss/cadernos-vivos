import Link from "next/link";

export default function NotFound() {
  return (
    <div style={{ padding: 12 }}>
      <h1 style={{ margin: 0, fontSize: 18 }}>Não achei isso aqui.</h1>
      <p style={{ marginTop: 8, opacity: 0.8 }}>Esse conteúdo/rota não existe (ainda).</p>
      <p style={{ marginTop: 12 }}>
        <Link href="/" style={{ textDecoration: "underline" }}>Voltar pro início</Link>
      </p>
    </div>
  );
}
