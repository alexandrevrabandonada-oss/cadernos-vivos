# CV — V2 Tijolo D4 v0_30a — ProvasV2 (hash focus)

## O que entrou
- ProvasV2 client resiliente (props unknown, normaliza array/obj).
- Foco por hash sem mutar window.location (scrollIntoView + hashchange).
- Busca local (título, texto, tags, fonte).
- Copiar link com hash (#id) + feedback Copiado!.
- (Compat) V2Nav: active agora aceita string (pra active=provas não quebrar build).

## Arquivos
- src/components/v2/ProvasV2.tsx
- src/app/c/[slug]/v2/provas/page.tsx

## Verify
- tools/cv-verify.ps1 (guard + lint + build)
