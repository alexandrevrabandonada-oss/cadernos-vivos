# Hotfix — markdown.ts rewrite v0.22d — 2025-12-27 23:53

## O que foi feito
- Reescreveu src/lib/markdown.ts inteiro com renderer minimalista.
- Inclui suporte: headings, paragrafos, listas, blockquote, code fences, inline code, bold/italic e links.
- Exporta aliases: renderMarkdown, markdownToHtml, mdToHtml e default.