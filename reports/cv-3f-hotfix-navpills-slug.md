# CV-3f — Hotfix NavPills slug + CadernoHeader slug — 2025-12-27 13:19

## O que foi corrigido
- Paginas com <NavPills /> agora viram <NavPills slug={slug} /> (quando a variavel slug existe no arquivo)
- Remocao de slug={...} em <CadernoHeader ...> (CadernoHeader nao aceita slug)

## Arquivos patchados
- src\app\c\[slug]\page.tsx
- src\app\c\[slug]\a\[aula]\page.tsx
- src\app\c\[slug]\acervo\page.tsx
- src\app\c\[slug]\debate\page.tsx
- src\app\c\[slug]\pratica\page.tsx
- src\app\c\[slug]\quiz\page.tsx
- src\app\c\[slug]\trilha\page.tsx

## Verify
- npm run lint
- npm run build