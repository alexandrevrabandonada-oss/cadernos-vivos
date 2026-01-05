# CV — Hotfix v0_42 — Next 16.1 async params/searchParams + MapaV2 props

## Causa
- Next 16.1+ em rotas dinamicas entrega params/searchParams como Promise; acesso direto em Server Components async quebra em dev.
- MapaV2 chamava MapaDockV2 sem o prop mapa (build TypeScript falhava).

## Fix
- Em pages/layouts async de src/app/c/[slug]: props.params.x e params.x agora usam await.
- MapaV2: MapaDockV2 recebe mapa={mapa}.

## Arquivos alterados (auto)
- (nenhum page/layout precisou mudar)

## Arquivos pulados (nao-async)
- (nenhum)

## Verify
- tools/cv-verify.ps1 (guard + lint + build)
