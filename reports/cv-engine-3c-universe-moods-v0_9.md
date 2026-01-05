# CV Engine-3C — Universe Moods v0.9 — 2025-12-27 20:07

## O que mudou
- Novo componente client: src/components/UniverseShell.tsx
- Layout do caderno agora usa UniverseShell (aplica classes por rota automaticamente)
- CSS moods adicionados em globals.css (marker: /* cv-universe-moods */)

## Resultado
- Cada página do caderno ganha um clima de fundo diferente:
  home, aula, debate, mapa, quiz, pratica, registro, acervo, trilha

## Verify
- npm run lint
- npm run build