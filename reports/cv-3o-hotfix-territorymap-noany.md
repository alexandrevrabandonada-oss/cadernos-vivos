# CV-3o — Hotfix ESLint (no-explicit-any) — 2025-12-27 14:36

## Problema
- ESLint: @typescript-eslint/no-explicit-any em TerritoryMap.tsx

## Correção
- Troca do cast s any por s MapPoint['kind'] | '' no select de categoria

## Verify
- npm run lint
- npm run build