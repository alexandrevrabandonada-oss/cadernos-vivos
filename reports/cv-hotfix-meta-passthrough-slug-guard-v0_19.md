# CV Hotfix — meta passthrough + slug guard v0.19 — 2025-12-27 22:28

## Mudanças
- cadernos.ts: CadernoMeta.passthrough().parse() para não perder campos extras do meta (mood/theme/universe etc).
- /c/[slug]/page.tsx: se estava usando params.slug sem await params, corrigido para evitar slug undefined.

## Próximo
- Engine: scaffold de novo caderno (criar pasta + meta + arquivos mínimos por slug).