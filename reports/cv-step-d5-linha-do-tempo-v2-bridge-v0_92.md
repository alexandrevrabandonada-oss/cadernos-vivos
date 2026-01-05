# CV — Step D5 — Linha do Tempo V2 bridge (v0_92)

## O que foi entregue
- LinhaDoTempoV2 (client): busca + filtro ?node= + links para Mapa/Debate/Provas.
- /v2/linha-do-tempo: pagina nova usando loadCadernoV2.
- /v2/linha: redirect para /v2/linha-do-tempo (limpa warning antigo).

## Arquivos alterados
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\components\v2\LinhaDoTempoV2.tsx
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\v2\linha-do-tempo\page.tsx
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\v2\linha\page.tsx

## Verify
- tools/cv-verify.ps1 (guard + lint + build)