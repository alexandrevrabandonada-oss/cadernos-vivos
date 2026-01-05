# CV — Hotfix v0_14 — RunCmd sem $args

## Causa raiz
- Funções com parâmetro chamado $args usam o $args automático (vazio) ao splatar, chamando npm sem argumentos.

## Fix
- tools/_bootstrap.ps1: RunCmd agora usa [string[]]$CmdArgs e splat correto (& $Exe @CmdArgs).

## Verify
- npm run lint
- npm run build
