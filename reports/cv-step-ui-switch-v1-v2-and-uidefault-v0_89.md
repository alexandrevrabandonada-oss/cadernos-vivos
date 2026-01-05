# CV — Step — UI Switch V1↔V2 + uiDefault redirect (v0_89)

## O que foi feito
- V2Nav: adiciona "V2 beta" + link para V1.
- /c/[slug]: aplica redirect quando meta.ui.default = "v2" (usa uiDefault + redirect).
- HomeV2Hub: remove import useSyncExternalStore se estiver sobrando.

## Arquivos alterados
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\components\v2\V2Nav.tsx
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\components\v2\HomeV2Hub.tsx

## Verify
- tools/cv-verify.ps1 (guard + lint + build)