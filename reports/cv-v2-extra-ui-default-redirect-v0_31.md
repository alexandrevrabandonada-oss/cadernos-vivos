# CV — Extra v0_31 — meta.ui.default (V1→V2 opt-in)

## O que mudou
- /c/[slug] agora pode redirecionar para /c/[slug]/v2 se meta.ui.default === "v2".
- Se a flag não existir, V1 continua como sempre.

## Como usar
- No meta do caderno, adicione algo como:
  - "ui": { "default": "v2" }

## Arquivo alterado
- src/app/c/[slug]/page.tsx

## Verify
- tools/cv-verify.ps1 (Guard → Lint → Build)
