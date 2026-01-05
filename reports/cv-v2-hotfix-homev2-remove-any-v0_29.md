# CV — Hotfix v0_29 — HomeV2 sem any (pickFios)

## Causa raiz
- HomeV2.tsx ainda tinha (v as any).items para ler panorama.fios, e o eslint no-explicit-any travou.

## Fix
- Trocou o bloco por uma leitura segura via Record<string, unknown> + Array.isArray(items).

## Arquivo
- src/components/v2/HomeV2.tsx

## Verify
- tools/cv-verify.ps1 (Guard → Lint → Build)
