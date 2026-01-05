# CV V2 Hotfix — MetaV2 robust v0.4c — 2025-12-28 12:50

## Problema
- MetaV2 tinha campos opcionais (string|undefined) e index signature JsonValue (sem undefined).
- normalize.ts usa null para evitar undefined em JsonValue.

## Fix
- MetaV2 agora aceita null para subtitle/accent/ethos e mood fica obrigatório.
- Patch robusto: funciona com interface ou type.