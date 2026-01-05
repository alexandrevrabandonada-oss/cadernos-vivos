# CV Engine-3D — ReadingControls global v0.10 — 2025-12-27 20:12

## Objetivo
- Painel de leitura único por caderno (todas as páginas herdam)
- Remover imports repetidos e warnings de unused-vars

## Mudanças
- layout.tsx: import + render <ReadingControls /> antes de {children}
- pages: removido import ReadingControls (agora é global)

## Resultado
- Imports removidos: 9