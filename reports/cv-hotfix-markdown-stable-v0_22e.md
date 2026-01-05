# CV Hotfix - Markdown stable v0.22e - 2025-12-27 23:59

## O que fez
- Reescreveu src/lib/markdown.ts para um renderer minimalista e estavel (sem escapes problematicos).
- Mantem export renderMarkdown + aliases (markdownToHtml/mdToHtml/default).

## Verify
- npm run lint
- npm run build (a menos que -SkipBuild)