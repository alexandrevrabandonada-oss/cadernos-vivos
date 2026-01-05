import "./globals.css";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Cadernos Vivos • VR Abandonada",
  description: "Hub de cadernos interativos: estudo, debate e prática no território.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt-BR">
      <body className="zen-backdrop">
      <a href="#cv-main" className="sr-only focus:not-sr-only fixed top-3 left-3 z-50 rounded-xl bg-black px-4 py-2 text-white focus:outline-none focus:ring-2 focus:ring-white/50">Pular para o conteúdo</a>
        <div className="max-w-4xl mx-auto px-4 py-8">{children}</div>
      </body>
    </html>
  );
}
