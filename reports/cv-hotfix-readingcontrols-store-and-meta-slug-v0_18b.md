# CV Hotfix v0.18b — ReadingControls store + meta.slug fallback — 2025-12-27 22:15

## Fixes
- ReadingControls: prefs via useSyncExternalStore (SSR/hydration estável; lint sem setState-in-effect).
- cadernos.ts: meta.slug é preenchido com o slug da rota se não existir no meta.json (antes do Zod parse).

## Motivo
- Corrige o erro do eslint react-hooks/set-state-in-effect.
- Remove ZodError de meta.slug undefined em cadernos novos.