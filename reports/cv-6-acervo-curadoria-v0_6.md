# CV-6 — Curadoria do Acervo — 2025-12-27 17:12

## O que entrou
- src/lib/acervo.ts (loader tipado do acervo.json)
- src/components/AcervoClient.tsx (busca + tags + links)
- /c/[slug]/acervo agora usa params Promise (Next 16) e renderiza a UI nova

## Como usar
- Coloque arquivos em: public/cadernos/<slug>/acervo/
- Liste itens em: content/cadernos/<slug>/acervo.json (file/title/kind/tags)

## Observação
- Aqui é REGISTRO/ATA (Cadernos Vivos). Nada de Recibo ECO.