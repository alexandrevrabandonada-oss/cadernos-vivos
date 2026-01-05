# CV-4g — Hotfix TerritoryMap sem any — 2025-12-27 17:00

## Problema
- ESLint: @typescript-eslint/no-explicit-any em src/components/TerritoryMap.tsx

## Correcao
- Removeu anotacoes ': any' em parametros e vars para deixar TS inferir
- Se sobrou algum caso fora do padrao, adicionou eslint-disable-next-line somente na linha especifica

## Verify
- npm run lint
- npm run build