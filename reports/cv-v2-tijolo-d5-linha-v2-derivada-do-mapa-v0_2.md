# CV — Tijolo D5 v0_2 — Linha do tempo V2 derivada do mapa

## O que mudou
- src/components/v2/TimelineV2.tsx: timeline derivada de mapa(nodes), com ordenação, busca, filtros (tipo/tag), âncoras e botão copiar link.
- src/app/c/[slug]/v2/linha/page.tsx: página V2 Linha passando slug/title/mapa.
- (se existir) src/app/c/[slug]/v2/linha-do-tempo/page.tsx: vira alias para ../linha/page.

## Verify
- (opcional) tools/cv-guard-v2.ps1
- npm run lint
- npm run build

## Status
- OK