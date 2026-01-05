# CV — Fix — MapaV2 idx + uiDefault redirect (v0_79)

## O que foi corrigido
- MapaV2: nodes.map agora recebe (n, idx) para compat com layout deterministico.
- /c/[slug]: se encontrar uiDefault, faz redirect para /v2 quando uiDefault === "v2".

## Arquivos alterados
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\components\v2\MapaV2.tsx

## Verify
- tools/cv-verify.ps1 (guard + lint + build)