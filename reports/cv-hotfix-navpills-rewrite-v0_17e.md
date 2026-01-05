# Hotfix — NavPills rewrite v0_17e — 2025-12-27 21:31

## O que quebrou
- Lint acusou parsing error em src/components/NavPills.tsx (virgula/TSX quebrado).

## O que fizemos
- Reescrevemos NavPills.tsx inteiro num formato estável:
  - slug opcional (prop) + fallback via useParams()
  - itens definidos com vírgulas garantidas
  - inclui link Status (/status)

## Verificação
- npm run lint
- npm run build (se não usar -SkipBuild)