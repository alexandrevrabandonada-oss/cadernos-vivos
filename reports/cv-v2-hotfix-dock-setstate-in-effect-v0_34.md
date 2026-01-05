# CV — Hotfix v0_34 — Dock sem setState síncrono em useEffect

## Causa
- ESLint (react-hooks/set-state-in-effect) bloqueia setState chamado diretamente no corpo de um useEffect.

## Fix
- MapaDockV2: selectedId inicial agora vem de initializer (guard em window).
- MapaDockV2: removeu setSelectedId(readHashId()) do corpo do effect; mantém hashchange + cv:nodeSelect.
- MapaDockV2: dock no desktop virou position:fixed (não depende do layout pai).
- v2/mapa/page.tsx: monta <MapaDockV2 .../> para garantir que o inspector aparece.
- (opcional) MapaV2.tsx: remove import MapaDockV2 se estava sobrando.

## Verify
- tools/cv-verify.ps1 (Guard → Lint → Build)
