# CV — Hotfix v0_34 — MapaDockV2 props

## Fix
- Em src/components/v2/MapaV2.tsx: <MapaDockV2 slug={slug} /> -> <MapaDockV2 slug={slug} mapa={mapa} />

## Verify
- tools/cv-verify.ps1 (guard + lint + build)
