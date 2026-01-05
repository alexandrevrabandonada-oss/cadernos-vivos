# CV — Tijolo D4 v0_30 — Acervo/Provas V2

## O que entrou
- Componente novo: AcervoV2 (lista + busca + filtro por tipo).
- Provas page passa a renderizar o AcervoV2 lendo de c.acervo (unknown-safe).

## Arquivos
- src/components/v2/AcervoV2.tsx
- src/app/c/[slug]/v2/provas/page.tsx

## Verify
- tools/cv-verify.ps1 (Guard → Lint → Build)
