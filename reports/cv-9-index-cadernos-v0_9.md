# CV-9 — Índice de Cadernos (Home + /c) — 2025-12-27 17:33

## O que mudou
- Home (/) agora lista cadernos automaticamente
- Nova rota /c para ver o índice completo
- Nova lib src/lib/cadernos-index.ts (lê content/cadernos/*/caderno.json)

## Como funciona
- Cada pasta em content/cadernos/SLUG vira um item no índice
- Se caderno.json faltar, o título vira o slug humanizado

## Próximo tijolo (CV-10)
- Criador de caderno via script: gerar pasta + arquivos seed (caderno.json, panorama.md, aulas, pratica, quiz, debate, mapa, registro).