# CV-4 — Registro do Caderno + slug opcional (v0.4b) — 2025-12-27 15:41

## Por que o v0.4 quebrou
- O PowerShell interpreta o caractere ` (backtick) como escape em strings com aspas duplas.
- No report eu tinha markdown com `useParams` e isso virou escape unicode (`u...) -> ParserError.

## Mudança de estratégia
- Componentes client não exigem mais `slug` (agora é opcional e pode ser inferido via useParams()).
- Isso evita ficar “caçando slug” e quebrando build por prop faltando.

## Entregas
- Reescrito: src/components/DebateBoard.tsx (slug opcional/autoinfer)
- Reescrito: src/components/AulaProgress.tsx (slug opcional/autoinfer)
- Reescrito: src/components/TerritoryMap.tsx (sem any + slug opcional/autoinfer)
- Novo: src/components/RegistroPanel.tsx
- Nova rota: /c/[slug]/registro

## Nota (pra não misturar apps)
- “Recibo do mutirão” é do ECO.
- Aqui é “Registro do Caderno” (progresso + debate) salvo no aparelho.

## Verify
- npm run lint
- npm run build