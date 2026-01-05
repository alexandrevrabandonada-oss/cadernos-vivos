# CV-Engine-2 — Zod Schemas e Parse Central — 2025-12-27 17:52

## O que foi feito
- Criado src/lib/schemas.ts com schemas Zod para caderno.json, mapa.json, debate.json, acervo.json.
- MapPoint agora aceita title/label/name opcionais (evita regressao de type).
- Patch em src/lib/cadernos.ts: JSON.parse(raw) virou parseXxxJson(raw) quando o script reconhece o arquivo.

## Resultado esperado
- Se JSON/schema estiver quebrado, erro fica legivel e localizado.
- Tipos unificados e menos quebra-cabeca no build.

## Proximo tijolo sugerido
- CV-Engine-3: acessibilidade e interatividade (atalhos, foco, ARIA, modo leitura, TTS botao).