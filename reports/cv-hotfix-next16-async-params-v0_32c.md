# CV — Hotfix v0_32c — Next 16.1 async params/searchParams

## Causa
- Next 16.1+ trata params/searchParams como Promise em rotas dinâmicas no dev.

## Fix
- Em pages/layout async: props.params.* e params.* agora usam await.
- Em pages/layout async: props.searchParams.* e searchParams.* agora usam await.

## Arquivos alterados
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\v2\page.tsx
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\v2\debate\page.tsx
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\v2\linha-do-tempo\page.tsx
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\v2\mapa\page.tsx
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\v2\provas\page.tsx
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\v2\trilhas\page.tsx
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\v2\trilhas\[id]\page.tsx

## Arquivos pulados (nao-async)
- (nenhum)

## Verify
- tools/cv-verify.ps1 (guard + lint + build)
