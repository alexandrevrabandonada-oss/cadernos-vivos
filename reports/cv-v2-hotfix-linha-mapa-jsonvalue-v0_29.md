# CV — Hotfix v0_29 — Linha V2: mapa unknown -> JsonValue

## Causa raiz
- loadCadernoV2 devolve c.mapa tipado como unknown; TimelineV2 exige JsonValue.

## Fix
- Adiciona: import type { JsonValue } from "@/lib/v2";
- Tipagem: const mapa = c.mapa as unknown as JsonValue;

## Arquivos
- src/app/c/[slug]/v2/linha/page.tsx
- src/app/c/[slug]/v2/linha-do-tempo/page.tsx

## Verify
- tools/cv-verify.ps1 (Guard → Lint → Build)
