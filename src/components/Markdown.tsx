import { mdToHtml } from "@/lib/markdown";

export default async function Markdown({ markdown }: { markdown: string }) {
  const html = await mdToHtml(markdown);
  return (
    <div className="prose prose-invert max-w-none prose-a:underline prose-a:decoration-[color:var(--accent)] prose-hr:border-white/10">
      <div dangerouslySetInnerHTML={{ __html: html }} />
    </div>
  );
}
