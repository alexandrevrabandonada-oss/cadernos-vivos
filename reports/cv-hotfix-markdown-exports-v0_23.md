# CV Hotfix — Markdown exports v0.23 — 2025-12-28 11:02

## O que foi feito
- Reescreveu src/lib/markdown.ts com parser simples e estável
- Exporta markdownToHtml() e também aliases mdToHtml() e simpleMarkdownToHtml()
- Evita strings quebradas com barras e aspas

## Motivo
- Build estava falhando por imports esperando mdToHtml/simpleMarkdownToHtml sem export correspondente