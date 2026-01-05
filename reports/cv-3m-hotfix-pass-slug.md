# CV-3m — Hotfix: sempre passar slug — 2025-12-27 14:21

## O que foi feito
- Varreu src/app/c/[slug]/**/page.tsx e garantiu slug={slug} nos componentes:
  - NavPills
  - AulaProgress
  - DebateBoard
  - TerritoryMap

## Arquivos alterados
- (nenhum; já estava ok)

## Verify
- npm run lint
- npm run build