# CV-4c — Hotfix ESLint Hooks Condicionais — 2025-12-27 15:45

## Problema
- ESLint: react-hooks/rules-of-hooks (hooks chamados condicionalmente)

## Correção
- DebateBoard.tsx: removeu return antes dos hooks; slug vira string vazia e render mostra 'Carregando' quando necessário.
- RegistroPanel.tsx: mesma correção; hooks sempre executam na mesma ordem.

## Verify
- npm run lint
- npm run build