# CV — Fix — idx/_idx + HomeV2Hub useSyncExternalStore + uiDefault redirect (v0_88)

## O que foi corrigido
- MapaV2: removeu _idx remanescente (agora usa idx corretamente).
- HomeV2Hub: se existia React.useSyncExternalStore, troca para useSyncExternalStore (usa o import).
- /c/[slug]: usa uiDefault e redireciona quando uiDefault === "v2".

## Arquivos alterados
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\components\v2\MapaV2.tsx

## Verify
- tools/cv-verify.ps1 (guard + lint + build)