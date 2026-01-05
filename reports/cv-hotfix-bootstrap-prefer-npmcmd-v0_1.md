# CV Hotfix — bootstrap preferir npm.cmd — 2025-12-28 11:37

## Problema
- RunNative estava resolvendo npm para npm.ps1, disparando prompt interativo (instalação).

## Fix
- tools/_bootstrap.ps1: ResolveExe agora força npm.cmd no Windows (com fallback para Program Files).

## Verify
- npm run lint
- npm run build