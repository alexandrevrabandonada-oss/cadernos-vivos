export type MarkdownOptions = {
  target?: "_blank" | "_self";
};

const DEFAULT_OPTS: Required<MarkdownOptions> = { target: "_blank" };

function escapeHtml(s: string): string {
  return String(s ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

function escapeAttr(s: string): string {
  return escapeHtml(s).replace(/"/g, "&quot;");
}

function sanitizeHref(raw: string): string {
  const u = String(raw ?? "").trim();
  if (!u) return "";
  if (u.startsWith("#") || u.startsWith("/")) return u;
  if (u.startsWith("mailto:")) return u;
  if (u.startsWith("https://") || u.startsWith("http://")) return u;
  return "";
}

function inline(md: string, opts: Required<MarkdownOptions>): string {
  let t = escapeHtml(md);

  // links [text](url)
  t = t.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_m, text, href) => {
    const safe = sanitizeHref(String(href));
    const label = String(text);
    if (!safe) return label;
    const targetAttr = opts.target === "_blank" ? ' target="_blank" rel="noreferrer noopener"' : "";
    return `<a href="${escapeAttr(safe)}"${targetAttr}>${label}</a>`;
  });

  // inline code
  t = t.replace(/`([^`]+)`/g, (_m, code) => `<code>${code}</code>`);

  // bold / italic (simple)
  t = t.replace(/\*\*([^*]+)\*\*/g, (_m, b) => `<strong>${b}</strong>`);
  t = t.replace(/\*([^*]+)\*/g, (_m, i) => `<em>${i}</em>`);

  return t;
}

export async function markdownToHtml(markdown: string, options?: MarkdownOptions): Promise<string> {
  const opts: Required<MarkdownOptions> = { ...DEFAULT_OPTS, ...(options || {}) };
  const src = String(markdown || "").replace(/\r\n/g, "\n");
  const lines = src.split("\n");

  const out: string[] = [];
  let inCode = false;
  let list: "ul" | "ol" | null = null;

  const closeList = () => {
    if (list) {
      out.push(`</${list}>`);
      list = null;
    }
  };

  for (const rawLine of lines) {
    const line = rawLine ?? "";

    // fenced code ```
    if (/^```/.test(line)) {
      if (!inCode) {
        closeList();
        inCode = true;
        out.push("<pre><code>");
      } else {
        inCode = false;
        out.push("</code></pre>");
      }
      continue;
    }

    if (inCode) {
      out.push(escapeHtml(line));
      continue;
    }

    const trimmed = line.trim();
    if (!trimmed) {
      closeList();
      continue;
    }

    const h = line.match(/^(#{1,6})\s+(.*)$/);
    if (h) {
      closeList();
      const level = h[1].length;
      out.push(`<h${level}>${inline(h[2], opts)}</h${level}>`);
      continue;
    }

    const ul = line.match(/^[-*]\s+(.*)$/);
    if (ul) {
      if (list !== "ul") {
        closeList();
        list = "ul";
        out.push("<ul>");
      }
      out.push(`<li>${inline(ul[1], opts)}</li>`);
      continue;
    }

    const ol = line.match(/^\d+\.\s+(.*)$/);
    if (ol) {
      if (list !== "ol") {
        closeList();
        list = "ol";
        out.push("<ol>");
      }
      out.push(`<li>${inline(ol[1], opts)}</li>`);
      continue;
    }

    closeList();
    out.push(`<p>${inline(line, opts)}</p>`);
  }

  if (inCode) out.push("</code></pre>");
  closeList();

  return out.join("\n");
}

// aliases para imports antigos
export async function mdToHtml(markdown: string, options?: MarkdownOptions): Promise<string> {
  return markdownToHtml(markdown, options);
}

export async function simpleMarkdownToHtml(markdown: string, options?: MarkdownOptions): Promise<string> {
  return markdownToHtml(markdown, options);
}
