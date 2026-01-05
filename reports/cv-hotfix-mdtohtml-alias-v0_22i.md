# CV Hotfix — mdToHtml alias v0_22i — 2025-12-28 00:28

## O que foi feito
- Adicionou export async function mdToHtml(...) em src/lib/markdown.ts como alias para markdownToHtml.
- Corrige build que falhava em src/components/Markdown.tsx (import mdToHtml).

## Verify
- npm run lint
- npm run build