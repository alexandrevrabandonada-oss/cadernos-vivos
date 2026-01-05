# CV-3e — Hotfix: remover prop slug do CadernoHeader — 2025-12-27 13:06

## Motivo
- O componente CadernoHeader (default) não aceita slug nas props; apenas 	itle/subtitle/ethos.

## Arquivos alterados
- src\app\c\[slug]\a\[aula]\page.tsx
- src\app\c\[slug]\acervo\page.tsx
- src\app\c\[slug]\debate\page.tsx
- src\app\c\[slug]\mapa\page.tsx
- src\app\c\[slug]\pratica\page.tsx
- src\app\c\[slug]\quiz\page.tsx
- src\app\c\[slug]\trilha\page.tsx
- src\app\c\[slug]\page.tsx

## Verify
- npm run lint
- npm run build