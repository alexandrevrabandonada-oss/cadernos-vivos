# CV — V2 Tijolo D4 v0_28b — ProvasV2 (hash focus)

## O que entrou
- Componente client ProvasV2 resiliente (props unknown, heurística para extrair itens).
- Foco por hash sem mutar window.location (scrollIntoView).
- Botão copiar link com hash (clipboard) + highlight de foco.
- Page server /c/[slug]/v2/provas com meta.title ?? slug e acervo ?? provas.

## Arquivos
- src/components/v2/ProvasV2.tsx
- src/app/c/[slug]/v2/provas/page.tsx

## Verify
- tools/cv-verify.ps1 (guard + lint + build)
