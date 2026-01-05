# CV — V2 — Hotfix D1 — remover any (ESLint no-explicit-any)

## Fix
- Removeu cast "as any" das páginas V2 (Home/Mapa/Debate/Provas).
- Substituiu por unknown + guards (asObj/asStr/asUiDefault).

## Arquivos
- src/app/c/[slug]/v2/page.tsx
- src/app/c/[slug]/v2/mapa/page.tsx
- src/app/c/[slug]/v2/debate/page.tsx
- src/app/c/[slug]/v2/provas/page.tsx

## Verify
- npm run lint
- npm run build
