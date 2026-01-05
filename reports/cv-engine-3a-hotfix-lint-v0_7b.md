# CV-Engine-3A — Hotfix Lint v0.7b — 2025-12-27 19:58

## Correcoes
- ReadingControls.tsx: aspas em texto trocadas por &quot;...&quot; (react/no-unescaped-entities).
- Todas pages em /c/[slug] agora garantem import + uso de <ReadingControls /> apos <CadernoHeader />.

## Verify
- npm run lint
- npm run build