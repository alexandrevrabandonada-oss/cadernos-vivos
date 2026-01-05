# CV — Hotfix Pack v0_36

## O que entrou
- Next 16.1: em pages/layout async dentro de src/app/c/[slug], troca acessos diretos a params/searchParams por await.
- V2Nav: remove callback param i não usado e reforça key para reduzir warning em dev.
- MapaCanvasV2: troca window.location.hash = id por history.replaceState + evento hashchange (evita lint).
- MapaDockV2: mapa opcional; MapaV2 tenta passar mapa para o dock se estiver faltando.

## Arquivos alterados
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\components\v2\MapaDockV2.tsx

## Arquivos inspecionados e pulados (não-async ou sem padrão)
- 19 arquivo(s)

## Verify
- tools/cv-verify.ps1 (guard + lint + build)
