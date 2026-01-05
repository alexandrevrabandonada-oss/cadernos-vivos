# CV — Fix — ProvasV2 page sem any (v0_117)

## O que foi corrigido
- Removidos todos os 'as any' do /v2/provas/page.tsx (lint no-explicit-any).
- Accent aplicado via barra simples (sem CSS var) para evitar casts.

## Arquivos alterados
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\v2\provas\page.tsx

## Verify
- tools/cv-verify.ps1 (guard + lint + build)