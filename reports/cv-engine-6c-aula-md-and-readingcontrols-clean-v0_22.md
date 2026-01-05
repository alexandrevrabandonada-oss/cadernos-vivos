# CV Engine-6C — Aula MD + ReadingControls clean v0.22 — 2025-12-27 23:44

## Mudanças
- Adicionou src/lib/markdown.ts (renderer simples sem dependências)
- Adicionou src/lib/aulas.ts (carrega markdown da aula)
- Reescreveu ReadingControls (hydration-safe e lint-safe)
- Reescreveu /c/[slug]/a/[aula]/page.tsx para renderizar markdown
- globals.css: estilos cv-md e escala

## Teste
- Abra /c/meu-novo-caderno/a/1
- Tente Modo leitura / A+ / A- / Ouvir