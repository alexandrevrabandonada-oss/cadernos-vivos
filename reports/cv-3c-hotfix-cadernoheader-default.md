# CV-3c — Hotfix CadernoHeader default export — 2025-12-27 13:03

## Problema
O build falhava: import default de CadernoHeader, mas o módulo não exportava default.

## Correção
Adicionado export default (preferindo export default CadernoHeader;).
Se não existir símbolo CadernoHeader, adiciona fallback default usando NavPills.

## Verify
npm run lint
npm run build