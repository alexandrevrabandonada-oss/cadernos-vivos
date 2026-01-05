# CV — Fix — TrilhasV2 JSX namespace (v0_115)

## O que foi corrigido
- Removido retorno JSX.Element (namespace JSX não disponível no build); TS infere o tipo.

## Arquivos alterados
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\components\v2\TrilhasV2.tsx

## Verify
- tools/cv-verify.ps1 (guard + lint + build)