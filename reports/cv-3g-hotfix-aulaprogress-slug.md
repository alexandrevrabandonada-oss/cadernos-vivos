# CV-3g — Hotfix AulaProgress slug — 2025-12-27 13:21

## Problema
TypeScript: AulaProgress exige slug e havia chamada sem passar slug.

## Correcao
Dentro de src/app/c/[slug] foi adicionado slug={slug} nas tags <AulaProgress ...> que nao tinham slug.

## Arquivos patchados
(nenhum arquivo precisou de patch)

## Verify
- npm run lint
- npm run build