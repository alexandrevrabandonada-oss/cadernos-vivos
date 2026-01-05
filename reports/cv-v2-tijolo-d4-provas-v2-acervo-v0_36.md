# CV — Tijolo D4 v0_36 — Provas/Acervo V2 + hotfix MapaDockV2

## O que entrou
- src/components/v2/ProvasV2.tsx: lista do acervo com filtros (q, tipo, tag) + cards + copiar link + abrir no mapa/debate.
- src/app/c/[slug]/v2/provas/page.tsx: server page usando loadCadernoV2 + meta.title.

## Hotfix de lint
- src/components/v2/MapaDockV2.tsx: troca setSelectedId(readHashId()) dentro do useEffect por setTimeout(() => setSelectedId(...), 0).

## Verify
- tools/cv-verify.ps1 (Guard → Lint → Build)
