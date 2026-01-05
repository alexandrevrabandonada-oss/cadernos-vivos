# CV — Fix — HomeV2Hub props + /c/[slug] redirect (v0_95)

## O que foi corrigido
- HomeV2Hub agora aceita mapa/stats opcionais (evita erro de props em /v2/page).
- /c/[slug] agora usa uiDefault e redirect quando default=v2 (remove warnings).

## Arquivos alterados
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\components\v2\HomeV2Hub.tsx

## Verify
- tools/cv-verify.ps1 (guard + lint + build)