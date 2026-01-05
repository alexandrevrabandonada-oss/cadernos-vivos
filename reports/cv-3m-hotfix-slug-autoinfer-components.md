# CV-3m — Hotfix slug opcional e autoinfer — 2025-12-27 15:15

## Problema
- Build quebrava quando algum componente client exigia slug e a pagina esquecia de passar.

## Estrategia nova
- slug vira opcional em componentes client e e inferido via pathname (/c/<slug>/...).

## Alteracoes
- DebateBoard: slug?: string + infer + localStorage seguro
- TerritoryMap: slug?: string + infer + remove any (eslint)
- AulaProgress: slug?: string + infer + localStorage seguro

## Verify
- npm run lint
- npm run build
