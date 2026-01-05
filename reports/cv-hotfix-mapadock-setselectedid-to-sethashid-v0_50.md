# CV — Hotfix v0_50 — MapaDockV2 setSelectedId para setHashId

## Causa
- MapaDockV2 chamava setSelectedId, mas o state setter nao existe mais (migrou para hash store).

## Fix
- Substitui setSelectedId por setHashId (padrao hash focus).

## Arquivo
- src/components/v2/MapaDockV2.tsx

## Verify
- tools/cv-verify.ps1 (guard + lint + build)
