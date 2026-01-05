import React from "react";
import { getAulaMarkdown } from "@/lib/aulas";
import { simpleMarkdownToHtml } from "@/lib/markdown";

export default async function Page({
  params,
}: {
  params: Promise<{ slug: string; aula: string }>;
}) {
  const { slug, aula } = await params;
  const md = await getAulaMarkdown(slug, aula);
  const html = simpleMarkdownToHtml(md);

  return (
    <main className="cv-page">
      <section className="card p-6">
        <article className="cv-md" dangerouslySetInnerHTML={{ __html: html }} />
      </section>
    </main>
  );
}