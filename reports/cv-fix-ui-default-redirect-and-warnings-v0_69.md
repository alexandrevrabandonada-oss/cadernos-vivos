# CV — Fix — ui.default redirect + warnings (v0_69)

## O que foi ajustado
- /c/[slug]: usa uiDefault e faz redirect para /v2 quando meta.ui.default="v2".
- Remove import Link que estava sobrando.
- /v2/linha: remove import JsonValue que estava sobrando.

## Arquivos alterados
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\page.tsx

## Verify
- tools/cv-verify.ps1 (guard + lint + build)