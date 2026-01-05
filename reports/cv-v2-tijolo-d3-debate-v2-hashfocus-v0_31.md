# CV — V2 Tijolo D3 v0_31 — DebateV2 (hash focus)

## O que entrou
- DebateV2 client resiliente (props unknown, normaliza array/obj).
- Foco por hash sem mutar window.location (scrollIntoView + hashchange).
- Busca local (autor/texto/tags).
- Copiar link com hash (#id) + feedback Copiado!.
- Links cruzados no header (V2 Home/Mapa/Linha/Provas/Trilhas).

## Arquivos
- src/components/v2/DebateV2.tsx
- src/app/c/[slug]/v2/debate/page.tsx

## Verify
- tools/cv-verify.ps1 (guard + lint + build)
