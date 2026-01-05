# CV — Hotfix — V2 /provas sem getAcervo (v0_59)

## O que mudou
- Remove import getAcervo (nao existe em src/lib/cadernos.ts).
- /v2/provas agora usa getCaderno(slug) e extrai itens do acervo de forma tolerante (acervoItems | acervo.items | acervo | provas).

## Arquivos alterados
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\v2\provas\page.tsx

## Verify
- tools/cv-verify.ps1 (guard + lint + build)