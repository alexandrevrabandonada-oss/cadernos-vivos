# CV — V2 Tijolo D1 v0_42 — Home V2 Concreto Zen

## O que entrou
- Home V2 com visual Concreto Zen (header + cards + seções).
- Portas: Mapa, Debate, Provas, Linha, Linha do tempo, Trilhas.
- Fios quentes: nós mais conectados do mapa (heurística por grau), linkando para /v2/mapa#id.
- Sem componente criado dentro do render (lint).
- Sem any; parsing resiliente para mapa/meta.

## Arquivos
- src/components/v2/V2HomeCard.tsx
- src/app/c/[slug]/v2/page.tsx

## Verify
- tools/cv-verify.ps1 (guard + lint + build)
