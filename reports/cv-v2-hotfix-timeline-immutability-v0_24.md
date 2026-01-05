# CV — Hotfix v0_24 — TimelineV2 sem window.location.hash

## Causa raiz
- ESLint (react-hooks/immutability) bloqueia mutação de window.location.hash dentro de componente/hook.

## Fix
- Removeu a mutação do hash.
- Mantém UX: scrollIntoView no item do hash (o link já é copiado com #t-id).

## Arquivo
- src/components/v2/TimelineV2.tsx

## Verify
- tools/cv-verify.ps1 (guard + lint + build)
