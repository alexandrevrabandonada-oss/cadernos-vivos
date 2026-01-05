# CV — Hotfix v0_15 — href regex no MapaV2 corrigido

## Causa raiz
- Em TSX, href={/c//v2} é interpretado como regex/divisão, gerando tipo 
umber e quebrando Link href (Url).

## Fix
- Troca para href={"/c/" + slug + "/v2"} e variantes (debate/provas/trilhas).

## Verify
- npm run lint
- npm run build
