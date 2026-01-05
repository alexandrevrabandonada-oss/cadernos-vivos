# CV V2 Hotfix — normalize no undefined v0.3b — 2025-12-28 11:46

## Problema
- build falhava: MetaV2 não aceita undefined (JsonValue).

## Fix
- Converte subtitle/mood/accent/ethos de asStr(x) para asStr(x) ?? null.

## Observação
- Hotfix não altera V1; é só camada V2.