# CV — Hotfix v0_43 — V2Nav active linhaTempo + remove unused i

## Fixes
- page /v2/linha-do-tempo: active='linhaTempo' (alinha com NavKey).
- V2Nav.tsx: remove param i nao usado no map (lint).

## Arquivos
- src/app/c/[slug]/v2/linha-do-tempo/page.tsx
- src/components/v2/V2Nav.tsx

## Verify
- tools/cv-verify.ps1 (guard + lint + build)
