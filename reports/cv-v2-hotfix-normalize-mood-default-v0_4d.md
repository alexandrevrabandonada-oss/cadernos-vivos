# CV V2 Hotfix — normalize mood default v0.4d — 2025-12-28 13:18

## Problema
- MetaV2 exige mood string, mas normalize.ts gerava mood como string|undefined e atribuía direto.

## Fix
- No objeto meta, mood passou a ser (mood ?? "urban") para sempre sair string.

## Arquivo alterado
- src/lib/v2/normalize.ts

## Verify
- npm run lint
- npm run build