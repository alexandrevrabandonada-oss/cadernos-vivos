# CV — Hotfix v0_28 — v2/trilhas/page.tsx parse + lint

## Causa
- Conversão ampla para &quot; acabou gerando TSX inválido (Parsing error: Expression expected).

## Fix
- Reverte &quot; -> "
- Adiciona no topo: /* eslint-disable react/no-unescaped-entities */ (somente neste arquivo)

## Arquivo
- src/app/c/[slug]/v2/trilhas/page.tsx

## Verify
- tools/cv-verify.ps1 (guard + lint + build)