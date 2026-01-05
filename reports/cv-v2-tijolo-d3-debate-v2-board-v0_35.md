# CV — Tijolo D3 v0_35 — Debate V2 Board

## O que entrou
- Novo componente: src/components/v2/DebateBoardV2.tsx
- Page V2 Debate reescrita para usar DebateBoardV2 + meta.title

## UX
- Sidebar com tópicos derivados do mapa (nodes/items, com heurística safe).
- Painel com fio selecionado + links para Home/Provas/Linha + abrir no Mapa.
- Render do debate como texto (string) ou JSON (object) sem depender de Markdown.

## Verify
- tools/cv-verify.ps1 (Guard → Lint → Build)
