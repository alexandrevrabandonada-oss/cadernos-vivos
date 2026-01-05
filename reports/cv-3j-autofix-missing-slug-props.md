# CV-3j — Autofix missing slug props — 2025-12-27 13:54

## Estratégia
- Varre src/app/c/[slug]/ e injeta slug={slug} automaticamente em tags JSX que usam componentes que exigem slug.
- Alvos: NavPills, AulaProgress, DebateBoard, TerritoryMap

## Arquivos alterados
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\mapa\page.tsx

## Verify
- npm run lint
- npm run build