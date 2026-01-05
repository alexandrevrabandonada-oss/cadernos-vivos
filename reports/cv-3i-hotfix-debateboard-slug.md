# CV-3i — Hotfix DebateBoard slug — 2025-12-27 13:49

## Problema
- Build falhando: DebateBoard exige prop slug e a página /c/[slug]/debate não passava.

## Correção
- Patch em src/app/c/[slug]/debate/page.tsx: <DebateBoard slug={slug} prompts={prompts} />",
  ",
  
- npm run lint
- npm run build