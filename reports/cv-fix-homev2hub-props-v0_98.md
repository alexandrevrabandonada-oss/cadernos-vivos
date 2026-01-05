# CV — Fix — HomeV2Hub props mapa/stats (v0_98)

## O que foi corrigido
- HomeV2Hub exporta HubStats e aceita mapa/stats opcionais (corrige build de /v2/page).
- Evita variável reservada do PowerShell (C:\Users\Micro).

## Arquivos alterados
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\components\v2\HomeV2Hub.tsx

## Verify
- tools/cv-verify.ps1 (guard + lint + build)