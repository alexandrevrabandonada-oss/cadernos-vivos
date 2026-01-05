# CV-Engine-1 — CadernoShell — 2025-12-27 17:46

## O que foi feito
- Criado src/components/CadernoShell.tsx (Header + Nav + SkipLink + container de conteudo).
- Refatoradas pages em src/app/c/[slug]/**/page.tsx para usar CadernoShell.
- Removidos CadernoHeader/NavPills duplicados das pages (e imports) para evitar lint de unused.

## Resultado esperado
- UI base consistente em todas as paginas do caderno.
- Menos risco de regressao ao evoluir interface/acessibilidade.

## Proximo tijolo sugerido
- CV-Engine-2: schemas (Zod) para caderno.json / mapa.json / debate.json / acervo.json + mensagens amigaveis.