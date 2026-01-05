# CV-3h — Hotfix AulaProgress slug — 2025-12-27 13:41

## Problema
TypeScript build: AulaProgress exige prop slug e havia chamada sem slug.

## Correcao
Dentro de src/app/c/[slug], adiciona slug={slug} em <AulaProgress ...> quando nao existir slug=.

## Arquivos patchados
- src\app\c\[slug]\a\[aula]\page.tsx

## Verify
- npm run lint
- npm run build