# CV Hotfix — markdown.ts stable v0_22h — 2025-12-28 00:11

## O que foi feito
- Reescreveu src/lib/markdown.ts com renderer simples (sem dependencias).
- Links e regex com escapes seguros (sem over-escape).
- Exporta markdownToHtml e simpleMarkdownToHtml (alias p/ compat).

## Verify
- npm run lint
- npm run build