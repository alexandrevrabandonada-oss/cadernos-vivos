# CV — Hotfix v0_44 — Mapa hash (immutability) + Dock props

## Fixes
- MapaCanvasV2: remove window.location.hash = ... (lint react-hooks/immutability).
- Substitui por history.replaceState(... + #id) e dispara hashchange manualmente.
- MapaV2: garante mapa={mapa} ao chamar MapaDockV2 quando o padrão antigo existir.

## Arquivos
- src/components/v2/MapaCanvasV2.tsx
- src/components/v2/MapaV2.tsx

## Verify
- tools/cv-verify.ps1 (guard + lint + build)
