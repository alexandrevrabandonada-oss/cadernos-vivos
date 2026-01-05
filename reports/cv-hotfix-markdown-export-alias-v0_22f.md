# CV Hotfix - Markdown export alias v0.22f - 2025-12-28 00:01

## O que fez
- Reescreveu src/lib/markdown.ts mantendo renderer estável.
- Exporta simpleMarkdownToHtml (alias) + markdownToHtml/mdToHtml/default.
- Corrigiu warning de variavel 'allowed' (agora é usada no retorno do link).

## Verify
- npm run lint
- npm run build (a menos que -SkipBuild)