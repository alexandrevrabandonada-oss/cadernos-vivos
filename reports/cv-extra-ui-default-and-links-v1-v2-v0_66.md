# CV — Extra — ui.default + links V1↔V2 (v0_66)

## O que entrou
- V1: link Ver V2 no topo (best-effort).
- V1: redirect para V2 quando meta.ui.default == v2 (apenas se detectar a variavel do getCaderno).
- V2Nav: botao V1 pra voltar rapido (best-effort).

## Como usar no caderno
- No meta.json: ui.default = v2 (ou uiDefault = v2).

## Arquivos alterados
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\page.tsx
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\components\v2\V2Nav.tsx

## Verify
- tools/cv-verify.ps1 (guard + lint + build)