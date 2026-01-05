# CV — Step D3 — ProvasV2 (v0_104)

## O que entrou
- Nova rota: /c/[slug]/v2/provas
- Componente: ProvasV2 (server-safe; lê provas.md/mdx/txt ou provas.json)
- HomeV2Hub: garante card Provas
- V2Nav: garante tipo active com "provas" (se preciso)

## Arquivos alterados
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\components\v2\ProvasV2.tsx
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\v2\provas\page.tsx

## Verify
- tools/cv-verify.ps1 (guard + lint + build)