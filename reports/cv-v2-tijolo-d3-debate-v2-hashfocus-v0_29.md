# CV — V2 Tijolo D3 v0_29 — DebateV2 (hash focus)

## O que entrou
- DebateV2 client resiliente (props unknown, extrai items/threads/list).
- Foco por hash sem mutar window.location (scrollIntoView).
- Busca local (título, texto, tags).
- Links cruzados: Mapa, Linha, Provas + copiar link com hash.
- Page server /c/[slug]/v2/debate com meta.title ?? slug e debate/discussao fallback.

## Arquivos
- src/components/v2/DebateV2.tsx
- src/app/c/[slug]/v2/debate/page.tsx

## Verify
- tools/cv-verify.ps1 (guard + lint + build)
