# CV — Step D4 — ProvasV2 ↔ DebateV2 (v0_91)

## O que foi entregue
- ProvasV2 (client): busca + filtro ?node= + links p/ Debate/Mapa.
- DebateV2: recebe provas e mostra ate 3 provas relacionadas por card (best-effort por nodeIds).
- /v2/provas e /v2/debate: passam provas/mapa.

## Arquivos alterados
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\components\v2\ProvasV2.tsx
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\v2\provas\page.tsx
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\components\v2\DebateV2.tsx
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\v2\debate\page.tsx

## Verify
- tools/cv-verify.ps1 (guard + lint + build)