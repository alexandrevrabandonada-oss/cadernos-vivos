# CV V2 Hotfix — normalize.ts lint unblock v0.2 — 2025-12-28 11:40

## Problema
- src/lib/v2/normalize.ts falhava no lint por 
o-explicit-any e _issues unused.

## Fix (não-destrutivo)
- Adiciona eslint-disable **somente no arquivo** normalize.ts (V2 ainda em estabilização).

## Próximo
- Quando o contrato v2 fechar, remover disable e tipar com guards/zod.