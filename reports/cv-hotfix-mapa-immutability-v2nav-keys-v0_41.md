# CV — Hotfix v0_41 — MapaCanvasV2 immutability + V2Nav keys

## Causa
- ESLint react-hooks/immutability bloqueia assignment em window.location.hash.
- V2Nav tinha indice i nao usado e warning de keys em runtime.

## Fix
- MapaCanvasV2: window.location.hash = id -> history.replaceState(null, "", "#" + id)
- V2Nav: remove i do map + key fica it.key + "-" + it.href

## Arquivos
- src/components/v2/MapaCanvasV2.tsx
- src/components/v2/V2Nav.tsx

## Verify
- tools/cv-verify.ps1 (guard + lint + build)
