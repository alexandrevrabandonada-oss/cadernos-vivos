# CV — Fix — MapaV2 sem Math.random (v0_73)

## O que foi corrigido
- Removeu Math.random do render (eslint react-hooks/purity).
- Fallback de posicao agora e deterministico via idx (grid simples).

## Arquivos alterados
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\components\v2\MapaV2.tsx

## Verify
- tools/cv-verify.ps1 (guard + lint + build)