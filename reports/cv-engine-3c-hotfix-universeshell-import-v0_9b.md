# CV Engine-3C — Hotfix import UniverseShell v0.9b — 2025-12-27 20:10

## Problema
- ESLint react/jsx-no-undef: UniverseShell usado no layout sem import

## Correção
- Inserido: import UniverseShell from "@/components/UniverseShell"

## Verify
- npm run lint
- npm run build