# CV — Hotfix v0_45 — V2Nav active key (linhaTempo)

## Fix
- /v2/linha-do-tempo: V2Nav active foi ajustado para 'linhaTempo' (compatível com o tipo NavKey).
- V2Nav: remove parametro i nao usado na lista (warning).

## Arquivos
- src/app/c/[slug]/v2/linha-do-tempo/page.tsx
- src/components/v2/V2Nav.tsx

## Verify
- tools/cv-verify.ps1 (guard + lint + build)
