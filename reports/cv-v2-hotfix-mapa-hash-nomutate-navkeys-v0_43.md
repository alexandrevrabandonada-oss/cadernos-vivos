# CV — V2 Hotfix v0_43 — Mapa hash sem mutacao + V2Nav keys

## Fix
- MapaCanvasV2: remove window.location.hash = id; troca por history.replaceState + dispatch hashchange (lint react-hooks/immutability).
- V2Nav: remove i nao usado e padroniza keys (key=href) para eliminar warning no console.

## Arquivos
- src/components/v2/MapaCanvasV2.tsx
- src/components/v2/V2Nav.tsx

## Verify
- tools/cv-verify.ps1 (guard + lint + build)
