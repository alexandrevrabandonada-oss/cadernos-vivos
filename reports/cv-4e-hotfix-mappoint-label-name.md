# CV-4e — Hotfix MapPoint label/name — 2025-12-27 16:36

## Problema
- Build falhava: MutiraoRegistro usa p.label / p.name, mas MapPoint não declarava essas props.

## Correção
- MapPoint agora aceita label?: string e name?: string (compatível com diferentes JSONs de mapa).

## Verify
- npm run lint
- npm run build