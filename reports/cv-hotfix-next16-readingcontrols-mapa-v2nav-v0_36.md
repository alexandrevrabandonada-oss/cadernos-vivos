# CV — Hotfix v0_36 — Next 16.1 + ReadingControls + MapaV2 + V2Nav

## Next 16.1 (dev): params/searchParams Promise
- Em pages async na V2: props.params.x / params.x -> (await ...).x

## ReadingControls
- Removeu hydration gate com setState em effect (lint proíbe).
- Hydrated agora vem de useSyncExternalStore (SSR=false, client=true).
- Ajustou deps de useMemo para incluir hydrated.

## MapaV2
- Passou mapa={mapa} para MapaDockV2 quando necessário (corrige build).

## V2Nav
- key mais único para evitar warning de keys duplicadas no console.

## Verify
- tools/cv-verify.ps1 (guard + lint + build)
