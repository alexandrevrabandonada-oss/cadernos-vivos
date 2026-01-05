# CV — Fix — HomeV2Hub useSyncExternalStore (v0_84)

## O que foi corrigido
- Removeu setState dentro de useEffect em HomeV2Hub; agora last vem de localStorage via useSyncExternalStore.

## Arquivos alterados
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\components\v2\HomeV2Hub.tsx

## Verify
- tools/cv-verify.ps1 (guard + lint + build)