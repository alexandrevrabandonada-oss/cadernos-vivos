# CV — Tijolo B (Data layer V2) — 2025-12-28 11:32

## O que foi criado (sem tocar UI)
- src/lib/v2/types.ts
- src/lib/v2/normalize.ts
- src/lib/v2/load.ts (server-only)
- src/lib/v2/index.ts

## Garantias
- Não mexe em rotas / componentes existentes.
- Leitura tolerante: meta/registro podem faltar (defaults + issues).
- Normalize superset: preserva chaves extras em meta/mapa/acervo.

## Próximo
- Tijolo C: criar /c/[slug]/v2 placeholder + Shell Concreto Zen, consumindo getCadernoV2(slug).