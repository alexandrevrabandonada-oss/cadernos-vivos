# CV — Fix — D2 lint (v0_102)

## O que foi corrigido
- Removeu explicit-any no /v2/debate (active="debate").
- V2Nav passa a aceitar "debate" no tipo do active (quando houver union).
- /c/[slug] usa uiDefault+redirect quando v2 (remove warnings).

## Arquivos alterados
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\v2\debate\page.tsx

## Verify
- tools/cv-verify.ps1 (guard + lint + build)