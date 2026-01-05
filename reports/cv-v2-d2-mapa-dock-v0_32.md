# CV — Tijolo D2 v0_32 — Dock do Mapa V2 (Concreto Zen)

## O que entrou
- Novo componente client: src/components/v2/MapaDockV2.tsx
- Integração no MapaV2: import + render do Dock (overlay/painel).

## UX
- Atalhos rápidos: Home/Provas/Linha/Debate/Trilhas
- Busca de nós (título/id) e botão "Copiar link" com #id
- Layout responsivo: mobile (dock fixo), desktop (painel lateral).

## Verify
- tools/cv-verify.ps1 (Guard → Lint → Build)
