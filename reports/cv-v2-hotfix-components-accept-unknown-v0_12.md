# CV — Hotfix v0_12 — V2 components accept unknown

## Causa raiz
- Pages V2 estavam passando valores tipados como unknown (loader/normalize superset).
- Componentes V2 exigiam JsonValue e o build travava (unknown nao atribuivel).

## Fix
- DebateV2/ProvasV2/TimelineV2 agora recebem unknown e validam internamente com guards.

## Arquivos
- src/components/v2/DebateV2.tsx
- src/components/v2/ProvasV2.tsx
- src/components/v2/TimelineV2.tsx

## Verify
- npm run lint
- npm run build
